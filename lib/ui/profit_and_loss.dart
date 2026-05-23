import 'package:flutter/material.dart';
import 'package:accounting_app/services/financial_statement_service.dart';
import 'package:accounting_app/services/period_service.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/ui/widgets/date_range_selector.dart';
import 'package:provider/provider.dart';

class ProfitAndLoss extends StatefulWidget {
  const ProfitAndLoss({Key? key}) : super(key: key);

  @override
  State<ProfitAndLoss> createState() => _ProfitAndLossState();
}

class _ProfitAndLossState extends State<ProfitAndLoss> {
  // App theme colors
  static const Color _kDarkGreen = Color(0xFF2C5545);
  static const Color _kMidGreen = Color(0xFF4C7380);
  static const Color _kMint = Color(0xFFE0F2E9);
  static const Color _kRowAlt = Color(0xFFC8E6D8);

  bool isLoading = true;
  DateTime? startDate;
  DateTime? endDate;
  String? booksBeginningDate;
  String _companyName = '';

  // Trading section
  List<Map<String, dynamic>> _purchases = [];
  List<Map<String, dynamic>> _directExpenses = [];
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _directIncome = [];
  double _totalPurchases = 0;
  double _totalDirectExpenses = 0;
  double _totalSales = 0;
  double _totalDirectIncome = 0;
  double _grossProfit = 0;

  // P&L section
  List<Map<String, dynamic>> _indirectExpenses = [];
  List<Map<String, dynamic>> _indirectIncome = [];
  double _totalIndirectExpenses = 0;
  double _totalIndirectIncome = 0;
  double _netProfit = 0;

  @override
  void initState() {
    super.initState();
    _initialise();
  }

  Future<void> _initialise() async {
    try {
      final company = await StorageService.getSelectedCompany();
      if (company != null) {
        booksBeginningDate = company['books_from'] as String?;
        _companyName = (company['name'] as String?) ?? '';
      }
    } catch (e) {
      debugPrint('Error loading company: $e');
    }
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      // Pick up period from PeriodService if not set locally
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

      final pl = await FinancialStatementService.calculateProfitAndLoss(
        startDate: startDate,
        endDate: endDate,
        booksBeginningDate: booksBeginningDate,
        grossProfit: trading['grossProfit'] as double,
      );

      if (!mounted) return;
      setState(() {
        _purchases = List<Map<String, dynamic>>.from(trading['purchases']);
        _directExpenses = List<Map<String, dynamic>>.from(trading['directExpenses']);
        _sales = List<Map<String, dynamic>>.from(trading['sales']);
        _directIncome = List<Map<String, dynamic>>.from(trading['directIncome']);
        _totalPurchases = trading['totalPurchases'] as double;
        _totalDirectExpenses = trading['totalDirectExpenses'] as double;
        _totalSales = trading['totalSales'] as double;
        _totalDirectIncome = trading['totalDirectIncome'] as double;
        _grossProfit = trading['grossProfit'] as double;

        _indirectExpenses = List<Map<String, dynamic>>.from(pl['indirectExpenses']);
        _indirectIncome = List<Map<String, dynamic>>.from(pl['indirectIncome']);
        _totalIndirectExpenses = pl['totalIndirectExpenses'] as double;
        _totalIndirectIncome = pl['totalIndirectIncome'] as double;
        _netProfit = pl['netProfit'] as double;

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading P&L: $e')),
      );
    }
  }

