import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';

class LedgerCreation extends StatefulWidget {
  final Map<String, dynamic>? existingLedger;

  const LedgerCreation({
    Key? key,
    this.existingLedger,
  }) : super(key: key);

  @override
  _LedgerCreationState createState() => _LedgerCreationState();
}

class _LedgerCreationState extends State<LedgerCreation> {
  late TextEditingController _nameController;
  late TextEditingController _balanceController;
  late TextEditingController _tinGstController;
  late TextEditingController _searchController;
  String _underGroup = '';
  String _type = 'Dr.';

  List<String> _filteredGroups = [];
  bool _isSaving = false;

  // Stock valuation fields
  List<Map<String, dynamic>> _stockValuations = [];
  final _stockAmountController = TextEditingController();
  final _stockNotesController = TextEditingController();
  DateTime _stockDate = DateTime.now();
  bool _showStockSection = false;
  String? _booksBeginningDate; // Format: YYYY-MM-DD
  DateTime? _booksBeginningDateTime;

  // Account groups available for selection
  final List<String> _underGroupOptions = [
    'Bank Accounts', 'Bank OD A/c', 'Branch / Division', 'Capital Account',
    'Cash-in-hand', 'Current Assets', 'Current Liabilities', 'Deposits (Assets)',
    'Direct Expenses', 'Direct Incomes', 'Duties & Taxes', 'Fixed Assets',
    'Indirect Expenses', 'Indirect Income', 'Investments', 'Loans & Advances (Asset)',
    'Loans (Liability)', 'Misc. Expenses (ASSET)', 'Provisions', 'Purchase Accounts',
    'Reserves & Surplus', 'Sales Accounts', 'Secured Loans', 'Stock-in-hand',
    'Sundry Creditors', 'Sundry Debtors', 'Suspense A/c', 'Unsecured Loans'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingLedger?['name'] ?? '');
    _balanceController = TextEditingController(text: widget.existingLedger?['balance']?.toString() ?? '0.00');
    _tinGstController = TextEditingController(text: widget.existingLedger?['tinGst'] ?? '');
    _searchController = TextEditingController();
    _underGroup = widget.existingLedger?['classification'] ?? '';
    _showStockSection = (_underGroup == 'Stock-in-hand');

