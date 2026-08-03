import 'package:flutter/material.dart';
import 'package:accounting_app/services/financial_statement_service.dart';
import 'package:accounting_app/services/period_service.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/ui/widgets/date_range_selector.dart';
import 'package:accounting_app/ui/widgets/report_view_toggle.dart';
import 'package:accounting_app/ui/widgets/t_format_table.dart';
import 'package:accounting_app/ui/widgets/ledger_drilldown.dart';
import 'package:provider/provider.dart';

class TradingAndPL extends StatefulWidget {
  const TradingAndPL({Key? key}) : super(key: key);

  @override
  State<TradingAndPL> createState() => _TradingAndPLState();
}

class _TradingAndPLState extends State<TradingAndPL> {
  bool isLoading = true;
  ReportViewMode viewMode = ReportViewMode.condensed;
  StatementFormat statementFormat = StatementFormat.tFormat;
  DateTime? startDate;
  DateTime? endDate;
  String? booksBeginningDate;

  // Trading Account data
  List<Map<String, dynamic>> purchases = [];
  List<Map<String, dynamic>> directExpenses = [];
  List<Map<String, dynamic>> sales = [];
  List<Map<String, dynamic>> directIncome = [];
  List<Map<String, dynamic>> openingStockList = [];
  List<Map<String, dynamic>> closingStockList = [];
  double totalPurchases = 0;
  double totalDirectExpenses = 0;
  double totalSales = 0;
  double totalDirectIncome = 0;
  double openingStock = 0;
  double closingStock = 0;
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
          openingStockList =
              tradingData['openingStockList'] as List<Map<String, dynamic>>;
          closingStockList =
              tradingData['closingStockList'] as List<Map<String, dynamic>>;
          openingStock = tradingData['openingStock'] as double;
          closingStock = tradingData['closingStock'] as double;
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

  void _openLedger(String ledgerName) {
    openLedgerDrilldown(
      context,
      ledgerName: ledgerName,
      startDate: startDate,
      endDate: endDate,
    );
  }

  // --- Row building -------------------------------------------------

  List<StatementRow> _group(
    String heading,
    List<Map<String, dynamic>> items,
    double total,
  ) {
    if (items.isEmpty) return const [];
    final rows = <StatementRow>[StatementRow(heading, total, isGroup: true)];
    if (viewMode == ReportViewMode.detailed) {
      for (final item in items) {
        rows.add(StatementRow(
          item['name'] as String,
          item['balance'] as double,
          isIndented: true,
          ledgerName: item['name'] as String,
        ));
      }
    }
    return rows;
  }

  /// Trading Account: closes at gross profit/loss, which is then carried
  /// down into the Profit & Loss Account below it.
  Widget _buildTradingAccount() {
    final left = <StatementRow>[
      ..._group('Opening Stock', openingStockList, openingStock),
      ..._group('Purchase Accounts', purchases, totalPurchases),
      ..._group('Direct Expenses', directExpenses, totalDirectExpenses),
    ];
    final right = <StatementRow>[
      ..._group('Sales Accounts', sales, totalSales),
      ..._group('Direct Incomes', directIncome, totalDirectIncome),
      ..._group('Closing Stock', closingStockList, closingStock),
    ];

    if (grossProfit >= 0) {
      left.add(StatementRow('Gross Profit c/d', grossProfit, isGroup: true));
    } else {
      right.add(StatementRow('Gross Loss c/d', grossProfit.abs(), isGroup: true));
    }

    final debitTotal = openingStock +
        totalPurchases +
        totalDirectExpenses +
        (grossProfit >= 0 ? grossProfit : 0);
    final creditTotal = totalSales +
        totalDirectIncome +
        closingStock +
        (grossProfit < 0 ? grossProfit.abs() : 0);

    return TFormatTable(
      onLedgerTap: _openLedger,
      title: 'TRADING ACCOUNT',
      leftRows: left,
      rightRows: right,
      leftTotal: debitTotal,
      rightTotal: creditTotal,
      minimumRows: 6,
    );
  }

