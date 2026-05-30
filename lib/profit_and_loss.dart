import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/services/financial_statement_service.dart';

class ProfitAndLoss extends StatefulWidget {
  const ProfitAndLoss({Key? key}) : super(key: key);

  @override
  State<ProfitAndLoss> createState() => _ProfitAndLossState();
}

class _ProfitAndLossState extends State<ProfitAndLoss> {
  bool isLoading = true;

  List<Map<String, dynamic>> incomeRows = [];
  List<Map<String, dynamic>> expenseRows = [];
  double totalIncome = 0;
  double totalExpenses = 0;
  double grossProfit = 0;
  double netProfit = 0;
  DateTime _asOf = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadProfitAndLoss();
  }

  Future<void> _loadProfitAndLoss() async {
    try {
      final company = await StorageService.getSelectedCompany();
      final rawBooks = company?['books_from'] as String?;
      // books_from may be ISO8601 (e.g. 2024-04-01T00:00:00.000); parse robustly.
      final parsed = rawBooks != null ? DateTime.tryParse(rawBooks) : null;
      final startDate = parsed != null
          ? DateTime(parsed.year, parsed.month, parsed.day)
          : DateTime(2000, 1, 1);
      final booksBeginningDate =
          '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
      final endDate = DateTime.now();

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

      final income = <Map<String, dynamic>>[];
      double incomeTotal = 0;
      void addAll(List src, String type) {
        for (final it in src) {
          final amt = (it['balance'] as num).toDouble();
          income.add({'name': it['name'], 'type': type, 'amount': amt});
          incomeTotal += amt;
        }
      }
      addAll(trading['sales'] as List, 'Sales');
      addAll(trading['directIncome'] as List, 'Direct Income');
      addAll(pl['indirectIncome'] as List, 'Indirect Income');

      final expenses = <Map<String, dynamic>>[];
      double expenseTotal = 0;
      void addAllExp(List src, String type) {
        for (final it in src) {
          final amt = (it['balance'] as num).toDouble();
          expenses.add({'name': it['name'], 'type': type, 'amount': amt});
          expenseTotal += amt;
        }
      }
      addAllExp(trading['purchases'] as List, 'Purchases');
      addAllExp(trading['directExpenses'] as List, 'Direct Expenses');
      addAllExp(pl['indirectExpenses'] as List, 'Indirect Expenses');

      if (mounted) {
        setState(() {
          incomeRows = income;
          expenseRows = expenses;
          totalIncome = incomeTotal;
          totalExpenses = expenseTotal;
          grossProfit = trading['grossProfit'] as double;
          netProfit = pl['netProfit'] as double;
          _asOf = endDate;
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

  Widget _buildSection(String title, List<Map<String, dynamic>> data, double total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C5545),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(
              const Color(0x1A2C5545),
            ),
            columns: const [
              DataColumn(label: Text('Particulars')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Amount'), numeric: true),
            ],
            rows: [
              ...data.map(
                (item) => DataRow(
                  cells: [
                    DataCell(Text(item['name'] as String)),
                    DataCell(Text(item['type'] as String)),
                    DataCell(Text((item['amount'] as double).toStringAsFixed(2))),
                  ],
                ),
              ),
              DataRow(
                color: MaterialStateProperty.all(const Color(0x1A2C5545)),
                cells: [
                  const DataCell(Text('Total',
                      style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataCell(Text('')),
                  DataCell(Text(
                    total.toStringAsFixed(2),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultRow(String label, double amount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C5545),
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
            amount.abs().toStringAsFixed(2),
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

  @override
  Widget build(BuildContext context) {
    final asOfStr = _asOf.toString().split(' ')[0];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profit & Loss'),
        backgroundColor: const Color(0xFF4C7380),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              color: const Color(0xFFE0F2E9),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Profit & Loss as of $asOfStr',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildSection('Income', incomeRows, totalIncome),
                    _buildSection('Expenses', expenseRows, totalExpenses),
                    const SizedBox(height: 12),
                    _buildResultRow(
                        grossProfit >= 0 ? 'Gross Profit' : 'Gross Loss',
                        grossProfit),
                    _buildResultRow(
                        netProfit >= 0 ? 'Net Profit' : 'Net Loss', netProfit),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}