    // Load books beginning date first, then load stock valuations after
    _loadBooksBeginningDate().then((_) {
      // Determine type based on classification if available
      if (widget.existingLedger != null) {
        final classification = widget.existingLedger?['classification'] as String? ?? '';
        _type = _getDefaultTypeForGroup(classification);

        // Load stock valuations if editing Stock-in-hand ledger
        if (_showStockSection && widget.existingLedger!['id'] != null) {
          _loadStockValuations(widget.existingLedger!['id'] as int);
        }
      } else {
        _type = 'Dr.';
      }
    });
    _filteredGroups = List.from(_underGroupOptions);
  }

  Future<void> _loadBooksBeginningDate() async {
    try {
      final company = await StorageService.getSelectedCompany();
      if (company != null && company['books_from'] != null) {
        _booksBeginningDate = company['books_from'] as String;

        // Try to parse date - could be YYYY-MM-DD or DD/MM/YYYY
        final parts = _booksBeginningDate!.split(RegExp(r'[-/]'));

        if (parts.length == 3) {
          // Check if format is YYYY-MM-DD (year comes first, will be 4 digits)
          if (parts[0].length == 4) {
            _booksBeginningDateTime = DateTime(
              int.parse(parts[0]), // year
              int.parse(parts[1]), // month
              int.parse(parts[2]), // day
            );
          } else {
            // Assume DD/MM/YYYY format
            _booksBeginningDateTime = DateTime(
              int.parse(parts[2]), // year
              int.parse(parts[1]), // month
              int.parse(parts[0]), // day
            );
          }

          // Set default stock date to books beginning date
          setState(() {
            _stockDate = _booksBeginningDateTime!;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading books beginning date: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _tinGstController.dispose();
    _searchController.dispose();
    _stockAmountController.dispose();
    _stockNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadStockValuations(int ledgerId) async {
    debugPrint('DEBUG LOAD: Loading stock valuations for ledger ID: $ledgerId');
    final valuations = await StorageService.getStockValuations(ledgerId);
    debugPrint('DEBUG LOAD: Found ${valuations.length} valuations');
    for (var v in valuations) {
      debugPrint('DEBUG LOAD: Valuation - Date: ${v['valuation_date']}, Amount: ${v['amount']}');
    }
    setState(() {
      _stockValuations = valuations.map((v) => {
        'id': v['id'],
        'date': v['valuation_date'],
        'amount': v['amount'],
        'notes': v['notes'] ?? '',
      }).toList();

      // If there's a valuation for books beginning date, populate the amount field
      if (_booksBeginningDateTime != null) {
        final booksBeginDateStr = '${_booksBeginningDateTime!.year}-${_booksBeginningDateTime!.month.toString().padLeft(2, '0')}-${_booksBeginningDateTime!.day.toString().padLeft(2, '0')}';
        final booksBeginValuation = _stockValuations.firstWhere(
          (v) => v['date'] == booksBeginDateStr,
          orElse: () => {},
        );
        if (booksBeginValuation.isNotEmpty) {
          _balanceController.text = booksBeginValuation['amount'].toString();
        }
      }
    });
    debugPrint('DEBUG LOAD: Stock valuations loaded into list. Total: ${_stockValuations.length}');
  }



  void _showUnderGroupSelection() {
    // Clear search text and reset filtered groups before showing the modal
    _searchController.clear();
    _filteredGroups = List.from(_underGroupOptions);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Color(0xFFE0F2E9),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF4C7380),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Please select from below',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (query) {
                      setModalState(() {
                        if (query.isEmpty) {
                          _filteredGroups = List.from(_underGroupOptions);
                        } else {
                          _filteredGroups = _underGroupOptions
                              .where((group) => group.toLowerCase().contains(query.toLowerCase()))
                              .toList();
                        }
                      });
                    },
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF2C5545)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredGroups.length,
                    itemBuilder: (context, index) {
                      final group = _filteredGroups[index];
                      return ListTile(
                        title: Text(group),
                        tileColor: index % 2 == 0 ? const Color(0xFFE0F2E9) : Colors.white,
                        onTap: () {
                          setState(() {
                            _underGroup = group;
                            _type = _getDefaultTypeForGroup(group);
                            _showStockSection = (group == 'Stock-in-hand');

                            // If switching to Stock-in-hand and amount field has value, auto-create valuation
                            if (_showStockSection && _balanceController.text.isNotEmpty && _booksBeginningDateTime != null) {
                              final amount = double.tryParse(_balanceController.text);
                              if (amount != null && amount > 0) {
                                final dateStr = '${_booksBeginningDateTime!.year}-${_booksBeginningDateTime!.month.toString().padLeft(2, '0')}-${_booksBeginningDateTime!.day.toString().padLeft(2, '0')}';

                                // Check if valuation for books beginning date already exists
                                final existingIndex = _stockValuations.indexWhere((v) => v['date'] == dateStr);

                                if (existingIndex == -1) {
                                  // Add new valuation with books beginning date
                                  _stockValuations.add({
                                    'date': dateStr,
                                    'amount': amount,
                                    'notes': 'Opening Stock',
                                  });
                                  // Sort by date
                                  _stockValuations.sort((a, b) => a['date'].compareTo(b['date']));
                                }
                              }
                            }
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2E9),
      appBar: AppBar(
        title: const Text('Ledger'),
        backgroundColor: const Color(0xFF4C7380),
      ),
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside text fields
          FocusScope.of(context).unfocus();
        },
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            const Text('Ledger', style: TextStyle(fontSize: 16, color: Colors.black)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              enabled: !(widget.existingLedger != null &&
                        widget.existingLedger!.containsKey('is_default') &&
                        widget.existingLedger!['is_default'] == 1),
              decoration: InputDecoration(
                hintText: 'Enter ledger name',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                helperText: (widget.existingLedger != null &&
                           widget.existingLedger!.containsKey('is_default') &&
                           widget.existingLedger!['is_default'] == 1)
                           ? 'Default Cash account name cannot be changed'
                           : null,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Under Group', style: TextStyle(fontSize: 16, color: Colors.black)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                // Dismiss keyboard when selecting under group
                FocusScope.of(context).unfocus();
                _showUnderGroupSelection();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _underGroup.isEmpty ? 'Select under group' : _underGroup,
                      style: TextStyle(
                        color: _underGroup.isEmpty ? Colors.grey : Colors.black,
                      ),
                    ),
                    const Icon(Icons.add, color: Color(0xFF4C7380)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Amount (Optional):', style: TextStyle(fontSize: 16, color: Colors.black)),
            const SizedBox(height: 8),
            TextField(
              controller: _balanceController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'Enter amount',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              onChanged: (value) {
                // Auto-update stock valuation section when amount is entered for Stock-in-Hand ledgers
                if (_showStockSection && _booksBeginningDateTime != null) {
                  final dateStr = '${_booksBeginningDateTime!.year}-${_booksBeginningDateTime!.month.toString().padLeft(2, '0')}-${_booksBeginningDateTime!.day.toString().padLeft(2, '0')}';
                  debugPrint('Amount changed: $value, Stock section shown: $_showStockSection, Books date: $dateStr');

                  setState(() {
                    // Find if valuation for books beginning date already exists
                    final existingIndex = _stockValuations.indexWhere((v) => v['date'] == dateStr);

                    if (value.isEmpty) {
                      // If amount field is cleared, remove the books beginning date valuation
                      if (existingIndex != -1) {
                        _stockValuations.removeAt(existingIndex);
                      }
                    } else {
                      final amount = double.tryParse(value);
                      if (amount != null && amount > 0) {
                        if (existingIndex != -1) {
                          // Update existing valuation
                          _stockValuations[existingIndex]['amount'] = amount;
                          // Keep any existing notes
                        } else {
                          // Add new valuation with books beginning date
                          _stockValuations.add({
                            'date': dateStr,
                            'amount': amount,
                            'notes': 'Opening Stock',
                          });
                          // Sort by date
                          _stockValuations.sort((a, b) => a['date'].compareTo(b['date']));
                          debugPrint('Added stock valuation: Date: $dateStr, Amount: $amount');
                        }
                        debugPrint('Total stock valuations: ${_stockValuations.length}');
                      } else if (existingIndex != -1 && (amount == null || amount <= 0)) {
                        // Remove if invalid amount
                        _stockValuations.removeAt(existingIndex);
                      }
                    }
                  });
                }
              },
              onTap: () {
                // Select all text when the field is tapped
                _balanceController.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _balanceController.text.length,
                );
              },
            ),
            const SizedBox(height: 16),
            const Text('Type :', style: TextStyle(fontSize: 16, color: Colors.black)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _type,
                  isExpanded: true,
                  items: ['Dr.', 'Cr.'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _type = newValue;
                      });
                    }
                  },
                ),
              ),
            ),

            // Stock valuations section for Stock-in-Hand ledgers
            if (_showStockSection) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF4C7380)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Stock Valuations (Optional)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _booksBeginningDateTime != null
                          ? 'Add opening stock from ${_formatDate(_booksBeginningDateTime!)} onwards for accurate period reporting'
                          : 'Add stock values at different dates for accurate period reporting',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 16),

                    // Existing valuations list
                    if (_stockValuations.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: _stockValuations.asMap().entries.map((entry) {
                            int index = entry.key;
                            var val = entry.value;
                            // Format date from YYYY-MM-DD to DD/MM/YYYY
                            String displayDate = val['date'];
                            try {
                              final parts = (val['date'] as String).split('-');
                              if (parts.length == 3) {
                                displayDate = '${parts[2]}/${parts[1]}/${parts[0]}';
                              }
                            } catch (e) {
                              // Keep original format if parsing fails
                            }

                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF4C7380),
                                radius: 20,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                '₹${(val['amount'] as num).toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Date: $displayDate',
                                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                                  ),
                                  if (val['notes'] != null && val['notes'].toString().isNotEmpty)
                                    Text(
                                      'Notes: ${val['notes']}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                    ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                                onPressed: () => _removeStockValuation(index),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Add new valuation form
                    const Text('Add New Valuation:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _stockAmountController,
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              border: OutlineInputBorder(),
                              prefixText: '₹ ',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: () => _selectStockDate(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.white,
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16),
                                  const SizedBox(width: 8),
                                  Text(_formatDate(_stockDate)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Color(0xFF4C7380), size: 32),
                          onPressed: _addStockValuation,
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    TextField(
                      controller: _stockNotesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],

            // Add moderate spacing before save button
            const SizedBox(height: 24),

            // Save button inside the scrollable area
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveLedger,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4C7380),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
            
            // Minimal bottom padding - just enough for comfortable viewing
            const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Determine the default type (Dr./Cr.) based on the account group
  String _getDefaultTypeForGroup(String group) {
    // Asset groups - Dr. by default
    final assetGroups = [
      'Bank Accounts', 
      'Cash-in-hand', 
      'Current Assets', 
      'Deposits (Assets)', 
      'Fixed Assets', 
      'Investments', 
      'Loans & Advances (Asset)', 
      'Misc. Expenses (ASSET)', 
      'Stock-in-hand', 
      'Sundry Debtors'
    ];
    
    // Liability and Capital groups - Cr. by default
    final liabilityGroups = [
      'Bank OD A/c', 
      'Capital Account', 
      'Current Liabilities', 
      'Duties & Taxes', 
      'Loans (Liability)', 
      'Provisions', 
      'Reserves & Surplus', 
      'Secured Loans', 
      'Sundry Creditors', 
      'Unsecured Loans'
    ];
    
    // Revenue groups - Cr. by default
    final revenueGroups = [
      'Direct Incomes', 
      'Indirect Income', 
      'Sales Accounts'
    ];
    
    // Expense groups - Dr. by default
    final expenseGroups = [
      'Direct Expenses', 
      'Indirect Expenses', 
      'Purchase Accounts'
    ];
    
    if (assetGroups.contains(group) || expenseGroups.contains(group)) {
      return 'Dr.';
    } else if (liabilityGroups.contains(group) || revenueGroups.contains(group)) {
      return 'Cr.';
    }
    
    // Default to Dr. for any other groups
    return 'Dr.';
  }

  Future<void> _saveLedger() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a ledger name')),
      );
      return;
    }

    if (_underGroup.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an under group')),
      );
      return;
    }

    // Auto-add pending stock valuation if user entered data but didn't click the + button
    if (_showStockSection && _stockAmountController.text.isNotEmpty) {
      final amount = double.tryParse(_stockAmountController.text);
      if (amount != null && amount > 0) {
        final dateStr = '${_stockDate.year}-${_stockDate.month.toString().padLeft(2, '0')}-${_stockDate.day.toString().padLeft(2, '0')}';

        // Only add if this date doesn't already exist
        if (!_stockValuations.any((v) => v['date'] == dateStr)) {
          _stockValuations.add({
            'date': dateStr,
            'amount': amount,
            'notes': _stockNotesController.text.trim(),
          });
          // Sort by date
          _stockValuations.sort((a, b) => a['date'].compareTo(b['date']));
        }
      }
    }

    setState(() => _isSaving = true);

    try {
      final selectedCompany = await StorageService.getSelectedCompany();
      if (selectedCompany == null) {
        throw Exception('No company selected');
      }

      final companyId = selectedCompany['id'];
      
      // Parse balance
      double balance = 0.0;
      if (_balanceController.text.isNotEmpty) {
        balance = double.tryParse(_balanceController.text) ?? 0.0;
      }

      // Store all balances as positive, regardless of type
      balance = balance.abs();

      final ledgerData = {
        'company_id': companyId,
        'name': _nameController.text.trim(),
        'classification': _underGroup,
        'balance': balance,
      };

      // Handle the default Cash account specially
      if (widget.existingLedger != null) {
        if (widget.existingLedger!.containsKey('id')) {
          ledgerData['id'] = widget.existingLedger!['id'];
        }
        
        // Check if this is the default account (is_default = 1)
        if (widget.existingLedger!.containsKey('is_default') &&
            widget.existingLedger!['is_default'] == 1) {
          ledgerData['is_default'] = 1;
          
          // Force the name to remain "Cash" for the default account
          ledgerData['name'] = 'Cash';
        }
      }

      final result = await StorageService.saveLedger(ledgerData);

      if (result == -1) {
        // Special case: Duplicate ledger name detected
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('A ledger with the name "${_nameController.text.trim()}" already exists (names are case-insensitive)'),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      } else if (result <= 0) {
        throw Exception('Failed to save ledger');
      }

      // Save stock valuations if Stock-in-Hand ledger
      if (_underGroup == 'Stock-in-hand') {
        // Use the correct ledger ID - for existing ledgers, use the original ID, not the returned result
        final ledgerIdToUse = (widget.existingLedger != null && widget.existingLedger!['id'] != null)
            ? widget.existingLedger!['id'] as int
            : result;

        debugPrint('DEBUG SAVE: Processing ${_stockValuations.length} stock valuations for ledger ID: $ledgerIdToUse');

        // If editing an existing ledger, delete all old stock valuations first
        // This handles both updates and deletions (if list is empty, all will be deleted)
        if (widget.existingLedger != null && widget.existingLedger!['id'] != null) {
          debugPrint('DEBUG SAVE: Deleting old stock valuations for ledger ID: $ledgerIdToUse');
          // Get all existing valuations and delete them one by one
          final existingValuations = await StorageService.getStockValuations(ledgerIdToUse);
          for (final existingVal in existingValuations) {
            await StorageService.deleteStockValuation(existingVal['id'] as int);
          }
          debugPrint('DEBUG SAVE: Deleted ${existingValuations.length} old stock valuations');
        }

        // Now save all current stock valuations (if any)
        if (_stockValuations.isNotEmpty) {
          for (final val in _stockValuations) {
            debugPrint('DEBUG SAVE: Saving valuation - Date: ${val['date']}, Amount: ${val['amount']}');
            await StorageService.saveStockValuation({
              'ledger_id': ledgerIdToUse,
              'valuation_date': val['date'],
              'amount': val['amount'],
              'notes': val['notes'],
            });
          }
          debugPrint('DEBUG SAVE: All ${_stockValuations.length} stock valuations saved');
        } else {
          debugPrint('DEBUG SAVE: No stock valuations to save (list is empty, all deleted)');
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ledger saved successfully')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _addStockValuation() {
    if (_stockAmountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    final amount = double.tryParse(_stockAmountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid positive amount')),
      );
      return;
    }

    final dateStr = '${_stockDate.year}-${_stockDate.month.toString().padLeft(2, '0')}-${_stockDate.day.toString().padLeft(2, '0')}';

    // Check for duplicate date
    if (_stockValuations.any((v) => v['date'] == dateStr)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valuation for this date already exists')),
      );
      return;
    }

    setState(() {
      _stockValuations.add({
        'date': dateStr,
        'amount': amount,
        'notes': _stockNotesController.text.trim(),
      });

      // Sort by date
      _stockValuations.sort((a, b) => a['date'].compareTo(b['date']));

      // Clear inputs
      _stockAmountController.clear();
      _stockNotesController.clear();
      // Reset to books beginning date if available, otherwise current date
      _stockDate = _booksBeginningDateTime ?? DateTime.now();
    });
  }

  void _removeStockValuation(int index) {
    setState(() {
      final removedValuation = _stockValuations[index];
      _stockValuations.removeAt(index);

      // Only clear the balance field if we're removing the books beginning date valuation
      if (_booksBeginningDateTime != null) {
        final booksBeginDateStr = '${_booksBeginningDateTime!.year}-${_booksBeginningDateTime!.month.toString().padLeft(2, '0')}-${_booksBeginningDateTime!.day.toString().padLeft(2, '0')}';
        if (removedValuation['date'] == booksBeginDateStr) {
          _balanceController.clear();
        }
      }
    });
  }

  Future<void> _selectStockDate(BuildContext context) async {
    // Use books beginning date as the first allowed date, or default to 2000
    final firstDate = _booksBeginningDateTime ?? DateTime(2000);

    final picked = await showDatePicker(
      context: context,
      initialDate: _stockDate.isBefore(firstDate) ? firstDate : _stockDate,
      firstDate: firstDate,
      lastDate: DateTime(2100),
      helpText: _booksBeginningDateTime != null
          ? 'Select date (from ${_formatDate(firstDate)} onwards)'
          : 'Select date',
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
    if (picked != null) {
      setState(() => _stockDate = picked);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
