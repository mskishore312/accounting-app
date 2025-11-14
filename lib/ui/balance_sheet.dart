import 'package:flutter/material.dart';
import 'package:accounting_app/services/financial_statement_service.dart';
import 'package:accounting_app/services/period_service.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/ui/widgets/date_range_selector.dart';
import 'package:provider/provider.dart';

class BalanceSheet extends StatefulWidget {
  const BalanceSheet({Key? key}) : super(key: key);

  @override
  State<BalanceSheet> createState() => _BalanceSheetState();
}

class _BalanceSheetState extends State<BalanceSheet> {
  bool isLoading = true;
  DateTime? startDate;
  DateTime? endDate;
  String? booksBeginningDate;

  // Assets data
  Map<String, List<Map<String, dynamic>>> assetsData = {};
  double totalAssets = 0;

  // Liabilities data
  Map<String, List<Map<String, dynamic>>> liabilitiesData = {};
  double totalLiabilities = 0;

  // Net Profit/Loss
  double netProfit = 0;

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
      _loadData();
    } catch (e) {
      debugPrint('Error loading books beginning date: $e');
      _loadData();
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Get period from PeriodService if not set locally
      if (startDate == null || endDate == null) {
        final periodService = Provider.of<PeriodService>(context, listen: false);
        startDate = periodService.startDate;
        endDate = periodService.endDate;
      }

      // Calculate Net Profit first
      final tradingData = await FinancialStatementService.calculateTradingAccount(
        startDate: startDate,
        endDate: endDate,
        booksBeginningDate: booksBeginningDate,
      );
      final plData = await FinancialStatementService.calculateProfitAndLoss(
        startDate: startDate,
        endDate: endDate,
        booksBeginningDate: booksBeginningDate,
        grossProfit: tradingData['grossProfit'] as double,
      );
      final calculatedNetProfit = plData['netProfit'] as double;

      // Get Assets
      final assets = await FinancialStatementService.getAssets(
        startDate: startDate,
        endDate: endDate,
        booksBeginningDate: booksBeginningDate,
      );

      // Get Liabilities
      final liabilities = await FinancialStatementService.getLiabilities(
        startDate: startDate,
        endDate: endDate,
        booksBeginningDate: booksBeginningDate,
      );

      // Calculate totals
      double assetsTotal = 0;
      for (var category in assets.values) {
        for (var item in category) {
          assetsTotal += item['balance'] as double;
        }
      }

      double liabilitiesTotal = 0;
      for (var category in liabilities.values) {
        for (var item in category) {
          liabilitiesTotal += item['balance'] as double;
        }
      }

      if (mounted) {
        setState(() {
          assetsData = assets;
          liabilitiesData = liabilities;
          totalAssets = assetsTotal;
          totalLiabilities = liabilitiesTotal;
          netProfit = calculatedNetProfit;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  void _onDateRangeSelected(DateTime start, DateTime end) {
    setState(() {
      startDate = start;
      endDate = end;
    });
    _loadData();
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
              _loadData();
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

  Widget _buildSectionHeader(String title, {required Color color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6, left: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2C5545),
        ),
      ),
    );
  }

  Widget _buildAccountItem(String name, double amount, {bool isIndented = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isIndented ? 24 : 16,
        vertical: 4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2C5545),
              ),
            ),
          ),
          Text(
            amount.toStringAsFixed(2),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF2C5545),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtotalRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C5545),
            ),
          ),
          Text(
            amount.toStringAsFixed(2),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C5545),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, Color backgroundColor) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            amount.toStringAsFixed(2),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetsSection() {
    double fixedAssetsTotal = 0;
    double investmentsTotal = 0;
    double currentAssetsTotal = 0;
    double loansAdvancesTotal = 0;
    double miscExpensesTotal = 0;

    // Calculate subtotals
    for (var item in assetsData['Fixed Assets'] ?? []) {
      fixedAssetsTotal += item['balance'] as double;
    }
    for (var item in assetsData['Investments'] ?? []) {
      investmentsTotal += item['balance'] as double;
    }
    for (var item in assetsData['Current Assets'] ?? []) {
      currentAssetsTotal += item['balance'] as double;
    }
    for (var item in assetsData['Loans & Advances'] ?? []) {
      loansAdvancesTotal += item['balance'] as double;
    }
    for (var item in assetsData['Misc. Expenses'] ?? []) {
      miscExpensesTotal += item['balance'] as double;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed Assets
          if ((assetsData['Fixed Assets'] ?? []).isNotEmpty) ...[
            _buildCategoryHeader('Fixed Assets'),
            ...(assetsData['Fixed Assets'] ?? []).map((item) =>
                _buildAccountItem(item['name'] as String, item['balance'] as double, isIndented: true)),
            if ((assetsData['Fixed Assets'] ?? []).length > 1)
              _buildSubtotalRow('Total Fixed Assets', fixedAssetsTotal),
          ],

          // Investments
          if ((assetsData['Investments'] ?? []).isNotEmpty) ...[
            _buildCategoryHeader('Investments'),
            ...(assetsData['Investments'] ?? []).map((item) =>
                _buildAccountItem(item['name'] as String, item['balance'] as double, isIndented: true)),
            if ((assetsData['Investments'] ?? []).length > 1)
              _buildSubtotalRow('Total Investments', investmentsTotal),
          ],

          // Current Assets
          if ((assetsData['Current Assets'] ?? []).isNotEmpty) ...[
            _buildCategoryHeader('Current Assets'),
            ...(assetsData['Current Assets'] ?? []).map((item) =>
                _buildAccountItem(item['name'] as String, item['balance'] as double, isIndented: true)),
            if ((assetsData['Current Assets'] ?? []).length > 1)
              _buildSubtotalRow('Total Current Assets', currentAssetsTotal),
          ],

          // Loans & Advances (Asset)
          if ((assetsData['Loans & Advances'] ?? []).isNotEmpty) ...[
            _buildCategoryHeader('Loans & Advances (Asset)'),
            ...(assetsData['Loans & Advances'] ?? []).map((item) =>
                _buildAccountItem(item['name'] as String, item['balance'] as double, isIndented: true)),
            if ((assetsData['Loans & Advances'] ?? []).length > 1)
              _buildSubtotalRow('Total Loans & Advances', loansAdvancesTotal),
          ],

          // Misc. Expenses (Asset)
          if ((assetsData['Misc. Expenses'] ?? []).isNotEmpty) ...[
            _buildCategoryHeader('Misc. Expenses (Asset)'),
            ...(assetsData['Misc. Expenses'] ?? []).map((item) =>
                _buildAccountItem(item['name'] as String, item['balance'] as double, isIndented: true)),
            if ((assetsData['Misc. Expenses'] ?? []).length > 1)
              _buildSubtotalRow('Total Misc. Expenses', miscExpensesTotal),
          ],

          if (totalAssets == 0)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No assets for this period',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLiabilitiesSection() {
    double capitalReservesTotal = 0;
    double loansTotal = 0;
    double bankODTotal = 0;
    double currentLiabilitiesTotal = 0;

    // Calculate subtotals
    for (var item in liabilitiesData['Capital & Reserves'] ?? []) {
      capitalReservesTotal += item['balance'] as double;
    }
    for (var item in liabilitiesData['Loans'] ?? []) {
      loansTotal += item['balance'] as double;
    }
    for (var item in liabilitiesData['Bank Overdraft'] ?? []) {
      bankODTotal += item['balance'] as double;
    }
    for (var item in liabilitiesData['Current Liabilities'] ?? []) {
      currentLiabilitiesTotal += item['balance'] as double;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Capital & Reserves
          if ((liabilitiesData['Capital & Reserves'] ?? []).isNotEmpty) ...[
            _buildCategoryHeader('Capital & Reserves'),
            ...(liabilitiesData['Capital & Reserves'] ?? []).map((item) =>
                _buildAccountItem(item['name'] as String, item['balance'] as double, isIndented: true)),
            if ((liabilitiesData['Capital & Reserves'] ?? []).length > 1)
              _buildSubtotalRow('Total Capital & Reserves', capitalReservesTotal),
          ],

          // Loans (Liability)
          if ((liabilitiesData['Loans'] ?? []).isNotEmpty) ...[
            _buildCategoryHeader('Loans'),
            ...(liabilitiesData['Loans'] ?? []).map((item) =>
                _buildAccountItem(item['name'] as String, item['balance'] as double, isIndented: true)),
            if ((liabilitiesData['Loans'] ?? []).length > 1)
              _buildSubtotalRow('Total Loans', loansTotal),
          ],

          // Bank Overdraft
          if ((liabilitiesData['Bank Overdraft'] ?? []).isNotEmpty) ...[
            _buildCategoryHeader('Bank Overdraft'),
            ...(liabilitiesData['Bank Overdraft'] ?? []).map((item) =>
                _buildAccountItem(item['name'] as String, item['balance'] as double, isIndented: true)),
            if ((liabilitiesData['Bank Overdraft'] ?? []).length > 1)
              _buildSubtotalRow('Total Bank Overdraft', bankODTotal),
          ],

          // Current Liabilities
          if ((liabilitiesData['Current Liabilities'] ?? []).isNotEmpty) ...[
            _buildCategoryHeader('Current Liabilities'),
            ...(liabilitiesData['Current Liabilities'] ?? []).map((item) =>
                _buildAccountItem(item['name'] as String, item['balance'] as double, isIndented: true)),
            if ((liabilitiesData['Current Liabilities'] ?? []).length > 1)
              _buildSubtotalRow('Total Current Liabilities', currentLiabilitiesTotal),
          ],

          if (totalLiabilities == 0 && netProfit == 0)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No liabilities for this period',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalLiabilitiesWithProfit = totalLiabilities + (netProfit >= 0 ? netProfit : 0);
    final difference = (totalAssets - totalLiabilitiesWithProfit).abs();
    final isBalanced = difference < 0.01;

    return Scaffold(
      backgroundColor: const Color(0xFFE0F2E9),
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Balance Sheet',
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Period display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2C5545), width: 2),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'As on: ${_formatDate(endDate)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C5545),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (!isBalanced)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Difference: ₹${difference.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[900],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ASSETS SECTION
                  _buildSectionHeader('ASSETS', color: Colors.blue.shade700),
                  const SizedBox(height: 12),
                  _buildAssetsSection(),
                  _buildTotalRow('Total Assets', totalAssets, Colors.blue.shade700),
                  const SizedBox(height: 30),

                  // LIABILITIES SECTION
                  _buildSectionHeader('LIABILITIES & CAPITAL', color: Colors.orange.shade700),
                  const SizedBox(height: 12),
                  _buildLiabilitiesSection(),
                  _buildTotalRow('Total Liabilities', totalLiabilities, Colors.orange.shade700),
                  const SizedBox(height: 12),

                  // Net Profit/Loss
                  if (netProfit != 0)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: netProfit >= 0 ? Colors.green.shade100 : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: netProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            netProfit >= 0 ? 'Add: Net Profit' : 'Less: Net Loss',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: netProfit >= 0 ? Colors.green.shade900 : Colors.red.shade900,
                            ),
                          ),
                          Text(
                            netProfit.abs().toStringAsFixed(2),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: netProfit >= 0 ? Colors.green.shade900 : Colors.red.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  _buildTotalRow(
                    'Total Liabilities + Capital',
                    totalLiabilitiesWithProfit,
                    Colors.orange.shade700,
                  ),
                ],
              ),
            ),
    );
  }
}
