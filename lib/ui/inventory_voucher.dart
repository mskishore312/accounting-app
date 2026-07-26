import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:accounting_app/data/storage_service.dart';

/// Inventory voucher (stock journal): record stock received and consumed
/// per inventory item. Adjusts item quantities and keeps a movement history.
class InventoryVoucherList extends StatefulWidget {
  const InventoryVoucherList({Key? key}) : super(key: key);

  @override
  State<InventoryVoucherList> createState() => _InventoryVoucherListState();
}

class _InventoryVoucherListState extends State<InventoryVoucherList> {
  List<Map<String, dynamic>> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await StorageService.getStockJournal();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stock journal: $e')),
        );
      }
    }
  }

  String _formatDate(String isoDate) {
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(isoDate));
    } catch (_) {
      return isoDate;
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text(
          'Delete the ${_formatDate(entry['journal_date'] as String)} '
          'movement for "${entry['item_name']}"? '
          'The stock quantity adjustment will be reversed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await StorageService.deleteStockJournalEntry(entry['id'] as int);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting entry: $e')),
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
        title: const Text(
          'Inventory Vouchers',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2C5545),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const InventoryVoucherForm(),
            ),
          );
          _load();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No inventory vouchers yet.\nTap + to record stock in/out.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 16, color: Color(0xFF2C5545)),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _entries.length,
                  separatorBuilder: (context, index) =>
                      const Divider(color: Color(0xFF2C5545), height: 1),
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    final qtyIn = (entry['qty_in'] as num?)?.toDouble() ?? 0.0;
                    final qtyOut =
                        (entry['qty_out'] as num?)?.toDouble() ?? 0.0;
                    final unit = entry['item_unit'] as String? ?? '';
                    final movement = [
                      if (qtyIn > 0) 'In: ${qtyIn.toStringAsFixed(2)} $unit',
                      if (qtyOut > 0) 'Out: ${qtyOut.toStringAsFixed(2)} $unit',
                    ].join('  ');
                    return InkWell(
                      onLongPress: () => _confirmDelete(entry),
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
                                    entry['item_name'] as String,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF2C5545),
                                    ),
                                  ),
                                  Text(
                                    '${_formatDate(entry['journal_date'] as String)}'
                                    '${(entry['narration'] as String? ?? '').isEmpty ? '' : ' • ${entry['narration']}'}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF4C7380),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              movement,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: qtyIn >= qtyOut
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
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

class InventoryVoucherForm extends StatefulWidget {
  const InventoryVoucherForm({Key? key}) : super(key: key);

  @override
  State<InventoryVoucherForm> createState() => _InventoryVoucherFormState();
}

class _LineDraft {
  Map<String, dynamic>? item;
  final TextEditingController qtyIn = TextEditingController();
  final TextEditingController qtyOut = TextEditingController();

  void dispose() {
    qtyIn.dispose();
    qtyOut.dispose();
  }
}

class _InventoryVoucherFormState extends State<InventoryVoucherForm> {
  DateTime _date = DateTime.now();
  final TextEditingController _narration = TextEditingController();
  final List<_LineDraft> _lines = [_LineDraft()];
  List<Map<String, dynamic>> _items = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _narration.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _loadItems() async {
    try {
      final items = await StorageService.getInventoryItems();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading inventory items: $e')),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final lines = <Map<String, dynamic>>[];
    for (final line in _lines) {
      if (line.item == null) continue;
      final qtyIn = double.tryParse(line.qtyIn.text) ?? 0.0;
      final qtyOut = double.tryParse(line.qtyOut.text) ?? 0.0;
      if (qtyIn == 0 && qtyOut == 0) continue;
      lines.add({
        'item_id': line.item!['id'],
        'qty_in': qtyIn,
        'qty_out': qtyOut,
      });
    }
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add at least one item with a quantity')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await StorageService.saveStockJournal(
        journalDate: DateFormat('yyyy-MM-dd').format(_date),
        narration: _narration.text.trim(),
        lines: lines,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inventory voucher saved'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving voucher: $e')),
        );
      }
    }
  }

  Widget _buildLine(int index) {
    final line = _lines[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DropdownButtonFormField<int>(
              // ignore: deprecated_member_use
              value: line.item?['id'] as int?,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Item'),
              items: _items
                  .map(
                    (item) => DropdownMenuItem<int>(
                      value: item['id'] as int,
                      child: Text(
                        '${item['name']} (${(item['stock_qty'] as num?)?.toDouble().toStringAsFixed(2) ?? '0'} ${item['unit']})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (id) => setState(() {
                line.item = _items.firstWhere((item) => item['id'] == id);
              }),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: line.qtyIn,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Qty In (received)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: line.qtyOut,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Qty Out (issued)'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF4C7380)),
                  onPressed: _lines.length == 1
                      ? null
                      : () => setState(() {
                            _lines.removeAt(index).dispose();
                          }),
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
          'New Inventory Voucher',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: _items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No inventory items found.\nCreate items under Masters → Inventory Masters first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Color(0xFF2C5545)),
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.calendar_today,
                          color: Color(0xFF2C5545)),
                      title: Text(
                          'Date: ${DateFormat('dd/MM/yyyy').format(_date)}'),
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(_lines.length, _buildLine),
                  TextButton.icon(
                    onPressed: () => setState(() => _lines.add(_LineDraft())),
                    icon: const Icon(Icons.add, color: Color(0xFF2C5545)),
                    label: const Text('Add Item',
                        style: TextStyle(color: Color(0xFF2C5545))),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _narration,
                    decoration: const InputDecoration(
                      labelText: 'Narration',
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C5545),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Save Voucher',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
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
