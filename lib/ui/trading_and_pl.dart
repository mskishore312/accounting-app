import 'package:flutter/material.dart';
import 'package:accounting_app/services/financial_statement_service.dart';
import 'package:accounting_app/services/period_service.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/ui/widgets/date_range_selector.dart';
import 'package:provider/provider.dart';

class TradingAndPL extends StatefulWidget {
  const TradingAndPL({Key? key}) : super(key: key);

  @override
  State<TradingAndPL> createState() => _TradingAndPLState();
}

class _TradingAndPLState extends State<TradingAndPL> {
  bool isLoading = true;
  DateTime? startDate;
  DateTime? endDate;
  String? booksBeginningDate;

  // Trading Account data
  List<Map<String, dynamic>> purchases = [];
  List<Map<String, dynamic>> directExpenses = [];
  List<Map<String, dynamic>> sales = [];
  List<Map<String, dynamic>> directIncome = [];
  double totalPurchases = 0;
  double totalDirectExpenses = 0;
  double totalSales = 0;
  double totalDirectIncome = 0;
  double grossProfit = 0;

  // P&L Account data
  List<Map<String, dynamic>> indirectExpenses = [];
  List<Map<String, dynamic>> indirectIncome = [];
  double totalIndirectExpenses = 0;
  double totalIndirectIncome = 0;
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

      // Calculate Trading Account
      final tradingData = await FinancialStatementService.calculateTradingAccount(
        startDate: startDate,
        endDate: endDate,
        booksBeginningDate: booksBeginningDate,
      );

      // Calculate P&L Account
      final plData = await FinancialStatementService.calculateProfitAndLoss(
        startDate: startDate,
        endDate: endDate,
        booksBeginningDate: booksBeginningDate,
        grossProfit: tradingData['grossProfit'] as double,
      );

