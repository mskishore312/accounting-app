import 'package:accounting_app/data/storage_service.dart';
import 'package:flutter/material.dart';

class InventoryItemsScreen extends StatefulWidget {
  const InventoryItemsScreen({super.key});

  @override
  State<InventoryItemsScreen> createState() => _InventoryItemsScreenState();
}

class _InventoryItemsScreenState extends State<InventoryItemsScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await StorageService.getInventoryItems();
    if (mounted) {
      setState(() {
        items = loaded;
        loading = false;
      });
    }
  }

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    final name = TextEditingController(text: existing?['name'] as String? ?? '');
    final hsn = TextEditingController(text: existing?['hsn'] as String? ?? '');
    final unit = TextEditingController(text: existing?['unit'] as String? ?? 'Nos');
    final rate = TextEditingController(
      text: (existing?['default_rate'] as num?)?.toStringAsFixed(2) ?? '',
    );
    final gst = TextEditingController(
      text: (existing?['gst_rate'] as num?)?.toString() ?? '18',
    );
    final stock = TextEditingController(
      text: (existing?['stock_qty'] as num?)?.toString() ?? '0',
    );
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'New inventory item' : 'Edit inventory item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: hsn, decoration: const InputDecoration(labelText: 'HSN/SAC')),
              TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unit')),
              TextField(controller: rate, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Default rate')),
              TextField(controller: gst, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'GST rate %')),
              TextField(controller: stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Opening/current quantity')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (save == true && name.text.trim().isNotEmpty) {
      await StorageService.saveInventoryItem({
        if (existing != null) 'id': existing['id'],
        'name': name.text.trim(),
        'hsn': hsn.text.trim(),
        'unit': unit.text.trim().isEmpty ? 'Nos' : unit.text.trim(),
        'default_rate': double.tryParse(rate.text) ?? 0,
        'gst_rate': double.tryParse(gst.text) ?? 0,
        'stock_qty': double.tryParse(stock.text) ?? 0,
      });
      await _load();
    }
    name.dispose();
    hsn.dispose();
    unit.dispose();
    rate.dispose();
    gst.dispose();
    stock.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Masters'),
        backgroundColor: const Color(0xFF2C5545),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('New Item'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(child: Text('No inventory items'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      child: ListTile(
                        onTap: () => _edit(item),
                        title: Text(item['name'] as String),
                        subtitle: Text(
                          'HSN ${item['hsn'] ?? '-'}  •  ${(item['stock_qty'] as num)} ${item['unit']}  •  GST ${item['gst_rate']}%',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            try {
                              await StorageService.deleteInventoryItem(item['id'] as int);
                              await _load();
                            } catch (_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Item is used in an invoice and cannot be deleted.')),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
