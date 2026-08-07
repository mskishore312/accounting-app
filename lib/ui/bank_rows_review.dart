import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/services/ai_accounting_service.dart';

const Color _kGreen = Color(0xFF2C5545);

/// Review screen for transactions the assistant read off a bank statement.
///
/// Everything here is editable and nothing is written until "Post" is pressed,
/// which is the whole point: the model's reading is a starting draft, not an
/// instruction.
class BankRowsReview extends StatefulWidget {
  final List<ProposedBankRow> rows;
  final AiAccountingService service;

  const BankRowsReview({
    super.key,
    required this.rows,
    required this.service,
  });

  @override
  State<BankRowsReview> createState() => _BankRowsReviewState();
}

class _BankRowsReviewState extends State<BankRowsReview> {
  List<Map<String, dynamic>> _ledgers = [];
  int? _bankLedgerId;
  bool _loading = true;
  bool _posting = false;

  static const _bankClassifications = [
    'Bank Accounts',
    'Bank OD A/c',
    'Cash-in-hand',
  ];

  List<Map<String, dynamic>> get _bankLedgers => _ledgers
      .where((l) =>
          _bankClassifications.contains(l['classification'] as String? ?? ''))
      .toList();

  List<ProposedBankRow> get _selected =>
      widget.rows.where((r) => r.selected).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ledgers = await StorageService.getLedgers();
    if (!mounted) return;
    setState(() {
      _ledgers = ledgers;
      _loading = false;
      final banks = _bankLedgers;
      if (banks.length == 1) _bankLedgerId = banks.first['id'] as int;
    });
  }

  Future<void> _pickLedger(ProposedBankRow row) async {
    final candidates =
        _ledgers.where((l) => l['id'] != _bankLedgerId).toList();
    var filtered = List<Map<String, dynamic>>.from(candidates);
    final controller = TextEditingController();

    final chosen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
            ),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.7,
              child: Column(
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Search ledger',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (query) => setSheetState(() {
                      final q = query.trim().toLowerCase();
                      filtered = candidates.where((l) {
                        final name = (l['name'] as String).toLowerCase();
                        final group =
                            (l['classification'] as String? ?? '').toLowerCase();
                        return name.contains(q) || group.contains(q);
                      }).toList();
                    }),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No matching ledgers'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) => ListTile(
                              title: Text(filtered[i]['name'] as String),
                              subtitle: Text(
                                  filtered[i]['classification'] as String? ?? ''),
                              onTap: () =>
                                  Navigator.pop(sheetContext, filtered[i]),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    controller.dispose();
    if (chosen == null || !mounted) return;
    setState(() {
      row.ledgerId = chosen['id'] as int;
      row.ledgerName = chosen['name'] as String;
    });
  }

  Future<void> _pickDate(ProposedBankRow row) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: row.date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => row.date = picked);
  }

  Future<void> _post() async {
    if (_bankLedgerId == null) {
      _toast('Choose the bank ledger this statement belongs to.');
      return;
    }
    setState(() => _posting = true);
    try {
      final count = await widget.service.postBankRows(
        bankLedgerId: _bankLedgerId!,
        rows: widget.rows,
      );
      if (!mounted) return;
      Navigator.pop(context, count);
    } on AiDraftException catch (e) {
      if (!mounted) return;
      setState(() => _posting = false);
      _toast(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _posting = false);
      _toast('Nothing was posted: $e');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final unassigned = selected.where((r) => r.ledgerId == null).length;

    return Scaffold(
      backgroundColor: const Color(0xFFE0F2E9),
      appBar: AppBar(
        backgroundColor: _kGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Review transactions',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: _bankLedgerId,
                    decoration: const InputDecoration(
                      labelText: 'Bank ledger for this statement',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: _bankLedgers
                        .map((l) => DropdownMenuItem<int>(
                              value: l['id'] as int,
                              child: Text(l['name'] as String,
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _bankLedgerId = v;
                      for (final r in widget.rows) {
                        if (r.ledgerId == v) r.ledgerId = null;
                      }
                    }),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: widget.rows.length,
                    itemBuilder: (_, i) => _rowCard(widget.rows[i]),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (unassigned > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '$unassigned selected row(s) still need a ledger.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.amber.shade900),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: _kGreen,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed:
                                _posting || selected.isEmpty ? null : _post,
                            icon: _posting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.post_add),
                            label: Text(
                              _posting
                                  ? 'Posting…'
                                  : 'Post ${selected.length} transaction(s)',
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

  Widget _rowCard(ProposedBankRow row) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: row.selected,
                  activeColor: _kGreen,
                  onChanged: (v) =>
                      setState(() => row.selected = v ?? false),
                ),
                InkWell(
                  onTap: () => _pickDate(row),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(row.date),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    initialValue: row.amount.toStringAsFixed(2),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.end,
                    decoration: const InputDecoration(
                      prefixText: '₹ ',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      final parsed =
                          double.tryParse(v.replaceAll(',', '').trim());
                      setState(() => row.amount = parsed ?? 0);
                    },
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Text(row.description,
                  maxLines: 3, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedButton<bool>(
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        selectedBackgroundColor: _kGreen,
                        selectedForegroundColor: Colors.white,
                      ),
                      segments: const [
                        ButtonSegment(value: true, label: Text('Received')),
                        ButtonSegment(value: false, label: Text('Paid')),
                      ],
                      selected: {row.isDeposit},
                      onSelectionChanged: (s) =>
                          setState(() => row.isDeposit = s.first),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: InkWell(
                onTap: () => _pickLedger(row),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Counterparty ledger',
                    helperText: row.ledgerId != null
                        ? null
                        : row.unmatchedSuggestion != null
                            ? 'Suggested "${row.unmatchedSuggestion}" — no such ledger'
                            : 'Not identified — choose one',
                    helperStyle: TextStyle(color: Colors.amber.shade900),
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(
                    row.ledgerName ?? 'Choose ledger',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: row.ledgerId == null ? Colors.grey.shade600 : null,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
