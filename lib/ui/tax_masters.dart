import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';

/// Tax Masters: ledgers under "Duties & Taxes" with add/edit support.
class TaxMasters extends StatefulWidget {
  const TaxMasters({Key? key}) : super(key: key);

  @override
  State<TaxMasters> createState() => _TaxMastersState();
}

class _TaxMastersState extends State<TaxMasters> {
  List<Map<String, dynamic>> _taxLedgers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ledgers = await StorageService.getLedgers();
      final taxLedgers = ledgers
          .where((l) => (l['classification'] as String? ?? '') == 'Duties & Taxes')
          .toList()
        ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      setState(() {
        _taxLedgers = taxLedgers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tax masters: $e')),
        );
      }
    }
  }

  Future<void> _editTaxLedger([Map<String, dynamic>? ledger]) async {
    final nameController =
        TextEditingController(text: ledger?['name'] as String? ?? '');
    final balanceController = TextEditingController(
        text: ledger == null
            ? ''
            : ((ledger['balance'] as num?)?.toDouble() ?? 0.0)
                .toStringAsFixed(2));

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          ledger == null ? 'New Tax Ledger' : 'Edit Tax Ledger',
          style: const TextStyle(
              color: Color(0xFF2C5545), fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. TDS Payable, Output CGST',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: balanceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Opening Balance (Cr.)',
                hintText: '0.00',
              ),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Under: Duties & Taxes',
                style: TextStyle(fontSize: 12, color: Color(0xFF4C7380)),
              ),
            ),
          ],
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
      final name = nameController.text.trim();
      if (name.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Name cannot be empty')),
          );
        }
      } else {
        try {
          final company = await StorageService.getSelectedCompany();
          if (company == null) throw Exception('No company selected');
          final balance = double.tryParse(balanceController.text) ?? 0.0;
          await StorageService.saveLedger({
            if (ledger != null) 'id': ledger['id'],
            if (ledger == null) 'company_id': company['id'],
            'name': name,
            'classification': 'Duties & Taxes',
            'balance': balance,
          });
          _load();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error saving tax ledger: $e')),
            );
          }
        }
      }
    }
    nameController.dispose();
    balanceController.dispose();
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
          'Tax Masters',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2C5545),
        onPressed: () => _editTaxLedger(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _taxLedgers.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No tax ledgers yet.\nTap + to create one under Duties & Taxes.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 16, color: Color(0xFF2C5545)),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _taxLedgers.length,
                  separatorBuilder: (context, index) =>
                      const Divider(color: Color(0xFF2C5545), height: 1),
                  itemBuilder: (context, index) {
                    final ledger = _taxLedgers[index];
                    return InkWell(
                      onTap: () => _editTaxLedger(ledger),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 24),
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
                              ((ledger['balance'] as num?)?.toDouble() ?? 0.0)
                                  .toStringAsFixed(2),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2C5545),
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

/// GST Tax Masters: manages the standard Output/Input GST ledgers used by
/// sales and purchase invoices.
class GstTaxMasters extends StatefulWidget {
  const GstTaxMasters({Key? key}) : super(key: key);

  @override
  State<GstTaxMasters> createState() => _GstTaxMastersState();
}

class _GstTaxMastersState extends State<GstTaxMasters> {
  static const List<String> _standardNames = [
    'Output CGST',
    'Output SGST',
    'Output IGST',
    'Input CGST',
    'Input SGST',
    'Input IGST',
  ];

  Map<String, Map<String, dynamic>> _existing = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ledgers = await StorageService.getLedgers();
      final existing = <String, Map<String, dynamic>>{};
      for (final ledger in ledgers) {
        final name = ledger['name'] as String;
        if (_standardNames.contains(name)) {
          existing[name] = ledger;
        }
      }
      setState(() {
        _existing = existing;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading GST masters: $e')),
        );
      }
    }
  }

  Future<void> _createMissing() async {
    try {
      final company = await StorageService.getSelectedCompany();
      if (company == null) throw Exception('No company selected');
      var created = 0;
      for (final name in _standardNames) {
        if (_existing.containsKey(name)) continue;
        await StorageService.saveLedger({
          'company_id': company['id'],
          'name': name,
          'classification': 'Duties & Taxes',
          'balance': 0.0,
        });
        created++;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(created == 0
                ? 'All standard GST ledgers already exist'
                : '$created GST ledger${created == 1 ? '' : 's'} created'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating GST ledgers: $e')),
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
          'GST Tax Masters',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'These ledgers are used automatically on GST sales and '
                    'purchase invoices.',
                    style: TextStyle(
                        fontSize: 13, color: const Color(0xFF2C5545).withAlpha(200)),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _standardNames.length,
                    separatorBuilder: (context, index) =>
                        const Divider(color: Color(0xFF2C5545), height: 1),
                    itemBuilder: (context, index) {
                      final name = _standardNames[index];
                      final exists = _existing.containsKey(name);
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 24),
                        child: Row(
                          children: [
                            Icon(
                              exists
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: exists
                                  ? Colors.green
                                  : const Color(0xFF4C7380),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF2C5545),
                                ),
                              ),
                            ),
                            Text(
                              exists ? 'Created' : 'Not created',
                              style: TextStyle(
                                fontSize: 13,
                                color: exists
                                    ? Colors.green
                                    : const Color(0xFF4C7380),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C5545),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _createMissing,
                      child: const Text(
                        'Create Missing GST Ledgers',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
