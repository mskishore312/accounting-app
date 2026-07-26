import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/services/financial_statement_service.dart';
import 'package:accounting_app/ui/ledger_view.dart';

/// Group Summary: account groups with their net closing balances.
/// Tapping a group drills down to its ledgers.
class GroupSummary extends StatefulWidget {
  const GroupSummary({Key? key}) : super(key: key);

  @override
  State<GroupSummary> createState() => _GroupSummaryState();
}

class _GroupSummaryState extends State<GroupSummary> {
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ledgers = await StorageService.getLedgers();
      final byGroup = <String, List<Map<String, dynamic>>>{};
      for (final ledger in ledgers) {
        final classification =
            ledger['classification'] as String? ?? 'Primary';
        final opening = (ledger['balance'] as num?)?.toDouble() ?? 0.0;
        final signedOpening =
            FinancialStatementService.isDebitNature(classification)
                ? opening
                : -opening;
        final movement =
            await StorageService.getLedgerBalance(ledger['id'] as int);
        byGroup.putIfAbsent(classification, () => []).add({
          ...ledger,
          'closing': signedOpening + movement,
        });
      }
      final groups = byGroup.entries.map((entry) {
        final total = entry.value
            .fold<double>(0.0, (sum, l) => sum + (l['closing'] as double));
        return <String, dynamic>{
          'name': entry.key,
          'ledgers': entry.value,
          'count': entry.value.length,
          'total': total,
        };
      }).toList()
        ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading group summary: $e')),
        );
      }
    }
  }

  String _formatAmount(double amount) {
    final side = amount >= 0 ? 'Dr.' : 'Cr.';
    return '${amount.abs().toStringAsFixed(2)} $side';
  }

  void _openGroup(Map<String, dynamic> group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _GroupLedgers(
          groupName: group['name'] as String,
          ledgers:
              (group['ledgers'] as List).cast<Map<String, dynamic>>(),
        ),
      ),
    ).then((_) => _load());
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
          'Group Summary',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? const Center(
                  child: Text(
                    'No ledgers found.',
                    style: TextStyle(fontSize: 16, color: Color(0xFF2C5545)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _groups.length,
                  separatorBuilder: (context, index) =>
                      const Divider(color: Color(0xFF2C5545), height: 1),
                  itemBuilder: (context, index) {
                    final group = _groups[index];
                    return InkWell(
                      onTap: () => _openGroup(group),
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
                                    group['name'] as String,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF2C5545),
                                    ),
                                  ),
                                  Text(
                                    '${group['count']} ledger${group['count'] == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF4C7380),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _formatAmount(group['total'] as double),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2C5545),
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: Color(0xFF4C7380)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _GroupLedgers extends StatelessWidget {
  final String groupName;
  final List<Map<String, dynamic>> ledgers;

  const _GroupLedgers({required this.groupName, required this.ledgers});

  String _formatAmount(double amount) {
    final side = amount >= 0 ? 'Dr.' : 'Cr.';
    return '${amount.abs().toStringAsFixed(2)} $side';
  }

  Future<void> _openLedger(
      BuildContext context, Map<String, dynamic> ledger) async {
    try {
      final report = await StorageService.getLedgerReport(ledger['id'] as int);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LedgerView(
            ledger: ledger,
            initialEntries: report,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading ledger report: $e')),
        );
      }
    }
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
        title: Text(
          groupName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: ledgers.length,
        separatorBuilder: (context, index) =>
            const Divider(color: Color(0xFF2C5545), height: 1),
        itemBuilder: (context, index) {
          final ledger = ledgers[index];
          return InkWell(
            onTap: () => _openLedger(context, ledger),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ledger['name'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2C5545),
                      ),
                    ),
                  ),
                  Text(
                    _formatAmount(ledger['closing'] as double),
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
