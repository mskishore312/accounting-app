import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/ui/widgets/voucher_date_picker.dart';
import 'package:accounting_app/ui/widgets/voucher_number_field.dart';

import 'package:sqflite/sqflite.dart'; // Import sqflite for Database type

class ReceiptVoucherForm extends StatefulWidget {
  const ReceiptVoucherForm({Key? key}) : super(key: key);

  @override
  State<ReceiptVoucherForm> createState() => _ReceiptVoucherFormState();
}

class _ReceiptVoucherFormState extends State<ReceiptVoucherForm> {
  final _formKey = GlobalKey<FormState>();
  final _voucherNoController = TextEditingController();
  final _narrationController = TextEditingController();
  DateTime _date = DateTime.now();
  List<String> _selectedLedgers = [];
  List<Map<String, dynamic>> _ledgers = [];
  final List<TextEditingController> _amountControllers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLedgers();
  }

  void _initializeFirstLedger() {
    if (_ledgers.isNotEmpty && _selectedLedgers.isEmpty) {
      setState(() {
        _selectedLedgers.add(_ledgers.first['id'].toString());
        _amountControllers.add(TextEditingController());
      });
    }
  }

  @override
  void dispose() {
    _voucherNoController.dispose();
    _narrationController.dispose();
    for (final controller in _amountControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLedgers() async {
    try {
      final loadedLedgers = await StorageService.getLedgers();
      setState(() {
        _ledgers = loadedLedgers;
        _isLoading = false;
      });
      // Initialize with at least two ledgers
      if (_ledgers.length >= 2) {
        setState(() {
          _selectedLedgers.add(_ledgers[0]['id'].toString());
          _amountControllers.add(TextEditingController());
          _selectedLedgers.add(_ledgers[1]['id'].toString());
          _amountControllers.add(TextEditingController());
        });
      } else if (_ledgers.isNotEmpty) {
        setState(() {
          _selectedLedgers.add(_ledgers[0]['id'].toString());
          _amountControllers.add(TextEditingController());
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading ledgers: $e')),
        );
      }
    }
  }

  Future<void> _saveVoucher() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLedgers.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 2 ledgers')),
      );
      return;
    }

    int? voucherId; // Keep track of voucher ID
    Database? db; // Hold db instance

    try {
      final company = await StorageService.getSelectedCompany();
      if (company == null) throw Exception('No company selected');

      final voucherData = {
        'company_id': company['id'],
        'type': 'Receipt',
        'voucher_no': _voucherNoController.text,
        'date': _date.toIso8601String(),
        'narration': _narrationController.text,
        'total': _amountControllers.fold<double>(0, (sum, c) => sum + (double.tryParse(c.text) ?? 0.0)), // Safer fold
      };

      db = await StorageService().database; // Get db instance

      // --- Using db.insert again, but keeping all checks ---
      // --- Re-adding Transaction Wrapper for atomicity ---
      await db.transaction((txn) async {
        // Insert Voucher
        print('Inserting Voucher: $voucherData');
        voucherId = await txn.insert('Vouchers', {
          'company_id': voucherData['company_id'],
          'voucher_number': voucherData['voucher_no'],
          'voucher_date': voucherData['date'],
          'type': voucherData['type'],
          'total': voucherData['total'],
        });
        print('Inserted Voucher ID: $voucherId');

        if (voucherId == null || voucherId! <= 0) { // Added null check for voucherId!
           throw Exception('Failed to insert voucher header.');
        }

        // Insert Credit Entries
        for (int i = 0; i < _selectedLedgers.length; i++) {
          final ledgerIdString = _selectedLedgers[i];
          final amountString = _amountControllers[i].text;

          if (ledgerIdString == null || ledgerIdString.isEmpty) {
             throw Exception('Selected ledger ID string is null or empty at index $i.');
          }
          final ledgerId = int.tryParse(ledgerIdString.trim()); // Trim whitespace
          final amount = double.tryParse(amountString) ?? 0.0;

          if (ledgerId == null) {
            throw Exception('Failed to parse ledger ID "$ledgerIdString" into an integer at index $i.');
          }
          if (amount <= 0) {
             throw Exception('Invalid amount entered: ${amountString}');
          }

          final Map<String, Object?> entryData = {
            'voucher_id': voucherId, // Use non-nullable voucherId
            'ledger_id': ledgerId, // Use parsed int
            'description': voucherData['narration'] ?? '',
            'debit': 0.0,
            'credit': amount,
          };

          if (entryData['ledger_id'] == null) {
             throw Exception('Internal error: ledger_id is null just before insert at index $i.');
          }

          print('Inserting VoucherEntry (Credit) loop [$i]: $entryData');
          await txn.insert('VoucherEntries', entryData); // Use txn.insert
        }

        // Insert Debit (Cash) Entry
        final cashLedger = await txn.query( // Use txn.query
          'Ledgers',
          where: 'company_id = ? AND is_default = 1',
          whereArgs: [company['id']],
          limit: 1
        );

        if (cashLedger.isNotEmpty) {
          final cashLedgerIdObject = cashLedger.first['id']; // Get the object
          final narration = voucherData['narration'] ?? '';

          if (cashLedgerIdObject == null) {
            throw Exception('Default cash ledger found but its ID is NULL in the database.');
          }
          // Explicit type check
          if (cashLedgerIdObject is! int) {
             throw Exception('Default cash ledger ID is not an integer: Type is ${cashLedgerIdObject.runtimeType}');
          }
          final int cashLedgerId = cashLedgerIdObject; // Now safely cast


          double totalCreditAmount = 0.0;
          for (final controller in _amountControllers) {
            totalCreditAmount += double.tryParse(controller.text) ?? 0.0;
          }

          if (totalCreditAmount <= 0) {
             throw Exception('Total credit amount is zero or negative. Cannot create balancing debit entry.');
          }

          final Map<String, Object?> cashEntryData = {
            'voucher_id': voucherId, // Use non-nullable voucherId
            'ledger_id': cashLedgerId, // Use validated int ID
            'description': narration,
            'debit': totalCreditAmount,
            'credit': 0.0,
          };

           if (cashEntryData['ledger_id'] == null) {
             throw Exception('Internal error: cash ledger_id is null just before insert.');
          }

          print('Inserting VoucherEntry (Debit - Cash): $cashEntryData');
          await txn.insert('VoucherEntries', cashEntryData); // Use txn.insert
        } else {
          throw Exception('Default cash ledger not found for this company. Please configure one in settings.');
        }
      }); // End Transaction

      // --- End of db.insert section ---

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voucher saved successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Caught error during saveVoucher: $e');
      // Cleanup is handled by transaction rollback if it was active
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving voucher: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (rest of the build method remains unchanged) ...
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2E9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C5545),
        title: const Text('Receipt Voucher'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2C5545),
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xFF2C5545),
                        width: 1,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Create Receipt Voucher',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          VoucherNumberField(
                            controller: _voucherNoController,
                            voucherType: 'Receipt',
                            label: 'Voucher No',
                          ),
                          const SizedBox(height: 16),
                          VoucherDatePicker(
                            selectedDate: _date,
                            onDateChanged: (date) {
                              setState(() => _date = date);
                            },
                            label: 'Date',
                          ),
                          const SizedBox(height: 16),
                          _buildLabel('Ledgers:'),
                          Column(
                            children: [
                              ..._selectedLedgers.asMap().entries.map((entry) {
                                final index = entry.key;
                                return Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: DropdownButtonFormField<String>(
                                            value: _selectedLedgers[index],
                                            decoration: _buildInputDecoration('Receipt from'),
                                            items: _ledgers
                                                .map((e) => DropdownMenuItem(
                                                      value: e['id'].toString(),
                                                      child: Text(e['name'] as String),
                                                    ))
                                                .toList(),
                                            onChanged: (value) {
                                              setState(() => _selectedLedgers[index] = value!);
                                            },
                                            validator: (value) =>
                                                value == null ? 'Please select a ledger' : null,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                                          onPressed: () {
                                            setState(() {
                                              _selectedLedgers.removeAt(index);
                                              _amountControllers.removeAt(index);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    _buildLabel('Amount:'),
                                    TextFormField(
                                      controller: _amountControllers[index],
                                      decoration: _buildInputDecoration('Enter amount'),
                                      keyboardType: TextInputType.number,
                                      validator: (value) {
                                        if (value?.isEmpty == true) return 'Required';
                                        if (double.tryParse(value!) == null) {
                                          return 'Please enter a valid number';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                );
                              }).toList(),
                              ElevatedButton(
                                onPressed: () {
                                  if (_ledgers.isNotEmpty) {
                                    setState(() {
                                      _selectedLedgers.add(_ledgers.first['id'].toString());
                                      _amountControllers.add(TextEditingController());
                                    });
                                  }
                                },
                                child: const Text('Add Another Ledger'),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildLabel('Narration:'),
                          TextFormField(
                            controller: _narrationController,
                            decoration: _buildInputDecoration('Enter narration'),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _saveVoucher,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2C5545),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Save',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF2C5545),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2C5545)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: const Color(0x802C5545)),  // 50% opacity
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2C5545), width: 2),
      ),
    );
  }
}
