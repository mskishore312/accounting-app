import 'package:flutter/material.dart';
import 'package:accounting_app/services/financial_statement_service.dart';
import 'package:accounting_app/services/period_service.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/ui/widgets/date_range_selector.dart';
import 'package:accounting_app/ui/widgets/report_view_toggle.dart';
import 'package:accounting_app/ui/widgets/t_format_table.dart';
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
  ReportViewMode viewMode = ReportViewMode.condensed;
  StatementFormat statementFormat = StatementFormat.tFormat;

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

  // --- Row building -------------------------------------------------

  double _sum(List<Map<String, dynamic>> items) =>
      items.fold(0.0, (sum, item) => sum + (item['balance'] as double));

  /// Rows for one side of the T-format sheet: a line per category with
  /// its ledgers underneath when the detailed view is selected.
  List<StatementRow> _sideRows(Map<String, List<Map<String, dynamic>>> data) {
    final rows = <StatementRow>[];
    for (final entry in data.entries) {
      if (entry.value.isEmpty) continue;
      rows.add(StatementRow(entry.key, _sum(entry.value), isGroup: true));
      if (viewMode == ReportViewMode.detailed) {
        for (final item in entry.value) {
          rows.add(StatementRow(
            item['name'] as String,
            item['balance'] as double,
            isIndented: true,
          ));
        }
      }
    }
    return rows;
  }

  /// Every ledger on a side, keyed by its underlying group, so the
  /// Schedule III layout can regroup them.
  List<Map<String, dynamic>> _itemsInGroups(
    Map<String, List<Map<String, dynamic>>> data,
    List<String> groups,
  ) {
    return data.values
        .expand((items) => items)
        .where((item) => groups.contains(item['group'] as String? ?? ''))
        .toList();
  }

  List<StatementRow> _scheduleRows(
    Map<String, List<Map<String, dynamic>>> data,
    String label,
    List<String> groups,
  ) {
    final items = _itemsInGroups(data, groups);
    if (items.isEmpty) return const [];
    final rows = <StatementRow>[
      StatementRow(label, _sum(items), isIndented: true),
    ];
    if (viewMode == ReportViewMode.detailed) {
      for (final item in items) {
        rows.add(StatementRow(
          '   ${item['name']}',
          item['balance'] as double,
          isIndented: true,
        ));
      }
    }
    return rows;
  }

  /// Prefixes a heading to [rows], or drops the heading when empty.
  List<StatementRow> _headed(String heading, List<StatementRow> rows) {
    if (rows.isEmpty) return const [];
    return [StatementRow(heading, null, isGroup: true), ...rows];
  }

  // --- Views --------------------------------------------------------

  Widget _buildTFormat() {
    final liabilityRows = _sideRows(liabilitiesData);
    if (netProfit != 0) {
      liabilityRows.add(StatementRow(
        netProfit >= 0 ? 'Profit & Loss A/c (Net Profit)' : 'Profit & Loss A/c (Net Loss)',
        netProfit,
        isGroup: true,
      ));
    }
    return TFormatTable(
      leftRows: liabilityRows,
      rightRows: _sideRows(assetsData),
      leftTotal: totalLiabilities + netProfit,
      rightTotal: totalAssets,
    );
  }

  Widget _buildScheduleIII() {
    // Equity & liabilities. Headings only appear when they have content.
    final shareholderRows = <StatementRow>[
      ..._headed('Shareholders\' funds', [
        ..._scheduleRows(
            liabilitiesData, '(a) Share capital', ['Capital Account']),
        ..._scheduleRows(
            liabilitiesData, '(b) Reserves and surplus', ['Reserves & Surplus']),
        if (netProfit != 0)
          StatementRow(
            netProfit >= 0
                ? '(c) Surplus — profit for the period'
                : '(c) Deficit — loss for the period',
            netProfit,
            isIndented: true,
          ),
      ]),
      ..._headed('Non-current liabilities', [
        ..._scheduleRows(liabilitiesData, '(a) Long-term borrowings', [
          'Loans (Liability)',
          'Secured Loans',
          'Unsecured Loans',
        ]),
      ]),
      ..._headed('Current liabilities', [
        ..._scheduleRows(
            liabilitiesData, '(a) Short-term borrowings', ['Bank OD A/c']),
        ..._scheduleRows(
            liabilitiesData, '(b) Trade payables', ['Sundry Creditors']),
        ..._scheduleRows(liabilitiesData, '(c) Other current liabilities', [
          'Current Liabilities',
          'Duties & Taxes',
          'Provisions',
        ]),
      ]),
    ];

    final assetRows = <StatementRow>[
      ..._headed('Non-current assets', [
        ..._scheduleRows(
            assetsData, '(a) Property, plant and equipment', ['Fixed Assets']),
        ..._scheduleRows(
            assetsData, '(b) Non-current investments', ['Investments']),
        ..._scheduleRows(assetsData, '(c) Other non-current assets',
            ['Misc. Expenses (ASSET)']),
      ]),
      ..._headed('Current assets', [
        ..._scheduleRows(assetsData, '(a) Inventories', ['Stock-in-hand']),
        ..._scheduleRows(assetsData, '(b) Trade receivables', ['Sundry Debtors']),
        ..._scheduleRows(assetsData, '(c) Cash and cash equivalents', [
          'Cash-in-hand',
          'Bank Accounts',
        ]),
        ..._scheduleRows(assetsData, '(d) Short-term loans and advances', [
          'Loans & Advances (Asset)',
          'Deposits (Assets)',
        ]),
      ]),
    ];

    return Column(
      children: [
        ScheduleIIISection(
          title: 'I. EQUITY AND LIABILITIES',
          rows: shareholderRows,
          total: totalLiabilities + netProfit,
          totalLabel: 'TOTAL',
        ),
        ScheduleIIISection(
          title: 'II. ASSETS',
          rows: assetRows,
          total: totalAssets,
          totalLabel: 'TOTAL',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalLiabilitiesWithProfit = totalLiabilities + netProfit;
    final difference = (totalAssets - totalLiabilitiesWithProfit).abs();
    final isBalanced = difference < 0.01;

    return Scaffold(
      backgroundColor: const Color(0xFFE0F2E9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: kStatementGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Balance Sheet',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            tooltip: 'Select Period',
            onPressed: _showDateRangeDialog,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  color: const Color(0xFFE0F2E9),
                  child: Text(
                    'As on: ${_formatDate(endDate)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kStatementGreen,
                    ),
                  ),
                ),
                StatementFormatToggle(
                  format: statementFormat,
                  onChanged: (value) =>
                      setState(() => statementFormat = value),
                ),
                ReportViewToggle(
                  mode: viewMode,
                  onChanged: (mode) => setState(() => viewMode = mode),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        if (statementFormat == StatementFormat.tFormat)
                          _buildTFormat()
                        else
                          _buildScheduleIII(),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: isBalanced
                                ? const Color(0xFFD5EADF)
                                : Colors.red.shade100,
                            border: Border.all(
                              color: isBalanced
                                  ? kStatementGreen
                                  : Colors.red.shade700,
                            ),
                          ),
                          child: Text(
                            isBalanced
                                ? 'Balanced — both sides agree at ${TFormatTable.formatAmount(totalAssets)}'
                                : 'Out of balance by ${TFormatTable.formatAmount(difference)}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isBalanced
                                  ? kStatementGreen
                                  : Colors.red.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
