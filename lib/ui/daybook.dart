import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/ui/receipt_voucher.dart';
import 'package:accounting_app/ui/payment_voucher.dart';
import 'package:accounting_app/ui/journal_voucher.dart';
import 'package:accounting_app/ui/widgets/date_range_selector.dart';
import 'package:provider/provider.dart';
import 'package:accounting_app/services/period_service.dart';

class Daybook extends StatefulWidget {
  const Daybook({Key? key}) : super(key: key);

  @override
  State<Daybook> createState() => _DaybookState();
}

class _DaybookState extends State<Daybook> {
  List<Map<String, dynamic>> entries = [];
  List<Map<String, dynamic>> allEntries = []; // Store all entries
  bool isLoading = true;
  bool isSelectionMode = false;
  Set<int> selectedVouchers = {};
  String currentPeriod = '';
  DateTime? startDate;
  DateTime? endDate;
  DateTime? _bookBeginningDate; // To store the actual start of the financial year

  @override
  void initState() {
    super.initState();
    startDate = Provider.of<PeriodService>(context, listen: false).startDate;
    endDate = Provider.of<PeriodService>(context, listen: false).endDate;
    _loadDaybook();
    _loadCurrentPeriod();
  }

  Future<void> _loadCurrentPeriod() async {
    try {
      final company = await StorageService.getSelectedCompany();
      if (company != null) {
        final financialYearFrom = company['financial_year_from'] as String? ?? '';
        if (financialYearFrom.isNotEmpty) {
          final fromDate = DateTime.parse(financialYearFrom);
          final toDate = DateTime(fromDate.year + 1, fromDate.month, fromDate.day - 1);
          setState(() {
            _bookBeginningDate = fromDate; // Store the book's beginning date
            currentPeriod = '${_formatDate(fromDate)} to ${_formatDate(toDate)}';
          });
        }
      }
    } catch (e) {
      print('Error loading current period: $e');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _loadDaybook() async {
    try {
      // Get vouchers with enhanced info (including particulars)
      final enhancedVouchers = await StorageService.getDaybook();
      
      // Sort by date in descending order (newest first)
      enhancedVouchers.sort((a, b) {
        // First compare by date (newest first)
        final dateComparison = (b['voucher_date'] as String).compareTo(a['voucher_date'] as String);
        if (dateComparison != 0) return dateComparison;
        
        // If dates are the same, compare by voucher ID (newest first)
        return (b['id'] as int).compareTo(a['id'] as int);
      });
      
      setState(() {
        allEntries = enhancedVouchers;
        _filterEntriesByDate();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading daybook: $e')),
        );
      }
    }
  }

  void _filterEntriesByDate() {
    if (startDate == null || endDate == null) {
      entries = allEntries;
      return;
    }

    entries = allEntries.where((entry) {
      final voucherDateStr = entry['voucher_date'] as String?;
      if (voucherDateStr == null || voucherDateStr.isEmpty) return false;
      
      try {
        final voucherDate = DateTime.parse(voucherDateStr);
        return !voucherDate.isBefore(startDate!) && !voucherDate.isAfter(endDate!);
      } catch (e) {
        return false;
      }
    }).toList();
  }

  void _onDateRangeSelected(DateTime start, DateTime end) {
    setState(() {
      startDate = start;
      startDate = start;
      endDate = end;
      currentPeriod = '${_formatDate(start)} to ${_formatDate(end)}'; // Update currentPeriod display
      _filterEntriesByDate();
    });
  }

  Future<void> _deleteSelectedVouchers() async {
    if (selectedVouchers.isEmpty) return;
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vouchers'),
        content: Text('Are you sure you want to delete ${selectedVouchers.length} selected voucher(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() {
      isLoading = true;
    });
    
    try {
      // Delete all selected vouchers at once
      await StorageService.deleteVouchers(selectedVouchers.toList());
      
      // Reload daybook and exit selection mode
      await _loadDaybook();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${selectedVouchers.length} voucher(s) deleted')),
      );
      
      setState(() {
        isSelectionMode = false;
        selectedVouchers.clear();
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting vouchers: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2E9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C5545),
        title: isSelectionMode
            ? Text(
                '${selectedVouchers.length} selected',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 32,
                    width: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_balance,
                      size: 20,
                      color: Color(0xFF2C5545),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Kishore',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
        centerTitle: true,
        leading: isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    isSelectionMode = false;
                    selectedVouchers.clear();
                  });
                },
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
        actions: isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _deleteSelectedVouchers,
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF2C5545),
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFF2C5545),
                  width: 1,
                ),
              ),
            ),
            child: const Text(
              'Day Book',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          DateRangeSelector(
            initialStartDate: startDate,
            initialEndDate: endDate,
            showResetButton: true,
            onDateRangeSelected: _onDateRangeSelected,
            minSelectableDate: _bookBeginningDate, // Pass the book's beginning date
            onResetToDefault: () {
              final periodService = Provider.of<PeriodService>(context, listen: false);
              periodService.resetToSessionDefault();
              setState(() {
                startDate = periodService.startDate;
                endDate = periodService.endDate;
                currentPeriod = '${_formatDate(startDate!)} to ${_formatDate(endDate!)}';
                _filterEntriesByDate();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Period reset to session default'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : entries.isEmpty
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0x1A000000), // 10% opacity black
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            'No entries found.\nCreate vouchers to see them here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF2C5545),
                            ),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Column(
                          children: [
                            // Table header
                            Container(
                              width: 760, // Sum of all column widths
                              color: const Color(0xFFE0F2E9),
                              child: Table(
                                border: TableBorder.all(
                                  color: const Color(0xFF2C5545),
                                  width: 1,
                                ),
                                columnWidths: const {
                                  0: FixedColumnWidth(120), // Date
                                  1: FixedColumnWidth(180), // Particulars
                                  2: FixedColumnWidth(120), // Vch Type
                                  3: FixedColumnWidth(100), // Vch No.
                                  4: FixedColumnWidth(120), // Debit
                                  5: FixedColumnWidth(120), // Credit
                                },
                                children: [
                                  TableRow(
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE0F2E9),
                                    ),
                                    children: [
                                      _buildTableHeader('Date'),
                                      _buildTableHeader('Particulars'),
                                      _buildTableHeader('Vch Type'),
                                      _buildTableHeader('Vch No.', FontWeight.bold),
                                      _buildTableHeader('Debit'),
                                      _buildTableHeader('Credit'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Table body
                            Container(
                              height: MediaQuery.of(context).size.height - 200, // Adjust height as needed
                              width: 760, // Same width as header
                              child: SingleChildScrollView(
                                child: Table(
                                  border: TableBorder.all(
                                    color: const Color(0xFF2C5545),
                                    width: 1,
                                  ),
                                  columnWidths: const {
                                    0: FixedColumnWidth(120), // Date
                                    1: FixedColumnWidth(180), // Particulars
                                    2: FixedColumnWidth(120), // Vch Type
                                    3: FixedColumnWidth(100), // Vch No.
                                    4: FixedColumnWidth(120), // Debit
                                    5: FixedColumnWidth(120), // Credit
                                  },
                                  children: entries.map((entry) {
                                    final voucherId = entry['id'] as int;
                                    final isSelected = selectedVouchers.contains(voucherId);
                                    
                                    // Determine if this is a debit or credit entry
                                    final type = entry['type'] as String;
                                    final amount = entry['total'] as double? ?? 0.0;
                                    double debitAmount = 0.0;
                                    double creditAmount = 0.0;
                                    
                                    // For receipt vouchers, the account should be credited (opposite of what happens to the bank)
                                    // For payment vouchers, the amount should be shown as a debit item
                                    if (type == 'Receipt') {
                                      creditAmount = amount;
                                    } else if (type == 'Payment') {
                                      debitAmount = amount;
                                    } else {
                                      // For other voucher types, determine based on the actual entries
                                      // This is a simplified approach
                                      debitAmount = amount;
                                    }
                                    
                                    // Format the date (assuming it's in YYYY-MM-DD format)
                                    String formattedDate = entry['voucher_date'] as String;
                                    try {
                                      final dateParts = formattedDate.split('-');
                                      if (dateParts.length == 3) {
                                        formattedDate = '${dateParts[2]}/${dateParts[1]}/${dateParts[0]}';
                                      }
                                    } catch (e) {
                                      // Keep the original format if parsing fails
                                    }
                                    
                                    return TableRow(
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFFB8E0D2) : const Color(0xFFE0F2E9),
                                      ),
                                      children: [
                                        // Date
                                        GestureDetector(
                                          onTap: () => _handleRowTap(entry),
                                          onLongPress: () => _handleRowLongPress(voucherId),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                            child: Text(
                                              formattedDate,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.normal,
                                                color: Color(0xFF2C5545),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                        // Particulars
                                        GestureDetector(
                                          onTap: () => _handleRowTap(entry),
                                          onLongPress: () => _handleRowLongPress(voucherId),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                            child: Text(
                                              entry['particulars'] as String? ?? '',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.normal,
                                                color: Color(0xFF2C5545),
                                              ),
                                              textAlign: TextAlign.left,
                                            ),
                                          ),
                                        ),
                                        // Vch Type
                                        GestureDetector(
                                          onTap: () => _handleRowTap(entry),
                                          onLongPress: () => _handleRowLongPress(voucherId),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                            child: Text(
                                              type,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.normal,
                                                color: Color(0xFF2C5545),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                        // Vch No.
                                        GestureDetector(
                                          onTap: () => _handleRowTap(entry),
                                          onLongPress: () => _handleRowLongPress(voucherId),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                            child: Text(
                                              entry['voucher_number'] as String? ?? '',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF2C5545),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                        // Debit
                                        GestureDetector(
                                          onTap: () => _handleRowTap(entry),
                                          onLongPress: () => _handleRowLongPress(voucherId),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                            child: Text(
                                              debitAmount > 0 ? debitAmount.toStringAsFixed(2) : '',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.normal,
                                                color: Color(0xFF2C5545),
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                        ),
                                        // Credit
                                        GestureDetector(
                                          onTap: () => _handleRowTap(entry),
                                          onLongPress: () => _handleRowLongPress(voucherId),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                            child: Text(
                                              creditAmount > 0 ? creditAmount.toStringAsFixed(2) : '',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.normal,
                                                color: Color(0xFF2C5545),
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
          if (isSelectionMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: ElevatedButton(
                onPressed: _deleteSelectedVouchers,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('Delete ${selectedVouchers.length} Selected'),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildTableHeader(String text, [FontWeight weight = FontWeight.bold]) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: weight,
          color: const Color(0xFF2C5545),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTableCell(String text, [TextAlign align = TextAlign.center, FontWeight? fontWeight]) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: const Color(0xFF2C5545),
          fontWeight: fontWeight ?? FontWeight.normal,
        ),
        textAlign: align,
      ),
    );
  }
  
  void _handleRowTap(Map<String, dynamic> entry) {
    if (isSelectionMode) {
      final voucherId = entry['id'] as int;
      setState(() {
        if (selectedVouchers.contains(voucherId)) {
          selectedVouchers.remove(voucherId);
          if (selectedVouchers.isEmpty) {
            isSelectionMode = false;
          }
        } else {
          selectedVouchers.add(voucherId);
        }
      });
    } else {
      // Navigate to edit the voucher based on its type
      final voucherType = entry['type'] as String;
      final voucherId = entry['id'] as int;
      Widget editPage;
      
      switch (voucherType) {
        case 'Receipt':
          editPage = ReceiptVoucher(voucherId: voucherId);
          break;
        case 'Payment':
          editPage = PaymentVoucher(voucherId: voucherId);
          break;
        case 'Journal':
          editPage = JournalVoucher(voucherId: voucherId);
          break;
        default:
          // Default to receipt voucher if type is unknown
          editPage = ReceiptVoucher(voucherId: voucherId);
      }
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => editPage,
        ),
      ).then((_) => _loadDaybook());
    }
  }
  
  void _handleRowLongPress(int voucherId) {
    setState(() {
      if (!isSelectionMode) {
        isSelectionMode = true;
        selectedVouchers.add(voucherId);
      }
    });
  }
}
