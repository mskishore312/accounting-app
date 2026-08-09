import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/ledger_classifications.dart';
import 'package:accounting_app/services/ai_accounting_service.dart';

const Color _kGreen = Color(0xFF2C5545);
const Color _kBackground = Color(0xFFE0F2E9);
const Color _kIn = Color(0xFF2E7D32);
const Color _kOut = Color(0xFFC62828);
const Color _kReview = Color(0xFFB26A00);

/// Review screen for transactions the assistant read off a bank statement.
///
/// Everything here is editable and nothing is written until "Post" is pressed,
/// which is the whole point: the model's reading is a starting draft, not an
/// instruction. Rows it was unsure about are assigned anyway — to Suspense if
/// nothing better fits — but visibly flagged, so a statement is always
/// postable and never silently wrong.
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
  final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

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

  int get _needingReview =>
      _selected.where((r) => r.ledgerId == null || !r.confident).length;

  double get _totalIn => _selected
      .where((r) => r.isDeposit)
      .fold(0.0, (sum, r) => sum + r.amount);

  double get _totalOut => _selected
      .where((r) => !r.isDeposit)
      .fold(0.0, (sum, r) => sum + r.amount);

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
      // Auto-select must go through the same path as the dropdown, or rows
      // that matched this ledger during extraction stay pointed at it and
      // block the whole batch at Post time.
      if (banks.length == 1) _setBankLedger(banks.first['id'] as int);
    });
  }

  /// Point the statement at a bank ledger, releasing any row that had been
  /// matched to it. A row cannot be both sides of its own voucher, and
  /// narration matching does not know which ledger will be picked here.
  void _setBankLedger(int? id) {
    _bankLedgerId = id;
    if (id == null) return;
    for (final row in widget.rows) {
      if (row.ledgerId != id) continue;
      row.ledgerId = null;
      row.ledgerName = null;
      row.confident = false;
      row.suggestionLabel = 'Same as the bank ledger — choose another';
    }
  }

  /// All ledger groups, with the most likely counterparties first.
  static final List<String> _allGroups = () {
    const preferred = [
      'Indirect Expenses',
      'Direct Expenses',
      'Sundry Creditors',
      'Sundry Debtors',
      'Indirect Income',
      'Sales Accounts',
      'Purchase Accounts',
    ];
    final rest = LedgerClassifications.groupClassifications.keys
        .where((g) => !preferred.contains(g))
        .toList()
      ..sort();
    return [...preferred, ...rest];
  }();

  /// Create a ledger inline and adopt it immediately.
  Future<Map<String, dynamic>?> _createLedger({
    required List<String> groups,
    required String initialGroup,
    String? suggestedName,
  }) async {
    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CreateLedgerDialog(
        existing: _ledgers,
        groups: groups,
        initialGroup: initialGroup,
        suggestedName: suggestedName,
      ),
    );
    if (created == null || !mounted) return null;
    final ledgers = await StorageService.getLedgers();
    if (!mounted) return created;
    setState(() => _ledgers = ledgers);
    return created;
  }

  Future<void> _pickLedger(ProposedBankRow row) async {
    final chosen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LedgerPicker(
        title: row.description,
        candidates: _ledgers.where((l) => l['id'] != _bankLedgerId).toList(),
        onCreate: () => _createLedger(
          groups: _allGroups,
          initialGroup: 'Indirect Expenses',
          // Usually the account the statement is asking for.
          suggestedName: row.modelSuggestedName,
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() =>
        row.chooseLedger(chosen['id'] as int, chosen['name'] as String));
  }

  Future<void> _createBankLedger() async {
    final created = await _createLedger(
      groups: _bankClassifications,
      initialGroup: 'Bank Accounts',
    );
    if (created == null || !mounted) return;
    setState(() => _bankLedgerId = created['id'] as int);
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

  Future<void> _editAmount(ProposedBankRow row) async {
    final value = await showDialog<double>(
      context: context,
      builder: (_) => _AmountDialog(initial: row.amount),
    );
    if (value == null || value <= 0 || !mounted) return;
    setState(() => row.amount = value);
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
    return Scaffold(
      backgroundColor: _kBackground,
      appBar: AppBar(
        backgroundColor: _kGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Review transactions',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _loading
                ? null
                : () => setState(() {
                      final turnOn = _selected.length != widget.rows.length;
                      for (final r in widget.rows) {
                        r.selected = turnOn;
                      }
                    }),
            child: Text(
              _selected.length == widget.rows.length ? 'None' : 'All',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _summary(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: widget.rows.length,
                    itemBuilder: (_, i) => _rowCard(widget.rows[i]),
                  ),
                ),
                _footer(),
              ],
            ),
    );
  }

  Widget _summary() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  isExpanded: true,
                  value: _bankLedgerId,
                  decoration: InputDecoration(
                    labelText: 'Bank ledger for this statement',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    prefixIcon:
                        const Icon(Icons.account_balance, color: _kGreen),
                    helperText: _bankLedgers.isEmpty
                        ? 'No bank or cash ledger yet — create one'
                        : null,
                    helperStyle: const TextStyle(color: _kReview),
                  ),
                  items: _bankLedgers
                      .map((l) => DropdownMenuItem<int>(
                            value: l['id'] as int,
                            child: Text(l['name'] as String,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _setBankLedger(v)),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                tooltip: 'Create a bank or cash ledger',
                icon: const Icon(Icons.add, color: _kGreen),
                onPressed: _createBankLedger,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _total('Received', _totalIn, _kIn, Icons.south_west),
              const SizedBox(width: 8),
              _total('Paid', _totalOut, _kOut, Icons.north_east),
            ],
          ),
          if (_needingReview > 0) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kReview.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: _kReview),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$_needingReview of ${_selected.length} need a closer '
                      'look at the ledger',
                      style: const TextStyle(fontSize: 12, color: _kReview),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _total(String label, double value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(fontSize: 11, color: color)),
                  Text(
                    _money.format(value),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowCard(ProposedBankRow row) {
    final tone = row.isDeposit ? _kIn : _kOut;
    final dimmed = !row.selected;

    return Opacity(
      opacity: dimmed ? 0.5 : 1,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: row.selected && row.ledgerId == null
                ? _kReview
                : Colors.black12,
          ),
        ),
        child: Column(
          children: [
            // Top line: select, date, amount.
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
              child: Row(
                children: [
                  Checkbox(
                    value: row.selected,
                    activeColor: _kGreen,
                    visualDensity: VisualDensity.compact,
                    onChanged: (v) =>
                        setState(() => row.selected = v ?? false),
                  ),
                  InkWell(
                    onTap: () => _pickDate(row),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: Row(
                        children: [
                          Text(
                            DateFormat('dd MMM yyyy').format(row.date),
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _kGreen),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.edit_calendar,
                              size: 13, color: Colors.grey.shade500),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => _editAmount(row),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: Text(
                        '${row.isDeposit ? '+' : '−'} ${_money.format(row.amount)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: tone,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.description.isEmpty
                        ? 'Bank transaction'
                        : row.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade800, height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _directionChip(row, deposit: true),
                      const SizedBox(width: 6),
                      _directionChip(row, deposit: false),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _ledgerRow(row),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _directionChip(ProposedBankRow row, {required bool deposit}) {
    final on = row.isDeposit == deposit;
    final tone = deposit ? _kIn : _kOut;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => row.isDeposit = deposit),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: on ? tone : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? tone : Colors.black26),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(deposit ? Icons.south_west : Icons.north_east,
                size: 13, color: on ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              deposit ? 'Received' : 'Paid',
              style: TextStyle(
                fontSize: 12,
                fontWeight: on ? FontWeight.bold : FontWeight.normal,
                color: on ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ledgerRow(ProposedBankRow row) {
    final unassigned = row.ledgerId == null;
    final flag = unassigned || !row.confident;
    final tone = unassigned ? _kReview : (flag ? _kReview : _kGreen);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _pickLedger(row),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: flag ? const Color(0xFFFFF4E0) : const Color(0xFFF1F7F3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tone.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Icon(
              unassigned
                  ? Icons.help_outline
                  : (flag ? Icons.error_outline : Icons.check_circle_outline),
              size: 16,
              color: tone,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.ledgerName ?? 'Choose ledger',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: unassigned ? _kReview : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (row.suggestionLabel.isNotEmpty)
                    Text(
                      row.suggestionLabel,
                      style: TextStyle(
                          fontSize: 11,
                          color: flag ? _kReview : Colors.grey.shade600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }

  Widget _footer() {
    final selected = _selected;
    return Material(
      elevation: 8,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _kGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _posting || selected.isEmpty ? null : _post,
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
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Amount editor.
///
/// A widget rather than an inline builder so the controller's lifetime is tied
/// to the dialog's. Disposing it straight after `showDialog` returns is too
/// early — the exit animation is still rebuilding the field.
class _AmountDialog extends StatefulWidget {
  final double initial;

  const _AmountDialog({required this.initial});

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.initial.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(
        context,
        double.tryParse(_controller.text.replaceAll(',', '').trim()),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Amount'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          prefixText: '₹ ',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _kGreen),
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Searchable ledger chooser. Stateful for the same controller-lifetime
/// reason as [_AmountDialog].
class _LedgerPicker extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> candidates;

  /// Opens the inline create form and returns the new ledger, if any.
  final Future<Map<String, dynamic>?> Function() onCreate;

  const _LedgerPicker({
    required this.title,
    required this.candidates,
    required this.onCreate,
  });

  @override
  State<_LedgerPicker> createState() => _LedgerPickerState();
}

class _LedgerPickerState extends State<_LedgerPicker> {
  final _controller = TextEditingController();
  late List<Map<String, dynamic>> _filtered = widget.candidates;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = widget.candidates.where((l) {
        final name = (l['name'] as String).toLowerCase();
        final group = (l['classification'] as String? ?? '').toLowerCase();
        return name.contains(q) || group.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
              if (widget.title.isNotEmpty)
                Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: _kGreen),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Search ledger',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: _filter,
              ),
              const SizedBox(height: 4),
              // Front and centre: the account you need often does not exist
              // yet, and leaving to create it would lose the whole review.
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_circle_outline, color: _kGreen),
                title: const Text('Create a new ledger',
                    style: TextStyle(
                        color: _kGreen, fontWeight: FontWeight.w600)),
                onTap: () async {
                  final created = await widget.onCreate();
                  if (created != null && mounted) {
                    Navigator.pop(context, created);
                  }
                },
              ),
              const Divider(height: 1),
              Expanded(
                child: _filtered.isEmpty
                    ? const Center(child: Text('No matching ledgers'))
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) => ListTile(
                          dense: true,
                          title: Text(_filtered[i]['name'] as String),
                          subtitle: Text(
                              _filtered[i]['classification'] as String? ?? ''),
                          onTap: () => Navigator.pop(context, _filtered[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Create a ledger without leaving the review.
///
/// Losing a whole statement's worth of corrections just to add one missing
/// account is the reason this exists. [suggestedName] pre-fills whatever the
/// assistant proposed, which is usually the account that is actually missing.
class _CreateLedgerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> existing;
  final List<String> groups;
  final String initialGroup;
  final String? suggestedName;

  const _CreateLedgerDialog({
    required this.existing,
    required this.groups,
    required this.initialGroup,
    this.suggestedName,
  });

  @override
  State<_CreateLedgerDialog> createState() => _CreateLedgerDialogState();
}

class _CreateLedgerDialogState extends State<_CreateLedgerDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.suggestedName ?? '');
  late String _group = widget.initialGroup;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the ledger a name');
      return;
    }
    final clash = widget.existing.any(
      (l) => (l['name'] as String).toLowerCase() == name.toLowerCase(),
    );
    if (clash) {
      setState(() => _error = 'A ledger called "$name" already exists');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final company = await StorageService.getSelectedCompany();
      if (company == null) throw Exception('No company selected');
      final id = await StorageService.saveLedger({
        'company_id': company['id'],
        'name': name,
        'classification': _group,
        'balance': 0.0,
      });
      if (!mounted) return;
      Navigator.pop(context, <String, dynamic>{
        'id': id,
        'name': name,
        'classification': _group,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not create the ledger: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New ledger'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Ledger name',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _group,
            decoration: const InputDecoration(
              labelText: 'Under group',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: widget.groups
                .map((g) => DropdownMenuItem(
                      value: g,
                      child: Text(g, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _group = v ?? _group),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _kGreen),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
