import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/services/financial_statement_service.dart';
import 'package:accounting_app/services/period_service.dart';
import 'package:accounting_app/ui/widgets/date_range_selector.dart';
import 'package:accounting_app/ui/widgets/report_view_toggle.dart';
import 'package:provider/provider.dart';

class ProfitAndLoss extends StatefulWidget {
  const ProfitAndLoss({Key? key}) : super(key: key);

  @override
  State<ProfitAndLoss> createState() => _ProfitAndLossState();
}

class _ProfitAndLossState extends State<ProfitAndLoss> {
  bool isLoading = true;
  Map<String, List<Map<String, dynamic>>> plData = {
    'income': [],
    'expenses': [],
  };
  double totalIncome = 0;
  double totalExpenses = 0;
  DateTime? startDate;
  DateTime? endDate;
  String? booksBeginningDate;
  ReportViewMode viewMode = ReportViewMode.condensed;

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
    } catch (e) {
      debugPrint('Error loading books beginning date: $e');
    }
    _loadProfitAndLoss();
  }

  Future<void> _loadProfitAndLoss() async {
    try {
      setState(() {
        isLoading = true;
      });

      if (startDate == null || endDate == null) {
        final periodService = Provider.of<PeriodService>(context, listen: false);
        startDate = periodService.startDate;
        endDate = periodService.endDate;
      }

      final trading = await FinancialStatementService.calculateTradingAccount(
        startDate: startDate,
        endDate: endDate,
        booksBeginningDate: booksBeginningDate,
      );
      final profitAndLoss =
          await FinancialStatementService.calculateProfitAndLoss(
        startDate: startDate,
        endDate: endDate,
        booksBeginningDate: booksBeginningDate,
        grossProfit: trading['grossProfit'] as double,
      );

      final incomeItems = <Map<String, dynamic>>[
        ..._tagItems(trading['sales'], 'Sales Accounts'),
        ..._tagItems(trading['directIncome'], 'Direct Incomes'),
        ..._tagItems(profitAndLoss['indirectIncome'], 'Indirect Income'),
      ];
      final expenseItems = <Map<String, dynamic>>[
        ..._tagItems(trading['purchases'], 'Purchase Accounts'),
        ..._tagItems(trading['directExpenses'], 'Direct Expenses'),
        ..._tagItems(profitAndLoss['indirectExpenses'], 'Indirect Expenses'),
      ];

      final incomeTotal = incomeItems.fold<double>(
        0,
        (sum, item) => sum + (item['amount'] as double),
      );
      final expensesTotal = expenseItems.fold<double>(
        0,
        (sum, item) => sum + (item['amount'] as double),
      );

      if (mounted) {
        setState(() {
          plData = {
            'income': incomeItems,
            'expenses': expenseItems,
          };
          totalIncome = incomeTotal;
          totalExpenses = expensesTotal;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profit and loss: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _tagItems(dynamic rawItems, String group) {
    final items = (rawItems as List<dynamic>? ?? const []);
    return items.map((rawItem) {
      final item = rawItem as Map<String, dynamic>;
      return {
        'name': item['name'] as String,
        'amount': (item['balance'] as num).toDouble(),
        'type': group,
      };
    }).toList();
  }

  Widget _buildSection(String title, List<Map<String, dynamic>> items, double total) {
    final groupedItems = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final group = item['type'] as String;
      groupedItems.putIfAbsent(group, () => []).add(item);
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C5545),
              ),
            ),
            const Divider(),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No balances for this period',
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ...groupedItems.entries.expand((entry) {
              final groupTotal = entry.value.fold<double>(
                0,
                (sum, item) => sum + (item['amount'] as double),
              );
              final groupRow = _buildAmountRow(
                entry.key,
                groupTotal,
                isGroup: true,
              );

              if (viewMode == ReportViewMode.condensed) {
                return <Widget>[groupRow];
              }

              return <Widget>[
                groupRow,
                ...entry.value.map(
                  (item) => _buildAmountRow(
                    item['name'] as String,
                    item['amount'] as double,
                    isIndented: true,
                  ),
                ),
              ];
            }),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total $title',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '₹${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountRow(
    String label,
    double amount, {
    bool isGroup = false,
    bool isIndented = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        left: isIndented ? 20 : 0,
        top: isGroup ? 8 : 4,
        bottom: 4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isGroup ? FontWeight.w600 : FontWeight.normal,
                color: const Color(0xFF2C5545),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isGroup ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _onDateRangeSelected(DateTime start, DateTime end) async {
    setState(() {
      startDate = start;
      endDate = end;
    });
    await _loadBooksBeginningDate();
  }

  @override
  Widget build(BuildContext context) {
    final netProfit = totalIncome - totalExpenses;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profit & Loss',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2C5545),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              color: const Color(0xFFE0F2E9),
              child: Column(
                children: [
                    DateRangeSelector(
                      initialStartDate: startDate,
                      initialEndDate: endDate,
                      onDateRangeSelected: _onDateRangeSelected,
                    ),
                    ReportViewToggle(
                      mode: viewMode,
                      onChanged: (mode) => setState(() => viewMode = mode),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildSection('Income', plData['income']!, totalIncome),
                          _buildSection('Expenses', plData['expenses']!, totalExpenses),
                          Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            color: const Color(0xFFE0F2E9),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Net Profit/Loss',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '₹${netProfit.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: netProfit >= 0 ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
