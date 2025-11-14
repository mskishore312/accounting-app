import 'package:flutter/material.dart';
import 'package:accounting_app/ui/account_masters.dart';
import 'package:accounting_app/data/storage_service.dart';

class MasterOptions extends StatefulWidget {
  const MasterOptions({Key? key}) : super(key: key);

  @override
  _MasterOptionsState createState() => _MasterOptionsState();
}

class _MasterOptionsState extends State<MasterOptions> {
  bool _isLoading = true;
  String? _error;
  int accountMastersCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAccountMastersCount();
  }

  Future<void> _loadAccountMastersCount() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Get the selected company data
      final selectedCompany = await StorageService.getSelectedCompany();
      if (selectedCompany == null) {
        throw Exception('No company selected');
      }
      
      final companyId = selectedCompany['id'] as int;

      // Load ledgers for the company
      final ledgers = await StorageService.getLedgers();
      
      // Check if Cash account exists
      bool hasCashAccount = ledgers.any((ledger) => ledger['name'] == 'Cash');
      
      // If Cash account doesn't exist, create it
      if (!hasCashAccount) {
        print('Creating Cash account for company ID: $companyId');
        
        // Create a new Cash account - check if classification column exists
        final cashLedger = {
          'company_id': companyId,
          'name': 'Cash',
          'balance': 0.0,
        };
        
        // Try to add classification if the column exists
        try {
          cashLedger['classification'] = 'Cash-in-hand';
        } catch (e) {
          print('Classification column might not exist: $e');
        }
        
        // Try to add is_default if the column exists
        try {
          cashLedger['is_default'] = 1;
        } catch (e) {
          print('is_default column might not exist: $e');
        }
        
        // Save the Cash account to the database
        final cashId = await StorageService.saveLedger(cashLedger);
        print('Created Cash account with ID: $cashId');
        
        // Reload ledgers to include the new Cash account
        final updatedLedgers = await StorageService.getLedgers();
        
        if (mounted) {
          setState(() {
            accountMastersCount = updatedLedgers.length;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            accountMastersCount = ledgers.length;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading account masters count: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
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
              'TOM-PA 9.0 (R 7.9)',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 60,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAccountMastersCount,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: const Color(0xFF2C5545),
                      padding: const EdgeInsets.all(16.0),
                      child: const Text(
                        'Masters',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            _buildMasterButton(
                              context,
                              'Account Masters ($accountMastersCount)',
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const AccountMasters(),
                                  ),
                                ).then((_) => _loadAccountMastersCount());
                              },
                            ),
                            _buildMasterButton(
                              context,
                              'Inventory Masters (0)',
                              () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Inventory Masters coming soon'),
                                  ),
                                );
                              },
                            ),
                            _buildMasterButton(
                              context,
                              'Tax Masters (0)',
                              () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Tax Masters coming soon'),
                                  ),
                                );
                              },
                            ),
                            _buildMasterButton(
                              context,
                              'GST Tax Masters (0)',
                              () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('GST Tax Masters coming soon'),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildMasterButton(BuildContext context, String title, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4C7380),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
