import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/ui/ledger_creation.dart';

class JournalVoucher extends StatefulWidget {
  final int? voucherId;
  
  const JournalVoucher({Key? key, this.voucherId}) : super(key: key);

  @override
  State<JournalVoucher> createState() => _JournalVoucherState();
}

class _JournalVoucherState extends State<JournalVoucher> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _narrationController = TextEditingController();
  final _voucherNumberController = TextEditingController();
  
  List<Map<String, dynamic>> allLedgers = [];
  
  // Lists to store multiple debit and credit entries
  List<DebitEntry> debitEntries = [];
  List<CreditEntry> creditEntries = [];
  
  double totalDebits = 0.0;
  double totalCredits = 0.0;
  bool _isEditMode = false;
  Map<String, dynamic>? _existingVoucher;
  List<Map<String, dynamic>> _existingEntries = [];

  @override
  void initState() {
    super.initState();
    _loadLedgers();
    
    // Check if we're editing an existing voucher
    if (widget.voucherId != null) {
      _isEditMode = true;
      _loadExistingVoucher();
    } else {
      _loadNextVoucherNumber();
      
      // Format date as DD/MM/YYYY
      final now = DateTime.now();
      _dateController.text = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
      
      // Add initial empty entries
      debitEntries.add(DebitEntry(
        controller: TextEditingController(),
        selectedLedger: null,
      ));
      
      creditEntries.add(CreditEntry(
        controller: TextEditingController(),
        selectedLedger: null,
      ));
    }
  }
  
  Future<void> _loadExistingVoucher() async {
    try {
      // Get the voucher data
      final vouchers = await StorageService.getVouchers();
      final voucher = vouchers.firstWhere((v) => v['id'] == widget.voucherId);
      _existingVoucher = voucher;
      
      // Set voucher number and date
      _voucherNumberController.text = voucher['voucher_number'] as String;
      
      // Convert date from YYYY-MM-DD to DD/MM/YYYY
      final dateStr = voucher['voucher_date'] as String;
      final dateParts = dateStr.split('-');
      if (dateParts.length == 3) {
        _dateController.text = "${dateParts[2]}/${dateParts[1]}/${dateParts[0]}";
      }
      
      // First load the ledgers
      await _loadLedgers();
      
      // Clear existing entries
      for (var entry in debitEntries) {
        entry.controller.dispose();
      }
      for (var entry in creditEntries) {
        entry.controller.dispose();
      }
      debitEntries.clear();
      creditEntries.clear();
      
      // Add a debit entry
      final controller1 = TextEditingController();
      controller1.text = voucher['total'].toString();
      
      debitEntries.add(DebitEntry(
        controller: controller1,
        selectedLedger: null, // Don't set the selectedLedger yet
      ));
      
      // Add a credit entry
      final controller2 = TextEditingController();
      controller2.text = voucher['total'].toString();
      
      creditEntries.add(CreditEntry(
        controller: controller2,
        selectedLedger: null, // Don't set the selectedLedger yet
      ));
      
      // Get the voucher entries to retrieve the narration
      final voucherEntries = await StorageService.getVoucherEntries(widget.voucherId!);
      
      // Get narration from the first entry that has a description
      if (voucherEntries.isNotEmpty) {
        for (var entry in voucherEntries) {
          if (entry['description'] != null && (entry['description'] as String).isNotEmpty) {
            _narrationController.text = entry['description'] as String;
            break;
          }
        }
      }
      
      // Calculate totals
      _calculateTotals();
      
      // Set the selected ledgers after a short delay to ensure the dropdowns are built
      Future.delayed(Duration(milliseconds: 100), () async {
        if (!mounted) return;
        
        setState(() {
          // For journal vouchers, we need to set both debit and credit entries
          if (allLedgers.isNotEmpty) {
            // For debit entry, use the first ledger as a default
            if (debitEntries.isNotEmpty) {
              debitEntries[0].selectedLedger = allLedgers[0]['name'] as String;
            }
            
            // For credit entry, use the particulars from the voucher if available
            if (creditEntries.isNotEmpty && voucher['particulars'] != null && (voucher['particulars'] as String).isNotEmpty) {
              // Find the ledger with the matching name
              for (var ledger in allLedgers) {
                if (ledger['name'] == voucher['particulars']) {
                  creditEntries[0].selectedLedger = ledger['name'] as String;
                  break;
                }
              }
              
              // If no matching ledger was found, use the second ledger (if available)
              if (creditEntries[0].selectedLedger == null && allLedgers.length > 1) {
                creditEntries[0].selectedLedger = allLedgers[1]['name'] as String;
              } else if (creditEntries[0].selectedLedger == null) {
                // If only one ledger is available, use it for both entries
                creditEntries[0].selectedLedger = allLedgers[0]['name'] as String;
              }
            }
          }
        });
      });
    } catch (e) {
      print('Error loading existing voucher: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading voucher: $e')),
        );
      }
    }
  }
  
  Future<void> _loadNextVoucherNumber() async {
    try {
      final nextNumber = await StorageService.getNextVoucherNumber('Journal');
      setState(() {
        _voucherNumberController.text = nextNumber;
      });
    } catch (e) {
      print('Error getting next voucher number: $e');
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _narrationController.dispose();
    _voucherNumberController.dispose();
    
    // Dispose all controllers in entries
    for (var entry in debitEntries) {
      entry.controller.dispose();
    }
    for (var entry in creditEntries) {
      entry.controller.dispose();
    }
    
    super.dispose();
  }

  Future<void> _loadLedgers() async {
    try {
      // Get all ledgers for the current company
      final loadedLedgers = await StorageService.getLedgers();
      
      setState(() {
        allLedgers = loadedLedgers;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading ledgers: $e')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    // Retrieve the company's "Books Beginning From" date.
    DateTime booksFrom = DateTime(2000); // default fallback
    final comp = await StorageService.getSelectedCompany();
    if (comp != null && comp['books_from'] != null) {
      final parts = (comp['books_from'] as String).split('/');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]) ?? 1;
        final month = int.tryParse(parts[1]) ?? 1;
        final year = int.tryParse(parts[2]) ?? DateTime.now().year;
        booksFrom = DateTime(year, month, day);
      }
    }
    final initialDate = DateTime.now().isBefore(booksFrom) ? booksFrom : DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: booksFrom,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      if (picked.isBefore(booksFrom)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Date cannot be before the Books Beginning From date')),
        );
      } else {
        setState(() {
          _dateController.text = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
        });
      }
    }
  }

  Future<void> _navigateToLedgerCreation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LedgerCreation(),
      ),
    );
    
    if (result == true) {
      // Reload ledgers if a new one was created
      _loadLedgers();
    }
  }
  
  void _calculateTotals() {
    double debits = 0.0;
    double credits = 0.0;
    
    for (var entry in debitEntries) {
      if (entry.controller.text.isNotEmpty) {
        debits += double.tryParse(entry.controller.text) ?? 0.0;
      }
    }
    
    for (var entry in creditEntries) {
      if (entry.controller.text.isNotEmpty) {
        credits += double.tryParse(entry.controller.text) ?? 0.0;
      }
    }
    
    setState(() {
      totalDebits = debits;
      totalCredits = credits;
    });
  }
  
  void _addDebitEntry() {
    setState(() {
      debitEntries.add(DebitEntry(
        controller: TextEditingController(),
        selectedLedger: null,
      ));
    });
  }
  
  void _removeDebitEntry(int index) {
    if (debitEntries.length > 1) {
      setState(() {
        debitEntries[index].controller.dispose();
        debitEntries.removeAt(index);
        _calculateTotals();
      });
    }
  }
  
  void _addCreditEntry() {
    setState(() {
      creditEntries.add(CreditEntry(
        controller: TextEditingController(),
        selectedLedger: null,
      ));
    });
  }
  
  void _removeCreditEntry(int index) {
    if (creditEntries.length > 1) {
      setState(() {
        creditEntries[index].controller.dispose();
        creditEntries.removeAt(index);
        _calculateTotals();
      });
    }
  }

  Future<void> _saveVoucher() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check if debits equal credits
    if (totalDebits != totalCredits) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Total debits must equal total credits')),
      );
      return;
    }
    
    // Check if any entry is missing a ledger
    for (var entry in debitEntries) {
      if (entry.selectedLedger == null && entry.controller.text.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a ledger for all debit entries')),
        );
        return;
      }
    }
    
    for (var entry in creditEntries) {
      if (entry.selectedLedger == null && entry.controller.text.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a ledger for all credit entries')),
        );
        return;
      }
    }
    
    // No need to check for uniqueness as the number is auto-generated

    try {
      final company = await StorageService.getSelectedCompany();
      if (company == null) {
        throw Exception('No company selected');
      }

      // Parse date from DD/MM/YYYY to YYYY-MM-DD for storage
      final dateParts = _dateController.text.split('/');
      final formattedDate = "${dateParts[2]}-${dateParts[1]}-${dateParts[0]}";

      Map<String, dynamic> voucher = {
        'company_id': company['id'],
        'voucher_number': _voucherNumberController.text,
        'voucher_date': formattedDate,
        'type': 'Journal',
        'total': totalDebits, // Use total debits (which equals total credits)
        // Note: description/narration is stored in VoucherEntries, not in Vouchers table
      };

      // If editing an existing voucher, include the ID
      if (_isEditMode && widget.voucherId != null) {
        voucher['id'] = widget.voucherId;
      }

      // Save the voucher (this will update if ID is included, otherwise insert)
      final voucherId = await StorageService.saveVoucher(voucher);

      // If editing, we need to delete the old entries first
      if (_isEditMode && widget.voucherId != null) {
        // Instead of deleting the entire voucher, we'll directly delete just the voucher entries
        // This is safer and avoids issues with narration
        await StorageService.deleteVoucherEntries(voucherId);
      }

      // Add voucher entries for all debit accounts
      for (var entry in debitEntries) {
        if (entry.selectedLedger != null && entry.controller.text.isNotEmpty) {
          final amount = double.tryParse(entry.controller.text) ?? 0.0;
          if (amount > 0) {
            // Get the narration text and log it for debugging
            String narration = _narrationController.text;
            print('Journal voucher narration (debit): "$narration"');
            
            // Create the entry map
            Map<String, dynamic> entryMap = {
              'voucher_id': voucherId,
              'ledger_id': allLedgers.firstWhere((l) => l['name'] == entry.selectedLedger)['id'],
              'description': narration,
              'debit': amount,
            };
            
            // Insert the entry
            await StorageService.insertVoucherEntry(entryMap);
          }
        }
      }

      // Add voucher entries for all credit accounts
      for (var entry in creditEntries) {
        if (entry.selectedLedger != null && entry.controller.text.isNotEmpty) {
          final amount = double.tryParse(entry.controller.text) ?? 0.0;
          if (amount > 0) {
            // Use the same narration for consistency
            String narration = _narrationController.text;
            print('Journal voucher narration (credit): "$narration"');
            
            // Create the entry map
            Map<String, dynamic> entryMap = {
              'voucher_id': voucherId,
              'ledger_id': allLedgers.firstWhere((l) => l['name'] == entry.selectedLedger)['id'],
              'description': narration,
              'credit': amount,
            };
            
            // Insert the entry
            await StorageService.insertVoucherEntry(entryMap);
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Journal voucher saved successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving voucher: $e')),
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
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 32,
              width: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.account_balance,
                size: 20,
                color: Color(0xFF2C5545),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'TOM-PA (V 4.5, R 73)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
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
              'Journal Voucher',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Voucher number field removed as requested
                    
                    // Date field with date picker
                    Row(
                      children: [
                        const SizedBox(width: 8),
                        const Text(
                          'Date :',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C5545),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _dateController,
                            readOnly: true, // Make it read-only to prevent keyboard from showing
                            decoration: InputDecoration(
                              border: const UnderlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.calendar_today),
                                onPressed: () => _selectDate(context),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a date';
                              }
                              return null;
                            },
                            onTap: () => _selectDate(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Debit entries section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFF0F8F5), // Light mint green
                            Color(0xFFE8F5E8), // Slightly deeper mint
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF2C5545), // Solid dark green border
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x1A2C5545), // Subtle green shadow
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Dr/By (Debit):',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C5545),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: Color(0xFF2C5545)),
                                onPressed: _addDebitEntry,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          
                          // List of debit entries
                          ...List.generate(debitEntries.length, (index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: DropdownButtonFormField<String>(
                                      value: debitEntries[index].selectedLedger,
                                      decoration: const InputDecoration(
                                        border: UnderlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                                        hintText: 'Select ledger',
                                      ),
                                      items: [
                                        ...allLedgers.map((ledger) {
                                          return DropdownMenuItem(
                                            value: ledger['name'] as String,
                                            child: Text(ledger['name'] as String),
                                          );
                                        }).toList(),
                                        const DropdownMenuItem(
                                          value: "__create_new__",
                                          child: Text("+ Create New Ledger", style: TextStyle(color: Color(0xFF2C5545), fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                      onChanged: (value) async {
                                        if (value == "__create_new__") {
                                          // Navigate to ledger creation page
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const LedgerCreation(),
                                            ),
                                          );
                                          
                                          if (result == true) {
                                            // Reload ledgers and select the newly created one
                                            await _loadLedgers();
                                            
                                            // Get the most recently created ledger (assuming it's the last one)
                                            if (allLedgers.isNotEmpty) {
                                              setState(() {
                                                debitEntries[index].selectedLedger = allLedgers.last['name'] as String;
                                              });
                                            }
                                          }
                                        } else {
                                          setState(() {
                                            debitEntries[index].selectedLedger = value;
                                          });
                                        }
                                      },
                                      validator: (value) {
                                        if (debitEntries[index].controller.text.isNotEmpty && 
                                            (value == null || value.isEmpty)) {
                                          return 'Required';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: debitEntries[index].controller,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        border: UnderlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                                        hintText: 'Amount',
                                      ),
                                      onChanged: (value) {
                                        _calculateTotals();
                                      },
                                      validator: (value) {
                                        if (value != null && value.isNotEmpty) {
                                          if (double.tryParse(value) == null) {
                                            return 'Invalid';
                                          }
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                                    onPressed: debitEntries.length > 1 ? () => _removeDebitEntry(index) : null,
                                  ),
                                ],
                              ),
                            );
                          }),
                          
                          // Total debits
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            color: const Color(0xFFE0F2E9),
                            child: Text(
                              'Total Debits: ${totalDebits.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C5545),
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Credit entries section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFF0F8F5), // Light mint green
                            Color(0xFFE8F5E8), // Slightly deeper mint
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF2C5545), // Solid dark green border
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x1A2C5545), // Subtle green shadow
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Cr/To (Credit):',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C5545),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: Color(0xFF2C5545)),
                                onPressed: _addCreditEntry,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          
                          // List of credit entries
                          ...List.generate(creditEntries.length, (index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: DropdownButtonFormField<String>(
                                      value: creditEntries[index].selectedLedger,
                                      decoration: const InputDecoration(
                                        border: UnderlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                                        hintText: 'Select ledger',
                                      ),
                                      items: [
                                        ...allLedgers.map((ledger) {
                                          return DropdownMenuItem(
                                            value: ledger['name'] as String,
                                            child: Text(ledger['name'] as String),
                                          );
                                        }).toList(),
                                        const DropdownMenuItem(
                                          value: "__create_new__",
                                          child: Text("+ Create New Ledger", style: TextStyle(color: Color(0xFF2C5545), fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                      onChanged: (value) async {
                                        if (value == "__create_new__") {
                                          // Navigate to ledger creation page
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const LedgerCreation(),
                                            ),
                                          );
                                          
                                          if (result == true) {
                                            // Reload ledgers and select the newly created one
                                            await _loadLedgers();
                                            
                                            // Get the most recently created ledger (assuming it's the last one)
                                            if (allLedgers.isNotEmpty) {
                                              setState(() {
                                                creditEntries[index].selectedLedger = allLedgers.last['name'] as String;
                                              });
                                            }
                                          }
                                        } else {
                                          setState(() {
                                            creditEntries[index].selectedLedger = value;
                                          });
                                        }
                                      },
                                      validator: (value) {
                                        if (creditEntries[index].controller.text.isNotEmpty && 
                                            (value == null || value.isEmpty)) {
                                          return 'Required';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: creditEntries[index].controller,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        border: UnderlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                                        hintText: 'Amount',
                                      ),
                                      onChanged: (value) {
                                        _calculateTotals();
                                      },
                                      validator: (value) {
                                        if (value != null && value.isNotEmpty) {
                                          if (double.tryParse(value) == null) {
                                            return 'Invalid';
                                          }
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                                    onPressed: creditEntries.length > 1 ? () => _removeCreditEntry(index) : null,
                                  ),
                                ],
                              ),
                            );
                          }),
                          
                          // Total credits
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            color: const Color(0xFFE0F2E9),
                            child: Text(
                              'Total Credits: ${totalCredits.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C5545),
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Balance indicator with enhanced styling
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: totalDebits == totalCredits
                              ? [
                                  const Color(0xFFF8FFF8), // Light green when balanced
                                  const Color(0xFFE8F5E8), // Deeper green when balanced
                                ]
                              : [
                                  const Color(0xFFFFF5F5), // Light red when unbalanced
                                  const Color(0xFFFFE8E8), // Deeper red when unbalanced
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: totalDebits == totalCredits ? const Color(0xFF2C5545) : Colors.red,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: totalDebits == totalCredits
                                ? const Color(0x1A2C5545) // Green shadow when balanced
                                : const Color(0x1AFF0000), // Red shadow when unbalanced
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        totalDebits == totalCredits 
                            ? 'Balanced: ${totalDebits.toStringAsFixed(2)}' 
                            : 'Difference: ${(totalDebits - totalCredits).abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: totalDebits == totalCredits ? const Color(0xFF2C5545) : Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Narration field with styled container
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFAFAFA), // Light gray
                            Color(0xFFF5F5F5), // Slightly deeper gray
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF2C5545), // Dark green border
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x1A2C5545), // Subtle green shadow
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Narration :',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C5545),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _narrationController,
                            maxLines: 3, // Increased to 3 lines
                            maxLength: null, // No character limit
                            decoration: const InputDecoration(
                              border: InputBorder.none, // Borderless input
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              hintText: 'Enter narration (no character limit)',
                            ),
                            onChanged: (value) {
                              // Print the narration for debugging
                              print('Narration changed: "$value"');
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Save button at the bottom
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: totalDebits == totalCredits && totalDebits > 0 ? _saveVoucher : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4C7380),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                disabledBackgroundColor: Colors.grey,
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
    );
  }
}

// Helper classes for debit and credit entries
class DebitEntry {
  TextEditingController controller;
  String? selectedLedger;
  
  DebitEntry({
    required this.controller,
    this.selectedLedger,
  });
}

class CreditEntry {
  TextEditingController controller;
  String? selectedLedger;
  
  CreditEntry({
    required this.controller,
    this.selectedLedger,
  });
}
