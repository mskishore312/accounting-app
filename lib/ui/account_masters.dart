import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/ui/ledger_creation.dart';

class AccountMasters extends StatefulWidget {
  const AccountMasters({Key? key}) : super(key: key);

  @override
  State<AccountMasters> createState() => _AccountMastersState();
}

class _AccountMastersState extends State<AccountMasters> {
  List<Map<String, dynamic>> ledgers = [];
  List<Map<String, dynamic>> filteredLedgers = [];
  bool isLoading = true;
  bool isSelectionMode = false;
  final _searchController = TextEditingController();
  final Set<int> selectedLedgers = {};

  @override
  void initState() {
    super.initState();
    _loadLedgers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLedgers() async {
    try {
      // Get the selected company ID
      final selectedCompany = await StorageService.getSelectedCompany();
      final companyId = selectedCompany?['id'] as int? ?? 0;
      
      if (companyId == 0) {
        setState(() {
          isLoading = false;
          ledgers = [];
          filteredLedgers = [];
        });
        return;
      }
      
      // Load ledgers from database
      final loadedLedgers = await StorageService.getLedgers();
      
      setState(() {
        ledgers = loadedLedgers;
        filteredLedgers = loadedLedgers;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading ledgers: $e');
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading ledgers: $e')),
        );
      }
    }
  }

  void _filterLedgers(String query) {
    setState(() {
      filteredLedgers = ledgers.where((ledger) {
        final name = ledger['name'].toString().toLowerCase();
        final classification = ledger['classification'].toString().toLowerCase();
        return name.contains(query.toLowerCase()) ||
            classification.contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> _showAddLedgerDialog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LedgerCreation(),
      ),
    );
    
    if (result == true) {
      _loadLedgers();
    }
  }
  
  Future<void> _deleteSelectedLedgers() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Ledgers'),
        content: Text('Are you sure you want to delete ${selectedLedgers.length} ledger(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() {
      isLoading = true;
    });
    
    try {
      // Delete each selected ledger (except Cash account)
      int deletedCount = 0;
      for (final ledgerId in selectedLedgers) {
        // Get the ledger details
        final ledgerDetails = ledgers.firstWhere(
          (ledger) => ledger['id'] == ledgerId,
          orElse: () => <String, dynamic>{},
        );
        
        // Skip Cash account
        if (ledgerDetails.isNotEmpty && ledgerDetails['name'] == 'Cash') {
          continue;
        }
        
        // Delete the ledger and check if it's being used in transactions
        final result = await StorageService.deleteLedger(ledgerId);
        
        if (result['success'] == true) {
          deletedCount++;
        } else {
          // Show error message if the ledger is being used in transactions
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] as String),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
      
      // Reload ledgers and exit selection mode
      await _loadLedgers();
      
      if (deletedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$deletedCount ledger(s) deleted')),
        );
      }
      
      setState(() {
        isSelectionMode = false;
        selectedLedgers.clear();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting ledgers: $e')),
      );
    }
  }
  
  Future<void> _showEditCashBalanceDialog(Map<String, dynamic> cashLedger) async {
    final TextEditingController balanceController = TextEditingController(
      text: (cashLedger['balance'] ?? 0.0).toString(),
    );
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Cash Account Balance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cash account cannot be deleted. You can only modify its opening balance.'),
            const SizedBox(height: 16),
            TextField(
              controller: balanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Opening Balance',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      try {
        // Parse the balance
        final double balance = double.tryParse(balanceController.text) ?? 0.0;
        
        // Update the cash ledger with the new balance
        final updatedLedger = Map<String, dynamic>.from(cashLedger);
        updatedLedger['balance'] = balance;
        
        // Save the updated ledger
        await StorageService.saveLedger(updatedLedger);
        
        // Reload ledgers
        await _loadLedgers();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cash account balance updated')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating cash account: $e')),
          );
        }
      }
    }
    
    // Dispose the controller
    balanceController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2E9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C5545),
        title: isSelectionMode
            ? Text(
                '${selectedLedgers.length} selected',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              )
            : FutureBuilder<Map<String, dynamic>?>(
                future: StorageService.getSelectedCompany(),
                builder: (context, snapshot) {
                  final company = snapshot.data;
                  return Text(
                    company?['name'] as String? ?? 'Unknown Company',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                },
              ),
        leading: isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    isSelectionMode = false;
                    selectedLedgers.clear();
                  });
                },
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
        actions: isSelectionMode
            ? [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (String result) {
                    if (result == 'delete') {
                      _deleteSelectedLedgers();
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Color(0xFF2C5545)),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ]
            : null,
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
              'Account Master',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: const Color(0xFFE0F2E9),
            child: TextField(
              controller: _searchController,
              onChanged: _filterLedgers,
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF2C5545)),
                filled: true,
                fillColor: const Color(0xFFE0F2E9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF2C5545), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF2C5545), width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF2C5545), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFE0F2E9),
            child: Row(
              children: const [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Name',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C5545),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Under',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C5545),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Op. Balance',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C5545),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredLedgers.isEmpty
                    ? const Center(
                        child: Text(
                          'No ledgers found.\nCreate a new ledger to get started.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredLedgers.length,
                        itemBuilder: (context, index) {
                          final ledger = filteredLedgers[index];
                          final ledgerId = ledger['id'] as int? ?? -1;
                          final isSelected = selectedLedgers.contains(ledgerId);
                          
                          // Check if this is the Cash account (which should not be deletable)
                          final isCashAccount = ledger['name'] == 'Cash';
                          
                          return GestureDetector(
                            onLongPress: () {
                              // Don't allow selection of Cash account
                              if (!isCashAccount) {
                                setState(() {
                                  if (!isSelectionMode) {
                                    isSelectionMode = true;
                                    selectedLedgers.add(ledgerId);
                                  }
                                });
                              } else {
                                // Show message that Cash account cannot be deleted
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Cash account cannot be deleted. You can only modify its opening balance.'),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              }
                            },
                            onTap: () {
                              if (isSelectionMode) {
                                // Don't allow selection of Cash account
                                if (!isCashAccount) {
                                  setState(() {
                                    if (isSelected) {
                                      selectedLedgers.remove(ledgerId);
                                      if (selectedLedgers.isEmpty) {
                                        isSelectionMode = false;
                                      }
                                    } else {
                                      selectedLedgers.add(ledgerId);
                                    }
                                  });
                                }
                              } else {
                                // Navigate to ledger creation page for editing all accounts
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LedgerCreation(existingLedger: ledger),
                                  ),
                                ).then((_) => _loadLedgers());
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              color: isSelected 
                                  ? const Color(0xFFB8E0D2) 
                                  : (index % 2 == 0 ? const Color(0xFFE0F2E9) : Colors.white),
                              child: Row(
                                children: [
                                  if (isSelectionMode)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: Checkbox(
                                        value: isSelected,
                                        activeColor: const Color(0xFF4C7380),
                                        // Disable checkbox for Cash account
                                        onChanged: isCashAccount 
                                            ? null  // Disabled for Cash account
                                            : (bool? value) {
                                                setState(() {
                                                  if (value == true) {
                                                    selectedLedgers.add(ledgerId);
                                                  } else {
                                                    selectedLedgers.remove(ledgerId);
                                                    if (selectedLedgers.isEmpty) {
                                                      isSelectionMode = false;
                                                    }
                                                  }
                                                });
                                              },
                                      ),
                                    ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      ledger['name'] as String,
                                      style: const TextStyle(
                                        color: Color(0xFF2C5545),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      ledger['classification'] as String? ?? '',
                                      style: const TextStyle(
                                        color: Color(0xFF2C5545),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '${ledger['balance'] ?? 0.0}',
                                      style: const TextStyle(
                                        color: Color(0xFF2C5545),
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: isSelectionMode
          ? null
          : Container(
              width: 80,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF4C7380),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showAddLedgerDialog,
                  child: const Center(
                    child: Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
