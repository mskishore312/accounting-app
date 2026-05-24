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
  static const Color _kDarkGreen = Color(0xFF2C5545);
  static const Color _kMidGreen = Color(0xFF4C7380);
  static const Color _kMint = Color(0xFFE0F2E9);

  bool isLoading = true;
  DateTime? startDate;
  DateTime? endDate;
  String? booksBeginningDate;
  String _companyName = '';

  Map<String, List<Map<String, dynamic>>> assetsData = {};
  Map<String, List<Map<String, dynamic>>> liabilitiesData = {};
  double totalAssets = 0;
  double totalLiabilities = 0;
  double netProfit = 0;

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

      final assets = await FinancialStatementService.getAssets(
        startDate: startDate,
        endDate: endDate,
        booksBeginningDate: booksBeginningDate,
      );
      final liabilities = await FinancialStatementService.getLiabilities(
        startDate: startDate,
        endDate: endDate,
        booksBeginningDate: booksBeginningDate,
      );

      double aTotal = 0;
      for (final category in assets.values) {
        for (final it in category) {
          aTotal += (it['balance'] as num).toDouble();
        }
      }
      double lTotal = 0;
      for (final category in liabilities.values) {
        for (final it in category) {
          lTotal += (it['balance'] as num).toDouble();
        }
      }

      if (!mounted) return;
      setState(() {
        assetsData = assets;
        liabilitiesData = liabilities;
        totalAssets = aTotal;
        totalLiabilities = lTotal;
        netProfit = pl['netProfit'] as double;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
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

  String _money(double v) => v.abs().toStringAsFixed(2);

  // ----- T-format building blocks (same style as P&L) -----

  Widget _sectionHeader(String title) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        color: _kDarkGreen,
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      );

  Widget _columnsHeader(String left, String right, double width) => Row(
        children: [
          _columnHeaderCell(left, width),
          Container(width: 1, color: _kDarkGreen),
          _columnHeaderCell(right, width),
        ],
      );

  Widget _columnHeaderCell(String text, double width) => Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        color: _kMidGreen,
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const Text(
              'Amount',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );

  Widget _groupLabel(String text, double width) => Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(color: _kMint.withOpacity(0.5)),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: _kDarkGreen,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
      );

  Widget _row(String name, double amount, double width) => Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontSize: 13, color: _kDarkGreen),
              ),
            ),
            Text(
              _money(amount),
              style: const TextStyle(
                fontSize: 13,
                color: _kDarkGreen,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );

  Widget _totalRow(String label, double amount, double width) => Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: const BoxDecoration(
          color: _kMint,
          border: Border(top: BorderSide(color: _kDarkGreen, width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: _kDarkGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              _money(amount),
              style: const TextStyle(
                fontSize: 13,
                color: _kDarkGreen,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );

  /// Build a flat list of widgets for one side, grouped by category.
  List<Widget> _buildSide(
    Map<String, List<Map<String, dynamic>>> data,
    double width, {
    Map<String, double>? extraItems, // e.g. Net Profit into Liabilities side
  }) {
    final widgets = <Widget>[];
    extraItems?.forEach((label, amount) {
      widgets.add(_groupLabel(' ', width));
      widgets.add(_row(label, amount, width));
    });
    data.forEach((category, items) {
      if (items.isEmpty) return;
      widgets.add(_groupLabel(category, width));
      for (final it in items) {
        widgets.add(_row(
          (it['name'] as String?) ?? '',
          (it['balance'] as num?)?.toDouble() ?? 0.0,
          width,
        ));
      }
    });
    if (widgets.isEmpty) {
      widgets.add(_row('(no entries)', 0, width));
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    const double colWidth = 280;

    // Net Profit goes on Liabilities side; Net Loss on Assets side
    final liabExtras = <String, double>{};
    final assetExtras = <String, double>{};
    if (netProfit >= 0) {
      liabExtras['Net Profit for the period'] = netProfit;
    } else {
      assetExtras['Net Loss for the period'] = netProfit.abs();
    }

    final liabRows = _buildSide(liabilitiesData, colWidth, extraItems: liabExtras);
    final assetRows = _buildSide(assetsData, colWidth, extraItems: assetExtras);

    // Pad shorter side
    final maxLen = liabRows.length > assetRows.length ? liabRows.length : assetRows.length;
    while (liabRows.length < maxLen) {
      liabRows.add(Container(
        width: colWidth,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      ));
    }
    while (assetRows.length < maxLen) {
      assetRows.add(Container(
        width: colWidth,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      ));
    }

    final pairedRows = <Widget>[];
    for (int i = 0; i < maxLen; i++) {
      pairedRows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            liabRows[i],
            Container(width: 1, color: _kDarkGreen),
            assetRows[i],
          ],
        ),
      ));
    }

    final totalLiabAndProfit = totalLiabilities + (netProfit >= 0 ? netProfit : 0);
    final totalAssetsAndLoss = totalAssets + (netProfit < 0 ? netProfit.abs() : 0);
    final maxTotal = totalLiabAndProfit > totalAssetsAndLoss ? totalLiabAndProfit : totalAssetsAndLoss;

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
          _companyName.isEmpty ? 'Balance Sheet' : _companyName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  color: _kMint,
                  child: Column(
                    children: [
                      const Text(
                        'Balance Sheet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _kDarkGreen,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'As at ${_formatDate(endDate)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _kDarkGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: _kDarkGreen, width: 1.5),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _sectionHeader('BALANCE SHEET'),
                                  _columnsHeader(
                                    'Liabilities',
                                    'Assets',
                                    colWidth,
                                  ),
                                  Container(height: 1, color: _kDarkGreen),
                                  ...pairedRows,
                                  IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        _totalRow('Total', maxTotal, colWidth),
                                        Container(width: 1, color: _kDarkGreen),
                                        _totalRow('Total', maxTotal, colWidth),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
