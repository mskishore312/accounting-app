import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';

/// Address Book: contact details (address, phone, GSTIN) for party ledgers.
/// Details are stored on the ledger and editable in place.
class AddressBook extends StatefulWidget {
  const AddressBook({Key? key}) : super(key: key);

  @override
  State<AddressBook> createState() => _AddressBookState();
}

class _AddressBookState extends State<AddressBook> {
  static const List<String> _partyGroups = [
    'Sundry Debtors',
    'Sundry Creditors',
  ];

  List<Map<String, dynamic>> _ledgers = [];
  bool _isLoading = true;
  bool _partiesOnly = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ledgers = await StorageService.getLedgers();
      ledgers.sort(
          (a, b) => (a['name'] as String).compareTo(b['name'] as String));
      if (!mounted) return;
      setState(() {
        _ledgers = ledgers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading address book: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _visibleLedgers => _partiesOnly
      ? _ledgers
          .where((l) =>
              _partyGroups.contains(l['classification'] as String? ?? ''))
          .toList()
      : _ledgers;

  Future<void> _editContact(Map<String, dynamic> ledger) async {
    final addressController =
        TextEditingController(text: ledger['address'] as String? ?? '');
    final contactController =
        TextEditingController(text: ledger['contact'] as String? ?? '');
    final gstinController =
        TextEditingController(text: ledger['gstin'] as String? ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          ledger['name'] as String,
          style: const TextStyle(
              color: Color(0xFF2C5545), fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: addressController,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contactController,
                keyboardType: TextInputType.phone,
                decoration:
                    const InputDecoration(labelText: 'Phone / Contact'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: gstinController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Tin/GST No'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save',
                style: TextStyle(
                    color: Color(0xFF2C5545), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (saved == true) {
      try {
        await StorageService.saveLedger({
          'id': ledger['id'],
          'address': addressController.text.trim(),
          'contact': contactController.text.trim(),
          'gstin': gstinController.text.trim(),
        });
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving contact details: $e')),
          );
        }
      }
    }
    addressController.dispose();
    contactController.dispose();
    gstinController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleLedgers;
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
          'Address Book',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          PopupMenuButton<bool>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: (value) => setState(() => _partiesOnly = value),
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: true,
                checked: _partiesOnly,
                child: const Text('Parties only'),
              ),
              CheckedPopupMenuItem(
                value: false,
                checked: !_partiesOnly,
                child: const Text('All ledgers'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : visible.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _partiesOnly
                          ? 'No party ledgers (Sundry Debtors/Creditors) found.\nUse the filter to show all ledgers.'
                          : 'No ledgers found.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16, color: Color(0xFF2C5545)),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: visible.length,
                  separatorBuilder: (context, index) =>
                      const Divider(color: Color(0xFF2C5545), height: 1),
                  itemBuilder: (context, index) {
                    final ledger = visible[index];
                    final details = [
                      ledger['address'] as String? ?? '',
                      ledger['contact'] as String? ?? '',
                      (ledger['gstin'] as String? ?? '').isEmpty
                          ? ''
                          : 'GST: ${ledger['gstin']}',
                    ].where((s) => s.isNotEmpty).join(' • ');
                    return InkWell(
                      onTap: () => _editContact(ledger),
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
                                    ledger['name'] as String,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF2C5545),
                                    ),
                                  ),
                                  if (details.isNotEmpty)
                                    Text(
                                      details,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF4C7380),
                                      ),
                                    )
                                  else
                                    const Text(
                                      'Tap to add contact details',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: Color(0xFF4C7380),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const Icon(Icons.edit_outlined,
                                color: Color(0xFF4C7380), size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
