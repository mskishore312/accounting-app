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
  static const Color _kDarkGreen = Color(0xFF2C5545);
  static const Color _kMidGreen = Color(0xFF4C7380);
  static const Color _kMint = Color(0xFFE0F2E9);

  bool isLoading = true;
  DateTime? startDate;
  DateTime? endDate;
  String? booksBeginningDate;
  String _companyName = '';

  List<Map<String, dynamic>> _purchases = [];
  List<Map<String, dynamic>> _directExpenses = [];
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _directIncome = [];
  double _totalPurchases = 0;
  double _totalDirectExpenses = 0;
  double _totalSales = 0;
  double _totalDirectIncome = 0;
  double _grossProfit = 0;

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

  String _money(double v) => v.abs().toStringAsFixed(2);

  // ----- T-format building blocks -----

  // Header bar spanning the full T
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

  // The two-column header strip ("Particulars / Amount" | "Particulars / Amount")
  Widget _columnsHeader(String left, String right, double colWidth) => Row(
        children: [
          _drCrCell(left, colWidth, isHeader: true),
          Container(width: 1, color: _kDarkGreen),
          _drCrCell(right, colWidth, isHeader: true),
        ],
      );

  Widget _drCrCell(String text, double width, {bool isHeader = false}) => Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        color: isHeader ? _kMidGreen : null,
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: isHeader ? Colors.white : _kDarkGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            Text(
              'Amount',
              style: TextStyle(
                color: isHeader ? Colors.white : _kDarkGreen,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );

  // Plain ledger row inside one column
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

  // Empty padding cell to balance column heights
  Widget _emptyCell(double width) => SizedBox(width: width);

  // Build a column of rows (used to pad shorter side)
  List<Widget> _itemRows(List<Map<String, dynamic>> items, double width) {
    return items.map((it) {
      return _row(
        (it['name'] as String?) ?? '',
        (it['balance'] as num?)?.toDouble() ?? 0.0,
        width,
      );
    }).toList();
  }

  // Subtotal/total row for one column
  Widget _totalRow(String label, double amount, double width, {bool bold = true}) =>
      Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: const BoxDecoration(
          color: _kMint,
          border: Border(
            top: BorderSide(color: _kDarkGreen, width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: _kDarkGreen,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            Text(
              _money(amount),
              style: TextStyle(
                fontSize: 13,
                color: _kDarkGreen,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );

  // ----- Build a T-block -----
  //
  // [leftItems]  = entries shown in Dr. column (e.g. expenses)
  // [rightItems] = entries shown in Cr. column (e.g. income)
  // [leftTotal] / [rightTotal] = totals to display at the bottom of each column
  // [leftBalancing] / [rightBalancing] = balancing figure (Gross Profit c/d etc.)
  //   shown ABOVE total. Pass null to omit.
  Widget _buildTBlock({
    required String title,
    required String leftHeader,
    required String rightHeader,
    required List<List<Map<String, dynamic>>> leftGroups,  // each group = subsection
    required List<String> leftGroupTitles,
    required List<List<Map<String, dynamic>>> rightGroups,
    required List<String> rightGroupTitles,
    required double leftTotal,
    required double rightTotal,
    String? leftBalancingLabel,
    double? leftBalancingAmount,
    String? rightBalancingLabel,
    double? rightBalancingAmount,
    required double colWidth,
  }) {
    // Flatten each side into a list of widget rows so we can pad equal heights.
    List<Widget> buildSide({
      required List<List<Map<String, dynamic>>> groups,
      required List<String> groupTitles,
      required double width,
    }) {
      final widgets = <Widget>[];
      for (int g = 0; g < groups.length; g++) {
        widgets.add(_groupLabel(groupTitles[g], width));
        if (groups[g].isEmpty) {
          widgets.add(_row('(none)', 0, width));
        } else {
          widgets.addAll(_itemRows(groups[g], width));
        }
      }
      return widgets;
    }

    final leftRows = buildSide(
      groups: leftGroups,
      groupTitles: leftGroupTitles,
      width: colWidth,
    );
    final rightRows = buildSide(
      groups: rightGroups,
      groupTitles: rightGroupTitles,
      width: colWidth,
    );

    // Pad shorter side with empty rows so the totals line up
    final maxLen = leftRows.length > rightRows.length
        ? leftRows.length
        : rightRows.length;
    while (leftRows.length < maxLen) {
      leftRows.add(Container(
        width: colWidth,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      ));
    }
    while (rightRows.length < maxLen) {
      rightRows.add(Container(
        width: colWidth,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      ));
    }

    // Pair each row index across both columns into a Row
    final pairs = <Widget>[];
    for (int i = 0; i < maxLen; i++) {
      pairs.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            leftRows[i],
            Container(width: 1, color: _kDarkGreen),
            rightRows[i],
          ],
        ),
      ));
    }

    // Balancing figures (e.g. Gross Profit c/d) appear above totals
    Widget balancingRow() {
      if (leftBalancingLabel == null && rightBalancingLabel == null) {
        return const SizedBox.shrink();
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            leftBalancingLabel != null
                ? _totalRow(leftBalancingLabel, leftBalancingAmount ?? 0, colWidth)
                : SizedBox(
                    width: colWidth,
                    child: Container(color: _kMint),
                  ),
            Container(width: 1, color: _kDarkGreen),
            rightBalancingLabel != null
                ? _totalRow(rightBalancingLabel, rightBalancingAmount ?? 0, colWidth)
                : SizedBox(
                    width: colWidth,
                    child: Container(color: _kMint),
                  ),
          ],
        ),
      );
    }

    // Totals row
    final totalsRow = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _totalRow('Total', leftTotal, colWidth),
          Container(width: 1, color: _kDarkGreen),
          _totalRow('Total', rightTotal, colWidth),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _kDarkGreen, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(title),
          _columnsHeader(leftHeader, rightHeader, colWidth),
          Container(height: 1, color: _kDarkGreen),
          ...pairs,
          balancingRow(),
          totalsRow,
        ],
      ),
    );
  }

  Widget _groupLabel(String text, double width) => Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: _kMint.withOpacity(0.5),
        ),
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

  // ----- Page -----

  @override
  Widget build(BuildContext context) {
    // Column width for the T-format — wide enough that both columns won't
    // be readable side-by-side on phone, so we wrap the whole T in a
    // horizontal scroll view.
    const double colWidth = 280;

    // Trading totals (Dr. side and Cr. side must balance after Gross P/L)
    final tradingDrSide = _totalPurchases + _totalDirectExpenses;
    final tradingCrSide = _totalSales + _totalDirectIncome;
    final tradingTotal = tradingDrSide > tradingCrSide ? tradingDrSide : tradingCrSide;

    // P&L totals (Dr. side and Cr. side must balance after Net P/L)
    final plDrSide = _totalIndirectExpenses + (_grossProfit < 0 ? _grossProfit.abs() : 0);
    final plCrSide = _totalIndirectIncome + (_grossProfit > 0 ? _grossProfit : 0);
    final plTotal = plDrSide > plCrSide ? plDrSide : plCrSide;

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
                        'Profit & Loss Account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _kDarkGreen,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'For the period ${_formatDate(startDate)} to ${_formatDate(endDate)}',
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
                    // Vertical scroll for the page
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                      child: SingleChildScrollView(
                        // Horizontal scroll so the T fits on the phone
                        scrollDirection: Axis.horizontal,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTBlock(
                              title: 'TRADING ACCOUNT',
                              leftHeader: 'Dr. — Particulars',
                              rightHeader: 'Cr. — Particulars',
                              leftGroups: [_purchases, _directExpenses],
                              leftGroupTitles: const [
                                'To Purchases',
                                'To Direct Expenses',
                              ],
                              rightGroups: [_sales, _directIncome],
                              rightGroupTitles: const [
                                'By Sales',
                                'By Direct Income',
                              ],
                              // Balancing figure goes on the side with the smaller subtotal
                              leftBalancingLabel: _grossProfit > 0 ? 'To Gross Profit c/d' : null,
                              leftBalancingAmount: _grossProfit > 0 ? _grossProfit : null,
                              rightBalancingLabel: _grossProfit < 0 ? 'By Gross Loss c/d' : null,
                              rightBalancingAmount: _grossProfit < 0 ? _grossProfit.abs() : null,
                              leftTotal: tradingTotal,
                              rightTotal: tradingTotal,
                              colWidth: colWidth,
                            ),
                            const SizedBox(height: 16),
                            _buildTBlock(
                              title: 'PROFIT & LOSS ACCOUNT',
                              leftHeader: 'Dr. — Particulars',
                              rightHeader: 'Cr. — Particulars',
                              leftGroups: [
                                if (_grossProfit < 0)
                                  [
                                    {'name': 'Gross Loss b/d', 'balance': _grossProfit.abs()}
                                  ],
                                _indirectExpenses,
                              ],
                              leftGroupTitles: [
                                if (_grossProfit < 0) ' ',
                                'To Indirect Expenses',
                              ],
                              rightGroups: [
                                if (_grossProfit > 0)
                                  [
                                    {'name': 'Gross Profit b/d', 'balance': _grossProfit}
                                  ],
                                _indirectIncome,
                              ],
                              rightGroupTitles: [
                                if (_grossProfit > 0) ' ',
                                'By Indirect Income',
                              ],
                              leftBalancingLabel: _netProfit > 0 ? 'To Net Profit' : null,
                              leftBalancingAmount: _netProfit > 0 ? _netProfit : null,
                              rightBalancingLabel: _netProfit < 0 ? 'By Net Loss' : null,
                              rightBalancingAmount: _netProfit < 0 ? _netProfit.abs() : null,
                              leftTotal: plTotal,
                              rightTotal: plTotal,
                              colWidth: colWidth,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: colWidth * 2 + 1,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              decoration: BoxDecoration(
                                color: _kMint,
                                border: Border.all(color: _kDarkGreen, width: 1.5),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _netProfit >= 0 ? 'NET PROFIT' : 'NET LOSS',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: _kDarkGreen,
                                    ),
                                  ),
                                  Text(
                                    _money(_netProfit),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _kDarkGreen,
                                      fontFeatures: [FontFeature.tabularFigures()],
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
