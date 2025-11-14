import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProfitAndLoss();
  }

  Future<void> _loadProfitAndLoss() async {
    try {
      setState(() {
        isLoading = true;
      });

      final ledgers = await StorageService.getLedgers();
      double incomeTotal = 0;
      double expensesTotal = 0;

      for (var ledger in ledgers) {
        final report = await StorageService.getLedgerReport(ledger['id'] as int);
        double balance = 0;

        for (var entry in report) {
          balance += (entry['credit'] as double? ?? 0) - (entry['debit'] as double? ?? 0);
        }

        if (balance != 0) {
          final classification = ledger['classification'] as String? ?? '';
          if (['Income', 'Sales'].contains(classification)) {
            plData['income']!.add({
              'name': ledger['name'],
              'amount': balance.abs(),
              'type': classification,
            });
            incomeTotal += balance > 0 ? balance : 0;
          } else if (['Expenses', 'Purchases', 'Direct Expenses', 'Indirect Expenses'].contains(classification)) {
            plData['expenses']!.add({
              'name': ledger['name'],
              'amount': balance.abs(),
              'type': classification,
            });
            expensesTotal += balance < 0 ? balance.abs() : 0;
          }
        }
      }

      if (mounted) {
        setState(() {
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

  Widget _buildSection(String title, List<Map<String, dynamic>> items, double total) {
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
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item['name'] as String),
                      Text(
                        '₹${item['amount'].toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )),
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

  @override
  Widget build(BuildContext context) {
    final netProfit = totalIncome - totalExpenses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profit & Loss'),
        backgroundColor: const Color(0xFF4C7380),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
    );
  }
}
