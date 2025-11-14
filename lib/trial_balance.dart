import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/services/financial_statement_service.dart';
import 'package:accounting_app/services/period_service.dart';
import 'package:accounting_app/ui/widgets/date_range_selector.dart';
import 'package:accounting_app/ui/ledger_view.dart';
import 'package:provider/provider.dart';

class TrialBalance extends StatefulWidget {
  const TrialBalance({Key? key}) : super(key: key);

  @override
  State<TrialBalance> createState() => _TrialBalanceState();
}

class _TrialBalanceState extends State<TrialBalance> {
  bool isLoading = true;
  List<Map<String, dynamic>> trialBalanceData = [];
  List<Map<String, dynamic>> stockValuationNotes = [];
  double totalDebit = 0;
  double totalCredit = 0;
  DateTime? startDate;
  DateTime? endDate;
  String? booksBeginningDate;

  @override
  void initState() {
    super.initState();
    _loadBooksBeginningDate();
  }

  Future<void> _loadBooksBeginningDate() async {
    try {
      final company = await StorageService.getSelectedCompany();
      if (company != null) {
        booksBeginningDate = company['books_from'] as String?;
      }
      // After loading books date, load the trial balance
      _loadTrialBalance();
    } catch (e) {
      debugPrint('Error loading books beginning date: $e');
      _loadTrialBalance();
    }
  }

