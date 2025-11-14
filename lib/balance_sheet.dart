import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';

class BalanceSheet extends StatefulWidget {
  const BalanceSheet({Key? key}) : super(key: key);

  @override
  State<BalanceSheet> createState() => _BalanceSheetState();
}

class _BalanceSheetState extends State<BalanceSheet> {
  bool isLoading = true;
  Map<String, List<Map<String, dynamic>>> balanceSheetData = {
    'assets': [],
    'liabilities': [],
  };
  double totalAssets = 0;
  double totalLiabilities = 0;

  @override
  void initState() {
    super.initState();
    _loadBalanceSheet();
  }

  Future<void> _loadBalanceSheet() async {
    try {
      final ledgers = await StorageService.getLedgers();
      double assetsTotal = 0;
      double liabilitiesTotal = 0;

      for (var ledger in ledgers) {
        final report = await StorageService.getLedgerReport(ledger['id'] as int);
        double balance = 0;

        for (var entry in report) {
          balance += (entry['debit'] as double? ?? 0) - (entry['credit'] as double? ?? 0);
        }

        if (balance != 0) {
          final classification = ledger['classification'] as String? ?? '';
          if (['Fixed Assets', 'Current Assets', 'Investments'].contains(classification)) {
            balanceSheetData['assets']!.add({
              'name': ledger['name'],
              'amount': balance.abs(),
              'type': classification,
            });
            assetsTotal += balance > 0 ? balance : 0;
          } else if (['Current Liabilities', 'Loans', 'Capital Account'].contains(classification)) {
            balanceSheetData['liabilities']!.add({
              'name': ledger['name'],
              'amount': balance.abs(),
              'type': classification,
            });
            liabilitiesTotal += balance < 0 ? balance.abs() : 0;
          }
        }
      }

      if (mounted) {
        setState(() {
          totalAssets = assetsTotal;
          totalLiabilities = liabilitiesTotal;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading balance sheet: $e')),
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
              const Color(0x1A2C5545),  // 10% opacity
            ),
            columns: const [
              DataColumn(label: Text('Particulars')),
              DataColumn(label: Text('Type')),
              DataColumn(
                label: Text('Amount'),
                numeric: true,
              ),
            ],
            rows: [
              ...data.map(
                (item) => DataRow(
                  cells: [
                    DataCell(Text(item['name'] as String)),
                    DataCell(Text(item['type'] as String)),
                    DataCell(Text(
                      (item['amount'] as double).toStringAsFixed(2),
                    )),
                  ],
                ),
              ),
              DataRow(
                color: MaterialStateProperty.all(
                  const Color(0x1A2C5545),  // 10% opacity
                ),
                cells: [
                  const DataCell(Text(
                    'Total',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  )),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Balance Sheet'),
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
                        'Balance Sheet as of ${DateTime.now().toString().split(' ')[0]}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildSection('Assets', balanceSheetData['assets']!, totalAssets),
                    _buildSection('Liabilities & Capital', balanceSheetData['liabilities']!, totalLiabilities),
                  ],
                ),
              ),
            ),
    );
  }
}
