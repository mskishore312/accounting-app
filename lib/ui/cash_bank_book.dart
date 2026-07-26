import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/services/financial_statement_service.dart';
import 'package:accounting_app/ui/ledger_view.dart';

/// Cash/Bank Book: cash-in-hand, bank account and bank OD ledgers with
/// their closing balances. Tapping a ledger opens its ledger report.
class CashBankBook extends StatefulWidget {
  const CashBankBook({Key? key}) : super(key: key);

  @override
  State<CashBankBook> createState() => _CashBankBookState();
}

class _CashBankBookState extends State<CashBankBook> {
  static const List<String> _cashBankGroups = [
    'Cash-in-hand',
    'Bank Accounts',
    'Bank OD A/c',
  ];

  List<Map<String, dynamic>> _rows = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ledgers = await StorageService.getLedgers();
      final rows = <Map<String, dynamic>>[];
      for (final ledger in ledgers) {
        final classification = ledger['classification'] as String? ?? '';
        if (!_cashBankGroups.contains(classification)) continue;
        final opening = (ledger['balance'] as num?)?.toDouble() ?? 0.0;
        final signedOpening =
            FinancialStatementService.isDebitNature(classification)
                ? opening
                : -opening;
        final movement =
            await StorageService.getLedgerBalance(ledger['id'] as int);
        rows.add({
          ...ledger,
          'closing': signedOpening + movement,
        });
      }
      rows.sort((a, b) {
        final groupCompare = _cashBankGroups
            .indexOf(a['classification'] as String? ?? '')
            .compareTo(
                _cashBankGroups.indexOf(b['classification'] as String? ?? ''));
        if (groupCompare != 0) return groupCompare;
        return (a['name'] as String).compareTo(b['name'] as String);
      });
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading cash/bank book: $e')),
        );
      }
    }
  }

  Future<void> _openLedger(Map<String, dynamic> ledger) async {
    try {
      final report = await StorageService.getLedgerReport(ledger['id'] as int);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LedgerView(
            ledger: ledger,
            initialEntries: report,
          ),
        ),
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading ledger report: $e')),
        );
      }
    }
  }

  String _formatClosing(double closing) {
    final side = closing >= 0 ? 'Dr.' : 'Cr.';
    return '${closing.abs().toStringAsFixed(2)} $side';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2E9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C5545),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Cash/Bank Book',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const Center(
                  child: Text(
                    'No cash or bank ledgers found.',
                    style: TextStyle(fontSize: 16, color: Color(0xFF2C5545)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _rows.length,
                  separatorBuilder: (context, index) =>
                      const Divider(color: Color(0xFF2C5545), height: 1),
                  itemBuilder: (context, index) {
                    final row = _rows[index];
                    return InkWell(
                      onTap: () => _openLedger(row),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 24),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    row['name'] as String,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF2C5545),
                                    ),
                                  ),
                                  Text(
                                    row['classification'] as String? ?? '',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF4C7380),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _formatClosing(row['closing'] as double),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2C5545),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