  /// Profit & Loss Account: opens with the gross result brought down and
  /// closes at the net profit/loss for the period.
  Widget _buildProfitAndLossAccount() {
    final left = <StatementRow>[
      if (grossProfit < 0)
        StatementRow('Gross Loss b/d', grossProfit.abs(), isGroup: true),
      ..._group('Indirect Expenses', indirectExpenses, totalIndirectExpenses),
    ];
    final right = <StatementRow>[
      if (grossProfit >= 0)
        StatementRow('Gross Profit b/d', grossProfit, isGroup: true),
      ..._group('Indirect Income', indirectIncome, totalIndirectIncome),
    ];

    if (netProfit >= 0) {
      left.add(StatementRow('Net Profit', netProfit, isGroup: true));
    } else {
      right.add(StatementRow('Net Loss', netProfit.abs(), isGroup: true));
    }

    final debitTotal = (grossProfit < 0 ? grossProfit.abs() : 0) +
        totalIndirectExpenses +
        (netProfit >= 0 ? netProfit : 0);
    final creditTotal = (grossProfit >= 0 ? grossProfit : 0) +
        totalIndirectIncome +
        (netProfit < 0 ? netProfit.abs() : 0);

    return TFormatTable(
      onLedgerTap: _openLedger,
      title: 'PROFIT & LOSS ACCOUNT',
      leftRows: left,
      rightRows: right,
      leftTotal: debitTotal,
      rightTotal: creditTotal,
      minimumRows: 5,
    );
  }

  Widget _buildTFormat() {
    return Column(
      children: [
        _buildTradingAccount(),
        const SizedBox(height: 16),
        _buildProfitAndLossAccount(),
        const SizedBox(height: 12),
        _resultBanner(),
      ],
    );
  }

  /// Companies Act 2013, Schedule III — Statement of Profit and Loss.
  Widget _buildScheduleIII() {
    final revenue = totalSales;
    final otherIncome = totalDirectIncome + totalIndirectIncome;
    final totalIncome = revenue + otherIncome;
    // A stock increase reduces the charge to the statement.
    final changeInInventories = openingStock - closingStock;
    final totalExpenses = totalPurchases +
        changeInInventories +
        totalDirectExpenses +
        totalIndirectExpenses;

    return Column(
      children: [
        ScheduleIIISection(
          title: 'I. INCOME',
          rows: [
            const StatementRow('Revenue from operations', null, isGroup: true),
            StatementRow('Sale of products / services', revenue,
                isIndented: true),
            if (viewMode == ReportViewMode.detailed)
              for (final item in sales)
                StatementRow('   ${item['name']}', item['balance'] as double,
                    isIndented: true),
            const StatementRow('Other income', null, isGroup: true),
            StatementRow('Other income', otherIncome, isIndented: true),
          ],
          total: totalIncome,
          totalLabel: 'Total Income',
        ),
        ScheduleIIISection(
          title: 'II. EXPENSES',
          rows: [
            StatementRow('Purchases of stock-in-trade', totalPurchases,
                isIndented: true),
            StatementRow(
              'Changes in inventories of stock-in-trade',
              changeInInventories,
              isIndented: true,
            ),
            StatementRow('Direct expenses', totalDirectExpenses,
                isIndented: true),
            StatementRow('Other expenses', totalIndirectExpenses,
                isIndented: true),
          ],
          total: totalExpenses,
          totalLabel: 'Total Expenses',
        ),
        ScheduleIIISection(
          title: 'III. PROFIT BEFORE TAX',
          rows: [
            StatementRow('Total income', totalIncome, isIndented: true),
            StatementRow('Less: total expenses', totalExpenses,
                isIndented: true),
          ],
          total: totalIncome - totalExpenses,
          totalLabel: netProfit >= 0 ? 'Profit for the period' : 'Loss for the period',
        ),
        _resultBanner(),
      ],
    );
  }

  Widget _resultBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFD5EADF),
        border: Border.all(color: kStatementGreen),
      ),
      child: Column(
        children: [
          Text(
            '${grossProfit >= 0 ? 'Gross Profit' : 'Gross Loss'}: '
            '${TFormatTable.formatAmount(grossProfit.abs())}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: kStatementGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${netProfit >= 0 ? 'Net Profit' : 'Net Loss'}: '
            '${TFormatTable.formatAmount(netProfit.abs())}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: kStatementGreen,
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
        backgroundColor: kStatementGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Profit & Loss',
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
                    'Curr. Period ${_formatDate(startDate)} to ${_formatDate(endDate)}',
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
                    child: statementFormat == StatementFormat.tFormat
                        ? _buildTFormat()
                        : _buildScheduleIII(),
                  ),
                ),
              ],
            ),
    );
  }
}