  Future<void> _loadTrialBalance() async {
    try {
      setState(() {
        isLoading = true;
        stockValuationNotes.clear();
      });

      final ledgers = await StorageService.getLedgers();
      List<Map<String, dynamic>> data = [];
      double debitTotal = 0;
      double creditTotal = 0;

      // Get period from PeriodService if not set locally
      if (startDate == null || endDate == null) {
        final periodService = Provider.of<PeriodService>(context, listen: false);
        startDate = periodService.startDate;
        endDate = periodService.endDate;
      }

      // Track stock-in-hand ledgers separately
      double totalOpeningStock = 0.0;
      List<int> stockLedgerIds = [];
      List<Map<String, dynamic>> stockNotes = [];

      for (var ledger in ledgers) {
        final classification = ledger['classification'] as String? ?? '';
        double balance = 0.0;

        // Special handling for Stock-in-Hand - collect opening stock
        if (classification == 'Stock-in-hand') {
          stockLedgerIds.add(ledger['id'] as int);

          // Get opening stock (on or before start date) and closing stock (on or before end date)
          double openingStockValue = 0.0;
          double closingStockValue = 0.0;
          String? openingDate;
          String? closingDate;

          // Determine the effective opening date
          // If period starts on or before books beginning date, use books beginning date
          String? effectiveOpeningDateStr;
          if (startDate != null && booksBeginningDate != null) {
            final startDateStr = '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}';
            // If period starts before or on books beginning date, opening stock is at books beginning
            if (startDateStr.compareTo(booksBeginningDate!) <= 0) {
              effectiveOpeningDateStr = booksBeginningDate;
            } else {
              effectiveOpeningDateStr = startDateStr;
            }
          } else if (startDate != null) {
            effectiveOpeningDateStr = '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}';
          }

          // Get opening stock valuation (on or before effective opening date)
          if (effectiveOpeningDateStr != null) {
            final openingVal = await StorageService.getStockValuationForDate(
              ledger['id'] as int,
              effectiveOpeningDateStr,
            );
            if (openingVal != null) {
              openingStockValue = (openingVal['amount'] as num).toDouble();
              openingDate = openingVal['valuation_date'] as String;
            }
          }

          // Get closing stock valuation (on or before end date)
          if (endDate != null) {
            final endDateStr = '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}';
            final closingVal = await StorageService.getStockValuationForDate(
              ledger['id'] as int,
              endDateStr,
            );
            if (closingVal != null) {
              closingStockValue = (closingVal['amount'] as num).toDouble();
              closingDate = closingVal['valuation_date'] as String;
            }
          }

          // Add to total opening stock
          totalOpeningStock += openingStockValue;

          // Create note with both opening and closing stock info - always show
          String message = '';
          if (openingDate != null) {
            message += 'Opening Stock: ₹${openingStockValue.toStringAsFixed(2)} as of ${_formatDbDate(openingDate)}';
          } else {
            message += 'Opening Stock: No valuation found on or before ${_formatDate(startDate)}';
          }

          if (closingDate != null) {
            if (message.isNotEmpty) message += '; ';
            message += 'Closing Stock: ₹${closingStockValue.toStringAsFixed(2)} as of ${_formatDbDate(closingDate)}';
          } else {
            if (message.isNotEmpty) message += '; ';
            message += 'Closing Stock: No valuation found on or before ${_formatDate(endDate)}';
          }

          stockNotes.add({
            'ledger': ledger['name'],
            'message': message,
            'type': openingDate == null ? 'warning' : 'info',
          });
        } else {
          // Regular ledger balance calculation
          balance = await FinancialStatementService.calculateLedgerBalance(
            ledgerId: ledger['id'] as int,
            ledger: ledger,
            startDate: startDate,
            endDate: endDate,
            booksBeginningDate: booksBeginningDate,
          );

          if (balance == 0) continue;

          double debit = 0;
          double credit = 0;

          // Positive balance means debit, negative means credit
          if (balance > 0) {
            debit = balance;
            debitTotal += balance;
          } else {
            credit = balance.abs();
            creditTotal += balance.abs();
          }

          data.add({
            'id': ledger['id'],
            'name': ledger['name'],
            'classification': classification,
            'debit': debit,
            'credit': credit,
          });
        }
      }

      // Add single "Opening Stock" entry if there are stock-in-hand ledgers
      if (stockLedgerIds.isNotEmpty) {
        data.add({
          'id': stockLedgerIds.first,
          'name': 'Opening Stock',
          'classification': 'Stock-in-hand',
          'debit': totalOpeningStock,
          'credit': 0.0,
          'isStockSummary': true,
        });
        debitTotal += totalOpeningStock;
      }

      // Add stock notes
      stockValuationNotes.addAll(stockNotes);

      // Sort by classification, then by name
      data.sort((a, b) {
        final classCompare = (a['classification'] as String)
            .compareTo(b['classification'] as String);
        if (classCompare != 0) return classCompare;
        return (a['name'] as String).compareTo(b['name'] as String);
      });

      if (mounted) {
        setState(() {
          trialBalanceData = data;
          totalDebit = debitTotal;
          totalCredit = creditTotal;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading trial balance: $e')),
        );
      }
    }
  }

  String _formatDbDate(String dbDate) {
    final parts = dbDate.split('-');
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  void _onDateRangeSelected(DateTime start, DateTime end) {
    setState(() {
      startDate = start;
      endDate = end;
    });
    _loadTrialBalance();
  }

  void _showDateRangeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          child: DateRangeSelector(
            initialStartDate: startDate,
            initialEndDate: endDate,
            showResetButton: true,
            onDateRangeSelected: (start, end) {
              _onDateRangeSelected(start, end);
              Navigator.of(dialogContext).pop();
            },
            onCancel: () => Navigator.of(dialogContext).pop(),
            onResetToDefault: () {
              final periodService = Provider.of<PeriodService>(context, listen: false);
              periodService.resetToSessionDefault();
              setState(() {
                startDate = periodService.startDate;
                endDate = periodService.endDate;
              });
              _loadTrialBalance();
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Period reset to session default'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final difference = (totalDebit - totalCredit).abs();
    final isBalanced = difference < 0.01; // Allow for small floating point errors

    return Scaffold(
      backgroundColor: const Color(0xFFE0F2E9),
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Trial Balance',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2C5545),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: _showDateRangeDialog,
            tooltip: 'Select Date Range',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Period display
                Consumer<PeriodService>(
                  builder: (context, periodService, child) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      color: const Color(0xFFE0F2E9),
                      child: Column(
                        children: [
                          Text(
                            'Period: ${_formatDate(startDate)} to ${_formatDate(endDate)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2C5545),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Stock valuation notes
                if (stockValuationNotes.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      border: Border.all(color: Colors.blue[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Stock Valuation Notes',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...stockValuationNotes.map((note) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• ', style: TextStyle(color: Colors.blue[700])),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(color: Colors.black87, fontSize: 13),
                                    children: [
                                      TextSpan(
                                        text: '${note['ledger']}: ',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      TextSpan(text: note['message']),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),

                // Table
                Expanded(
                  child: trialBalanceData.isEmpty
                      ? const Center(
                          child: Text(
                            'No data available for the selected period',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                const Color(0xFFC8E6D8),
                              ),
                              columnSpacing: 20,
                              border: TableBorder.all(
                                color: const Color(0xFF2C5545),
                                width: 1.5,
                              ),
                              dataRowMinHeight: 48,
                              dataRowMaxHeight: 56,
                              columns: const [
                                DataColumn(
                                  label: Text(
                                    'Particulars',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF2C5545),
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Group',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF2C5545),
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Debit',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF2C5545),
                                    ),
                                  ),
                                  numeric: true,
                                ),
                                DataColumn(
                                  label: Text(
                                    'Credit',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF2C5545),
                                    ),
                                  ),
                                  numeric: true,
                                ),
                              ],
                              rows: [
                                ...trialBalanceData.map(
                                  (item) => DataRow(
                                    cells: [
                                      DataCell(
                                        GestureDetector(
                                          onTap: () async {
                                            // Navigate to ledger view for this account
                                            final ledgerId = item['id'] as int;

                                            // Capture context-dependent values before async gap
                                            final periodService = Provider.of<PeriodService>(context, listen: false);
                                            final navigator = Navigator.of(context);

                                            // Set the period to match Trial Balance period
                                            if (startDate != null && endDate != null) {
                                              periodService.setPeriod(startDate!, endDate!);
                                            }

                                            // Get full ledger data
                                            final ledgers = await StorageService.getLedgers();
                                            final ledger = ledgers.firstWhere(
                                              (l) => l['id'] == ledgerId,
                                              orElse: () => {},
                                            );

                                            if (ledger.isNotEmpty && mounted) {
                                              // Get ledger entries for the period
                                              final entries = await StorageService.getLedgerReport(ledgerId);

                                              navigator.push(
                                                MaterialPageRoute(
                                                  builder: (context) => LedgerView(
                                                    ledger: ledger,
                                                    initialEntries: entries,
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          child: Text(
                                            item['name'] as String,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              color: Colors.black,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          item['classification'] as String,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                      DataCell(Text(
                                        (item['debit'] as double) > 0
                                            ? (item['debit'] as double).toStringAsFixed(2)
                                            : '',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.black,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      )),
                                      DataCell(Text(
                                        (item['credit'] as double) > 0
                                            ? (item['credit'] as double).toStringAsFixed(2)
                                            : '',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.black,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      )),
                                    ],
                                  ),
                                ),
                                // Difference row (if not balanced)
                                if (!isBalanced)
                                  DataRow(
                                    color: WidgetStateProperty.all(Colors.red[50]),
                                    cells: [
                                      DataCell(Text(
                                        'Difference in Op.Bal',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.red[900],
                                        ),
                                      )),
                                      const DataCell(Text('')),
                                      DataCell(Text(
                                        totalDebit < totalCredit ? difference.toStringAsFixed(2) : '',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.red[900],
                                        ),
                                      )),
                                      DataCell(Text(
                                        totalCredit < totalDebit ? difference.toStringAsFixed(2) : '',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.red[900],
                                        ),
                                      )),
                                    ],
                                  ),
                                // Total row
                                DataRow(
                                  color: WidgetStateProperty.all(
                                    const Color(0xFFC8E6D8),
                                  ),
                                  cells: [
                                    const DataCell(Text(
                                      'Total',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF2C5545),
                                      ),
                                    )),
                                    const DataCell(Text('')),
                                    DataCell(Text(
                                      (totalDebit + (totalDebit < totalCredit ? difference : 0)).toStringAsFixed(2),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF2C5545),
                                      ),
                                    )),
                                    DataCell(Text(
                                      (totalCredit + (totalCredit < totalDebit ? difference : 0)).toStringAsFixed(2),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF2C5545),
                                      ),
                                    )),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