  void _showDatePicker() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: DateRangeSelector(
            initialStartDate: startDate,
            initialEndDate: endDate,
            showResetButton: true,
            onDateRangeSelected: (start, end) {
              setState(() {
                startDate = start;
                endDate = end;
              });
              _loadData();
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
            },
          ),
        );
      },
    );
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _money(double v) {
    final s = v.abs().toStringAsFixed(2);
    return v < 0 ? '($s)' : s;
  }

  // ---------- styled building blocks ----------

  Widget _sectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: const BoxDecoration(color: _kDarkGreen),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _subHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: const BoxDecoration(color: _kMidGreen),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _ledgerRow(String name, double amount, {bool alt = false}) {
    return Container(
      color: alt ? _kRowAlt : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 14, color: _kDarkGreen),
            ),
          ),
          Text(
            _money(amount),
            style: const TextStyle(
              fontSize: 14,
              color: _kDarkGreen,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _subtotalRow(String label, double amount) {
    return Container(
      color: _kMint,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: _kDarkGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            _money(amount),
            style: const TextStyle(
              fontSize: 14,
              color: _kDarkGreen,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _grandTotalRow(String label, double amount, {required bool positive}) {
    final colorBg = positive ? const Color(0xFFDFF5E1) : const Color(0xFFFCE4E4);
    final colorFg = positive ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: colorBg,
        border: Border.all(color: colorFg, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: colorFg,
              ),
            ),
          ),
          Text(
            _money(amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorFg,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyRow(String text) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.grey,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _renderItems(List<Map<String, dynamic>> items, {String emptyText = 'No entries'}) {
    if (items.isEmpty) return _emptyRow(emptyText);
    return Column(
      children: List.generate(items.length, (i) {
        final item = items[i];
        final name = (item['name'] as String?) ?? '';
        final bal = (item['balance'] as num?)?.toDouble() ?? 0.0;
        return _ledgerRow(name, bal, alt: i.isOdd);
      }),
    );
  }

  // ---------- page ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kMint,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _kDarkGreen,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _companyName.isEmpty ? 'Profit & Loss' : _companyName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            tooltip: 'Select Period',
            onPressed: _showDatePicker,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _kDarkGreen))
          : Column(
              children: [
                // Page title bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: _kMint,
                  child: const Text(
                    'Profit & Loss Account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _kDarkGreen,
                    ),
                  ),
                ),
                // Period strip
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  color: _kMint,
                  child: Text(
                    'Period: ${_formatDate(startDate)} – ${_formatDate(endDate)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _kDarkGreen,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: _kDarkGreen, width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          // ===== TRADING ACCOUNT =====
                          _sectionHeader('TRADING ACCOUNT'),

                          _subHeader('Sales'),
                          _renderItems(_sales, emptyText: 'No sales recorded'),
                          _subtotalRow('Total Sales', _totalSales),

                          _subHeader('Direct Income'),
                          _renderItems(_directIncome, emptyText: 'No direct income recorded'),
                          _subtotalRow('Total Direct Income', _totalDirectIncome),

                          _subHeader('Less: Purchases'),
                          _renderItems(_purchases, emptyText: 'No purchases recorded'),
                          _subtotalRow('Total Purchases', _totalPurchases),

                          _subHeader('Less: Direct Expenses'),
                          _renderItems(_directExpenses, emptyText: 'No direct expenses recorded'),
                          _subtotalRow('Total Direct Expenses', _totalDirectExpenses),

                          _grandTotalRow(
                            _grossProfit >= 0 ? 'Gross Profit c/d' : 'Gross Loss c/d',
                            _grossProfit,
                            positive: _grossProfit >= 0,
                          ),

                          const SizedBox(height: 12),

                          // ===== PROFIT & LOSS ACCOUNT =====
                          _sectionHeader('PROFIT & LOSS ACCOUNT'),

                          _subtotalRow(
                            _grossProfit >= 0 ? 'Gross Profit b/d' : 'Gross Loss b/d',
                            _grossProfit,
                          ),

                          _subHeader('Add: Indirect Income'),
                          _renderItems(_indirectIncome, emptyText: 'No indirect income'),
                          _subtotalRow('Total Indirect Income', _totalIndirectIncome),

                          _subHeader('Less: Indirect Expenses'),
                          _renderItems(_indirectExpenses, emptyText: 'No indirect expenses'),
                          _subtotalRow('Total Indirect Expenses', _totalIndirectExpenses),

                          _grandTotalRow(
                            _netProfit >= 0 ? 'NET PROFIT' : 'NET LOSS',
                            _netProfit,
                            positive: _netProfit >= 0,
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
