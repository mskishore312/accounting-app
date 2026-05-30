import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/services/financial_statement_service.dart';

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
  DateTime _asOf = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadBalanceSheet();
  }

  Future<void> _loadBalanceSheet() async {
    try {
      final company = await StorageService.getSelectedCompany();
      final rawBooks = company?['books_from'] as String?;
      // books_from may be ISO8601 (e.g. 2024-04-01T00:00:00.000); parse robustly.
      final parsed = rawBooks != null ? DateTime.tryParse(rawBooks) : null;
      final startDate = parsed != null
          ? DateTime(parsed.year, parsed.month, parsed.day)
          : DateTime(2000, 1, 1);
      // Build the gate string the exact same way the service formats startDate,
      // so opening balances (held on the ledger) are always picked up.
      final booksBeginningDate =
          '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
      final endDate = DateTime.now();

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
      final netProfit = pl['netProfit'] as double;

      // Flatten assets
      final assetRows = <Map<String, dynamic>>[];
      double assetsTotal = 0;
      assets.forEach((category, items) {
        for (final it in items) {
          final amt = (it['balance'] as num).toDouble();
          assetRows.add({
            'name': it['name'],
            'type': it['group'],
            'amount': amt,
          });
          assetsTotal += amt;
        }
      });

      // Flatten liabilities
      final liabRows = <Map<String, dynamic>>[];
      double liabilitiesTotal = 0;
      liabilities.forEach((category, items) {
        for (final it in items) {
          final amt = (it['balance'] as num).toDouble();
          liabRows.add({
            'name': it['name'],
            'type': it['group'],
            'amount': amt,
          });
          liabilitiesTotal += amt;
        }
      });

      // Net Profit increases Capital (Liabilities side); Net Loss sits on Assets.
      if (netProfit >= 0) {
        if (netProfit != 0) {
          liabRows.add({
            'name': 'Net Profit',
            'type': 'Capital Account',
            'amount': netProfit,
          });
          liabilitiesTotal += netProfit;
        }
      } else {
        assetRows.add({
          'name': 'Net Loss',
          'type': 'Profit & Loss A/c',
          'amount': netProfit.abs(),
        });
        assetsTotal += netProfit.abs();
      }

      if (mounted) {
        setState(() {
          balanceSheetData['assets'] = assetRows;
          balanceSheetData['liabilities'] = liabRows;
          totalAssets = assetsTotal;
          totalLiabilities = liabilitiesTotal;
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

  @override
  Widget build(BuildContext context) {
    final asOfStr = _asOf.toString().split(' ')[0];
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
                        'Balance Sheet as of $asOfStr',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Liabilities & Capital on top
                    _buildSection('Liabilities & Capital',
                        balanceSheetData['liabilities']!, totalLiabilities),
                    _buildSection(
                        'Assets', balanceSheetData['assets']!, totalAssets),
                  ],
                ),
              ),
            ),
    );
  }
}
