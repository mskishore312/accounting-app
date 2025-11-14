import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/ui/ledger_creation.dart';

class ReceiptVoucher extends StatefulWidget {
  final int? voucherId;
  const ReceiptVoucher({Key? key, this.voucherId}) : super(key: key);

  @override
  State<ReceiptVoucher> createState() => _ReceiptVoucherState();
}

class _ReceiptVoucherState extends State<ReceiptVoucher> {
  final _formKey = GlobalKey<FormState>();
  final _voucherNoController = TextEditingController();
  final _narrationController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _ledgers = [];
  List<Map<String, dynamic>> _cashBankLedgers = [];
  List<DebitEntry> _debitEntries = [];
  List<CreditEntry> _creditEntries = [];
  
  double _totalDebit = 0.0;
  double _totalCredit = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLedgers();
    if (widget.voucherId != null) {
      _loadExistingVoucher();
    } else {
      _generateVoucherNumber();
      _addInitialEntries();
    }
  }

  void _addInitialEntries() {
    // Add one debit and one credit entry by default
    _debitEntries.add(DebitEntry(
      ledgerController: TextEditingController(),
      amountController: TextEditingController(),
    ));
    _creditEntries.add(CreditEntry(
      ledgerController: TextEditingController(),
      amountController: TextEditingController(),
    ));
  }

  Future<void> _loadLedgers() async {
    try {
      final ledgers = await StorageService.getLedgers();
      
      // Filter cash and bank accounts for debit dropdown
      final cashBankLedgers = ledgers.where((ledger) {
        final classification = (ledger['classification'] as String? ?? '').toLowerCase();
        return classification.contains('cash') || 
               classification.contains('bank') ||
               classification == 'cash-in-hand' ||
               classification == 'bank accounts' ||
               classification == 'bank od a/c';
      }).toList();
      
      setState(() {
        _ledgers = ledgers; // All ledgers for credit dropdown
        _cashBankLedgers = cashBankLedgers; // Only cash/bank for debit dropdown
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading ledgers: $e')),
        );
      }
    }
  }

  Future<void> _generateVoucherNumber() async {
    try {
      final company = await StorageService.getSelectedCompany();
      if (company == null) return;
      
      final vouchers = await StorageService.getVouchers(company['id'], 'Receipt');
      int nextNumber = 1;
      
      if (vouchers.isNotEmpty) {
        int maxNumber = 0;
        for (var voucher in vouchers) {
          final voucherNo = voucher['voucher_number'] as String?;
          if (voucherNo != null) {
            final numberMatch = RegExp(r'(\d+)').firstMatch(voucherNo);
            if (numberMatch != null) {
              final number = int.tryParse(numberMatch.group(1)!) ?? 0;
              if (number > maxNumber) maxNumber = number;
            }
          }
        }
        nextNumber = maxNumber + 1;
      }
      
      _voucherNoController.text = 'RV${nextNumber.toString().padLeft(3, '0')}';
    } catch (e) {
      _voucherNoController.text = 'RV001';
    }
  }

  void _calculateTotals() {
    double debitTotal = 0.0;
    double creditTotal = 0.0;
    
    for (var entry in _debitEntries) {
      debitTotal += double.tryParse(entry.amountController.text) ?? 0.0;
    }
    
    for (var entry in _creditEntries) {
      creditTotal += double.tryParse(entry.amountController.text) ?? 0.0;
    }
    
    setState(() {
      _totalDebit = debitTotal;
      _totalCredit = creditTotal;
    });
  }

  // Check if debiting this amount would make the cash/bank account negative
  Future<void> _checkNegativeBalance(String ledgerId, double debitAmount) async {
    try {
      final ledgerIdInt = int.tryParse(ledgerId);
      if (ledgerIdInt != null) {
        final balanceAfterTransaction = await StorageService.getLedgerBalanceAfterTransaction(ledgerIdInt, -debitAmount); // Negative because we're debiting
        
        // Find ledger name for display
        final ledger = _cashBankLedgers.firstWhere(
          (l) => l['id'].toString() == ledgerId,
          orElse: () => <String, dynamic>{},
        );
        final ledgerName = ledger.isNotEmpty ? ledger['name'] as String : 'Account';
        
        // If balance would be negative, show warning
        if (balanceAfterTransaction < 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Warning: This transaction will make ${ledgerName} negative by ${balanceAfterTransaction.abs().toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
                action: SnackBarAction(
                  label: 'OK',
                  textColor: Colors.white,
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error checking negative balance: $e');
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2C5545),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF2C5545),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _addDebitEntry() {
    setState(() {
      _debitEntries.add(DebitEntry(
        ledgerController: TextEditingController(),
        amountController: TextEditingController(),
      ));
    });
  }

  void _addCreditEntry() {
    setState(() {
      _creditEntries.add(CreditEntry(
        ledgerController: TextEditingController(),
        amountController: TextEditingController(),
      ));
    });
  }

  void _removeDebitEntry(int index) {
    if (_debitEntries.length > 1) {
      setState(() {
        _debitEntries[index].dispose();
        _debitEntries.removeAt(index);
      });
      _calculateTotals();
    }
  }

  void _removeCreditEntry(int index) {
    if (_creditEntries.length > 1) {
      setState(() {
        _creditEntries[index].dispose();
        _creditEntries.removeAt(index);
      });
      _calculateTotals();
    }
  }

  Future<void> _loadExistingVoucher() async {
    if (widget.voucherId == null) return;
    
    try {
      final voucherData = await StorageService.getVoucherById(widget.voucherId!);
      if (voucherData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voucher not found')),
          );
          Navigator.pop(context);
        }
        return;
      }
      
      setState(() {
        // Load voucher details
        _voucherNoController.text = voucherData['voucher_number'] ?? '';
        
        // Parse voucher date
        if (voucherData['voucher_date'] != null) {
          try {
            _selectedDate = DateTime.parse(voucherData['voucher_date']);
          } catch (e) {
            _selectedDate = DateTime.now();
          }
        }
        
        // Clear existing entries
        for (var entry in _debitEntries) {
          entry.dispose();
        }
        for (var entry in _creditEntries) {
          entry.dispose();
        }
        _debitEntries.clear();
        _creditEntries.clear();
        
        // Load entries from database
        final entries = voucherData['entries'] as List<Map<String, dynamic>>;
        
        for (var entry in entries) {
          final ledgerId = entry['ledger_id'] as int;
          final ledgerName = entry['ledger_name'] as String;
          final debit = (entry['debit'] as num?)?.toDouble() ?? 0.0;
          final credit = (entry['credit'] as num?)?.toDouble() ?? 0.0;
          
          if (debit > 0) {
            // This is a debit entry
            final debitEntry = DebitEntry(
              ledgerController: TextEditingController(text: ledgerName),
              amountController: TextEditingController(text: debit.toString()),
              selectedLedgerId: ledgerId.toString(),
            );
            _debitEntries.add(debitEntry);
          } else if (credit > 0) {
            // This is a credit entry
            final creditEntry = CreditEntry(
              ledgerController: TextEditingController(text: ledgerName),
              amountController: TextEditingController(text: credit.toString()),
              selectedLedgerId: ledgerId.toString(),
            );
            _creditEntries.add(creditEntry);
          }
        }
        
        // Set narration from the first entry's description
        if (entries.isNotEmpty) {
          _narrationController.text = entries.first['description'] ?? '';
        }
        
        // Ensure at least one entry of each type
        if (_debitEntries.isEmpty) {
          _debitEntries.add(DebitEntry(
            ledgerController: TextEditingController(),
            amountController: TextEditingController(),
          ));
        }
        if (_creditEntries.isEmpty) {
          _creditEntries.add(CreditEntry(
            ledgerController: TextEditingController(),
            amountController: TextEditingController(),
          ));
        }
        
        _isLoading = false;
      });
      
      _calculateTotals();
      
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading voucher: $e')),
        );
      }
    }
  }

  Future<void> _saveVoucher() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final company = await StorageService.getSelectedCompany();
      if (company == null) throw Exception('No company selected');

      final db = await StorageService().database;
      await db.transaction((txn) async {
        int voucherId;
        
        if (widget.voucherId != null) {
          // Update existing voucher
          voucherId = widget.voucherId!;
          await txn.update('Vouchers', {
            'voucher_number': _voucherNoController.text,
            'voucher_date': _selectedDate.toIso8601String().split('T')[0],
            'total': _totalDebit,
          }, where: 'id = ?', whereArgs: [voucherId]);
          
          // Delete existing entries
          await StorageService.deleteVoucherEntries(voucherId, txn);
        } else {
          // Insert new voucher - ensure voucher_number is unique before inserting (checked inside txn)
          String voucherNumberToInsert = _voucherNoController.text;
          
          // If voucher number is empty, generate one
          if (voucherNumberToInsert.isEmpty) {
            await _generateVoucherNumber();
            voucherNumberToInsert = _voucherNoController.text;
          }
          
          // Check uniqueness globally using the same transaction (atomic)
          // (voucher_number has a UNIQUE constraint at table level)
          var exists = await txn.query(
            'Vouchers',
            where: 'voucher_number = ?',
            whereArgs: [voucherNumberToInsert],
          );
          if (exists.isNotEmpty) {
            // Extract prefix and numeric suffix, then increment using txn checks
            final match = RegExp(r'^(.+?)(\d+)$').firstMatch(voucherNumberToInsert);
            String prefix;
            int startNum;
            if (match != null) {
              prefix = match.group(1)!;
              startNum = int.tryParse(match.group(2)!) ?? 0;
            } else {
              // Fallback: treat whole string as prefix and start from 0
              prefix = voucherNumberToInsert;
              startNum = 0;
            }
            int candidate = startNum + 1;
            String candidateStr = '$prefix${candidate.toString().padLeft(3, '0')}';
            var candidateExists = await txn.query(
              'Vouchers',
              where: 'voucher_number = ?',
              whereArgs: [candidateStr],
            );
            while (candidateExists.isNotEmpty) {
              candidate++;
              candidateStr = '$prefix${candidate.toString().padLeft(3, '0')}';
              candidateExists = await txn.query(
                'Vouchers',
                where: 'voucher_number = ?',
                whereArgs: [candidateStr],
              );
            }
            voucherNumberToInsert = candidateStr;
            _voucherNoController.text = voucherNumberToInsert;
          }

          // Attempt to insert voucher; if UNIQUE constraint still occurs (race or unexpected existing),
          // retry by incrementing numeric suffix up to a limit.
          int attempts = 0;
          const int maxAttempts = 50;
          String baseVoucher = voucherNumberToInsert;
          int numericSuffix = 0;
          final m = RegExp(r'(\d+)$').firstMatch(baseVoucher);
          if (m != null) {
            numericSuffix = int.tryParse(m.group(1)!) ?? 0;
            baseVoucher = baseVoucher.substring(0, m.start);
          }

          while (true) {
            try {
              voucherId = await txn.insert('Vouchers', {
                'company_id': company['id'],
                'voucher_number': voucherNumberToInsert,
                'voucher_date': _selectedDate.toIso8601String().split('T')[0],
                'type': 'Receipt',
                'total': _totalDebit,
              });
              break; // success
            } catch (e) {
              // If UNIQUE constraint on voucher_number, try next candidate
              final msg = e.toString().toLowerCase();
              if (msg.contains('unique') && attempts < maxAttempts) {
                attempts++;
                numericSuffix++;
                voucherNumberToInsert = '$baseVoucher${numericSuffix.toString().padLeft(3, '0')}';
                _voucherNoController.text = voucherNumberToInsert;
                // continue loop to retry insert
              } else {
                // Re-throw if not a unique constraint or exceeded attempts
                rethrow;
              }
            }
          }
        }

        // Insert debit entries
        for (var entry in _debitEntries) {
          final amount = double.tryParse(entry.amountController.text) ?? 0.0;
          if (amount > 0 && entry.selectedLedgerId != null) {
            await StorageService.insertVoucherEntry({
              'voucher_id': voucherId,
              'ledger_id': int.parse(entry.selectedLedgerId!),
              'description': _narrationController.text,
              'debit': amount,
              'credit': 0.0,
            }, txn);
          }
        }

        // Insert credit entries
        for (var entry in _creditEntries) {
          final amount = double.tryParse(entry.amountController.text) ?? 0.0;
          if (amount > 0 && entry.selectedLedgerId != null) {
            await StorageService.insertVoucherEntry({
              'voucher_id': voucherId,
              'ledger_id': int.parse(entry.selectedLedgerId!),
              'description': _narrationController.text,
              'debit': 0.0,
              'credit': amount,
            }, txn);
          }
        }
      });

      if (mounted) {
        final message = widget.voucherId != null 
            ? 'Receipt voucher updated successfully'
            : 'Receipt voucher saved successfully';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
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
  void dispose() {
    _voucherNoController.dispose();
    _narrationController.dispose();
    for (var entry in _debitEntries) {
      entry.dispose();
    }
    for (var entry in _creditEntries) {
      entry.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFE0F2E9),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFFE0F2E9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Color(0xFF2C5545),
        title: Text(
          widget.voucherId != null ? 'Edit Receipt Voucher' : 'Receipt Voucher',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: const Color(0xFFE0F2E9),
              child: const Text(
                'Receipt Voucher',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C5545),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Voucher Number and Date Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Voucher No :',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C5545),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _voucherNoController,
                                decoration: const InputDecoration(
                                  border: UnderlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                ),
                                validator: (value) =>
                                    value?.isEmpty == true ? 'Required' : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Date :',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C5545),
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _selectDate,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(color: Colors.grey),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDate(_selectedDate),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Color(0xFF2C5545),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.calendar_today,
                                        color: Color(0xFF2C5545),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Debit Section
                    Row(
                      children: [
                        const Text(
                          'Debit (Cash/Bank Accounts)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C5545),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _addDebitEntry,
                          icon: const Icon(
                            Icons.add_circle,
                            color: Color(0xFF4C7380),
                          ),
                        ),
                      ],
                    ),
                    
                    // Debit Entries
                    ...List.generate(_debitEntries.length, (index) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
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
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<String>(
                                    value: _debitEntries[index].selectedLedgerId,
                                    decoration: const InputDecoration(
                                      labelText: 'Ledger',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                    items: [
                                      // Create New Ledger option
                                      const DropdownMenuItem<String>(
                                        value: 'create_new',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.add_circle,
                                              color: Color(0xFF4C7380),
                                              size: 20,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'New Ledger',
                                              style: TextStyle(
                                                color: Color(0xFF4C7380),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Divider
                                      const DropdownMenuItem<String>(
                                        value: 'divider',
                                        enabled: false,
                                        child: Divider(height: 1),
                                      ),
                                      // Cash/Bank ledgers only for debit
                                       ..._cashBankLedgers.map((ledger) {
                                         return DropdownMenuItem<String>(
                                           value: ledger['id'].toString(),
                                           child: Text(
                                             ledger['name'] as String,
                                             overflow: TextOverflow.ellipsis,
                                           ),
                                         );
                                       }).toList(),
                                    ],
                                    onChanged: (value) async {
                                      if (value == 'create_new') {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const LedgerCreation(),
                                          ),
                                        );
                                        if (result == true) {
                                          // Reload ledgers after creating new one
                                          await _loadLedgers();
                                          
                                          // Auto-select the newly created ledger
                                          if (_cashBankLedgers.isNotEmpty) {
                                            // Find the most recently added cash/bank ledger
                                            final latestLedger = _cashBankLedgers.last;
                                            setState(() {
                                              _debitEntries[index].selectedLedgerId = latestLedger['id'].toString();
                                            });
                                          }
                                        }
                                      } else if (value != 'divider') {
                                        setState(() {
                                          _debitEntries[index].selectedLedgerId = value;
                                        });
                                      }
                                    },
                                    validator: (value) =>
                                        value == null || value == 'create_new' || value == 'divider' ? 'Select ledger' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _debitEntries[index].amountController,
                                    decoration: const InputDecoration(
                                      labelText: 'Amount',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) async {
                                      _calculateTotals();
                                      
                                      // Check for negative balance warning
                                      if (value.isNotEmpty && _debitEntries[index].selectedLedgerId != null) {
                                        final amount = double.tryParse(value);
                                        if (amount != null && amount > 0) {
                                          await _checkNegativeBalance(_debitEntries[index].selectedLedgerId!, amount);
                                        }
                                      }
                                    },
                                    validator: (value) {
                                      if (value?.isEmpty == true) return 'Required';
                                      if (double.tryParse(value!) == null) {
                                        return 'Invalid amount';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                if (_debitEntries.length > 1)
                                  IconButton(
                                    onPressed: () => _removeDebitEntry(index),
                                    icon: const Icon(
                                      Icons.remove_circle,
                                      color: Colors.red,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    
                    const SizedBox(height: 24),
                    
                    // Credit Section
                    Row(
                      children: [
                        const Text(
                          'Credit',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C5545),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _addCreditEntry,
                          icon: const Icon(
                            Icons.add_circle,
                            color: Color(0xFF4C7380),
                          ),
                        ),
                      ],
                    ),
                    
                    // Credit Entries
                    ...List.generate(_creditEntries.length, (index) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
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
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<String>(
                                    value: _creditEntries[index].selectedLedgerId,
                                    decoration: const InputDecoration(
                                      labelText: 'Ledger',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                    items: [
                                      // Create New Ledger option
                                      const DropdownMenuItem<String>(
                                        value: 'create_new',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.add_circle,
                                              color: Color(0xFF4C7380),
                                              size: 20,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'New Ledger',
                                              style: TextStyle(
                                                color: Color(0xFF4C7380),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Divider
                                      const DropdownMenuItem<String>(
                                        value: 'divider',
                                        enabled: false,
                                        child: Divider(height: 1),
                                      ),
                                      // Regular ledgers
                                      ..._ledgers.map((ledger) {
                                        return DropdownMenuItem<String>(
                                          value: ledger['id'].toString(),
                                          child: Text(
                                            ledger['name'] as String,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                    ],
                                    onChanged: (value) async {
                                      if (value == 'create_new') {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const LedgerCreation(),
                                          ),
                                        );
                                        if (result == true) {
                                          // Reload ledgers after creating new one
                                          await _loadLedgers();
                                          
                                          // Auto-select the newly created ledger
                                          if (_ledgers.isNotEmpty) {
                                            // Find the most recently added ledger
                                            final latestLedger = _ledgers.last;
                                            setState(() {
                                              _creditEntries[index].selectedLedgerId = latestLedger['id'].toString();
                                            });
                                          }
                                        }
                                      } else if (value != 'divider') {
                                        setState(() {
                                          _creditEntries[index].selectedLedgerId = value;
                                        });
                                      }
                                    },
                                    validator: (value) =>
                                        value == null || value == 'create_new' || value == 'divider' ? 'Select ledger' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _creditEntries[index].amountController,
                                    decoration: const InputDecoration(
                                      labelText: 'Amount',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) => _calculateTotals(),
                                    validator: (value) {
                                      if (value?.isEmpty == true) return 'Required';
                                      if (double.tryParse(value!) == null) {
                                        return 'Invalid amount';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                if (_creditEntries.length > 1)
                                  IconButton(
                                    onPressed: () => _removeCreditEntry(index),
                                    icon: const Icon(
                                      Icons.remove_circle,
                                      color: Colors.red,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    
                    const SizedBox(height: 24),
                    
                    // Totals Display
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _totalDebit == _totalCredit 
                              ? [
                                  const Color(0xFFF8FFF8), // Very light green
                                  const Color(0xFFE8F5E8), // Light green
                                ]
                              : [
                                  const Color(0xFFFFF5F5), // Very light red
                                  const Color(0xFFFFE8E8), // Light red
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _totalDebit == _totalCredit 
                              ? const Color(0xFF2C5545) 
                              : const Color(0xFFD32F2F),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _totalDebit == _totalCredit 
                                ? const Color(0x1A2C5545)
                                : const Color(0x1AD32F2F),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Debit: ${_totalDebit.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C5545),
                            ),
                          ),
                          Text(
                            'Total Credit: ${_totalCredit.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C5545),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Narration
                    const Text(
                      'Narration :',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C5545),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFAFAFA), // Very light gray
                            Color(0xFFF5F5F5), // Light gray
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF2C5545),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x1A2C5545),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _narrationController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Enter narration (optional)',
                          hintStyle: TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 14,
                          ),
                          contentPadding: EdgeInsets.all(16),
                        ),
                        style: const TextStyle(
                          color: Color(0xFF2C5545),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_totalDebit == _totalCredit && _totalDebit > 0) {
                            _saveVoucher();
                          } else if (_totalDebit == 0.0 && _totalCredit == 0.0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter amounts'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Debit totals should match credit totals'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4C7380),
                          foregroundColor: Colors.white,
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
          ],
        ),
      ),
    );
  }
}

// Helper classes for debit and credit entries
class DebitEntry {
  final TextEditingController ledgerController;
  final TextEditingController amountController;
  String? selectedLedgerId;
  
  DebitEntry({
    required this.ledgerController,
    required this.amountController,
    this.selectedLedgerId,
  });
  
  void dispose() {
    ledgerController.dispose();
    amountController.dispose();
  }
}

class CreditEntry {
  final TextEditingController ledgerController;
  final TextEditingController amountController;
  String? selectedLedgerId;
  
  CreditEntry({
    required this.ledgerController,
    required this.amountController,
    this.selectedLedgerId,
  });
  
  void dispose() {
    ledgerController.dispose();
    amountController.dispose();
  }
}