      if (mounted) {
        setState(() {
          // Trading Account
          purchases = tradingData['purchases'] as List<Map<String, dynamic>>;
          directExpenses = tradingData['directExpenses'] as List<Map<String, dynamic>>;
          sales = tradingData['sales'] as List<Map<String, dynamic>>;
          directIncome = tradingData['directIncome'] as List<Map<String, dynamic>>;
          totalPurchases = tradingData['totalPurchases'] as double;
          totalDirectExpenses = tradingData['totalDirectExpenses'] as double;
          totalSales = tradingData['totalSales'] as double;
          totalDirectIncome = tradingData['totalDirectIncome'] as double;
          grossProfit = tradingData['grossProfit'] as double;

          // P&L Account
          indirectExpenses = plData['indirectExpenses'] as List<Map<String, dynamic>>;
          indirectIncome = plData['indirectIncome'] as List<Map<String, dynamic>>;
          totalIndirectExpenses = plData['totalIndirectExpenses'] as double;
          totalIndirectIncome = plData['totalIndirectIncome'] as double;
          netProfit = plData['netProfit'] as double;

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

  Widget _buildSectionHeader(String title, {Color? backgroundColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFF4C7380),
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

  Widget _buildAccountItem(String name, double amount, {bool isSubtotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isSubtotal ? 8 : 16,
        vertical: 6,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: isSubtotal ? 15 : 14,
                fontWeight: isSubtotal ? FontWeight.w600 : FontWeight.normal,
                color: const Color(0xFF2C5545),
              ),
            ),
          ),
          Text(
            amount.toStringAsFixed(2),
            style: TextStyle(
              fontSize: isSubtotal ? 15 : 14,
              fontWeight: isSubtotal ? FontWeight.w600 : FontWeight.normal,
              color: const Color(0xFF2C5545),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {Color? backgroundColor, Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFFC8E6D8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor ?? const Color(0xFF2C5545),
            ),
          ),
          Text(
            amount.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor ?? const Color(0xFF2C5545),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2E9),
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Trading & Profit/Loss Account',
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
                    child: Text(
                      'For the period: ${_formatDate(startDate)} to ${_formatDate(endDate)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C5545),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ============ TRADING ACCOUNT ============
                  _buildSectionHeader('TRADING ACCOUNT', backgroundColor: const Color(0xFF2C5545)),
                  const SizedBox(height: 12),

                  // Debit Side (Expenses)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8, left: 8),
                          child: Text(
                            'Debit (Dr.)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        // Purchases
                        if (purchases.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text(
                              'Purchases:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2C5545),
                              ),
                            ),
                          ),
                          ...purchases.map((item) => _buildAccountItem(
                                '  ${item['name']}',
                                item['balance'] as double,
                              )),
                          if (purchases.length > 1)
                            _buildAccountItem('Total Purchases', totalPurchases, isSubtotal: true),
                        ],
                        // Direct Expenses
                        if (directExpenses.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text(
                              'Direct Expenses:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2C5545),
                              ),
                            ),
                          ),
                          ...directExpenses.map((item) => _buildAccountItem(
                                '  ${item['name']}',
                                item['balance'] as double,
                              )),
                          if (directExpenses.length > 1)
                            _buildAccountItem('Total Direct Expenses', totalDirectExpenses, isSubtotal: true),
                        ],
                        if (purchases.isEmpty && directExpenses.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text(
                              'No direct expenses for this period',
                              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Credit Side (Income)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8, left: 8),
                          child: Text(
                            'Credit (Cr.)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        // Sales
                        if (sales.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text(
                              'Sales:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2C5545),
                              ),
                            ),
                          ),
                          ...sales.map((item) => _buildAccountItem(
                                '  ${item['name']}',
                                item['balance'] as double,
                              )),
                          if (sales.length > 1)
                            _buildAccountItem('Total Sales', totalSales, isSubtotal: true),
                        ],
                        // Direct Income
                        if (directIncome.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text(
                              'Direct Income:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2C5545),
                              ),
                            ),
                          ),
                          ...directIncome.map((item) => _buildAccountItem(
                                '  ${item['name']}',
                                item['balance'] as double,
                              )),
                          if (directIncome.length > 1)
                            _buildAccountItem('Total Direct Income', totalDirectIncome, isSubtotal: true),
                        ],
                        if (sales.isEmpty && directIncome.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text(
                              'No sales or direct income for this period',
                              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Gross Profit/Loss
                  _buildTotalRow(
                    grossProfit >= 0 ? 'Gross Profit' : 'Gross Loss',
                    grossProfit.abs(),
                    backgroundColor: grossProfit >= 0 ? Colors.green.shade100 : Colors.red.shade100,
                    textColor: grossProfit >= 0 ? Colors.green.shade900 : Colors.red.shade900,
                  ),
                  const SizedBox(height: 30),

                  // ============ PROFIT & LOSS ACCOUNT ============
                  _buildSectionHeader('PROFIT & LOSS ACCOUNT', backgroundColor: const Color(0xFF2C5545)),
                  const SizedBox(height: 12),

                  // Debit Side (Indirect Expenses)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8, left: 8),
                          child: Text(
                            'Debit (Dr.)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        // Gross Loss (if any)
                        if (grossProfit < 0) ...[
                          const SizedBox(height: 8),
                          _buildAccountItem('Gross Loss b/d', grossProfit.abs(), isSubtotal: true),
                        ],
                        // Indirect Expenses
                        if (indirectExpenses.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text(
                              'Indirect Expenses:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2C5545),
                              ),
                            ),
                          ),
                          ...indirectExpenses.map((item) => _buildAccountItem(
                                '  ${item['name']}',
                                item['balance'] as double,
                              )),
                          if (indirectExpenses.length > 1)
                            _buildAccountItem('Total Indirect Expenses', totalIndirectExpenses, isSubtotal: true),
                        ],
                        if (grossProfit >= 0 && indirectExpenses.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text(
                              'No indirect expenses for this period',
                              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Credit Side (Indirect Income + Gross Profit)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8, left: 8),
                          child: Text(
                            'Credit (Cr.)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        // Gross Profit (if any)
                        if (grossProfit > 0) ...[
                          const SizedBox(height: 8),
                          _buildAccountItem('Gross Profit c/d', grossProfit, isSubtotal: true),
                        ],
                        // Indirect Income
                        if (indirectIncome.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text(
                              'Indirect Income:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2C5545),
                              ),
                            ),
                          ),
                          ...indirectIncome.map((item) => _buildAccountItem(
                                '  ${item['name']}',
                                item['balance'] as double,
                              )),
                          if (indirectIncome.length > 1)
                            _buildAccountItem('Total Indirect Income', totalIndirectIncome, isSubtotal: true),
                        ],
                        if (grossProfit <= 0 && indirectIncome.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text(
                              'No indirect income for this period',
                              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Net Profit/Loss
                  _buildTotalRow(
                    netProfit >= 0 ? 'Net Profit' : 'Net Loss',
                    netProfit.abs(),
                    backgroundColor: netProfit >= 0 ? Colors.green.shade100 : Colors.red.shade100,
                    textColor: netProfit >= 0 ? Colors.green.shade900 : Colors.red.shade900,
                  ),
                  const SizedBox(height: 20),

                  // Summary Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF2C5545), const Color(0xFF4C7380)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'SUMMARY',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white, thickness: 1),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Gross Profit:',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              grossProfit >= 0
                                  ? '+₹${grossProfit.toStringAsFixed(2)}'
                                  : '-₹${grossProfit.abs().toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: grossProfit >= 0 ? Colors.lightGreenAccent : Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Net Profit:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              netProfit >= 0
                                  ? '+₹${netProfit.toStringAsFixed(2)}'
                                  : '-₹${netProfit.abs().toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: netProfit >= 0 ? Colors.lightGreenAccent : Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
