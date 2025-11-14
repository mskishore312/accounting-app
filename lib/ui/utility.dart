import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/ui/gateway.dart';
import 'package:accounting_app/ui/company_settings_selection.dart';
import 'package:accounting_app/ui/edit_company.dart';

class Utility extends StatelessWidget {
  const Utility({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF5F0),

      
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF2C5545),
              ),
              child: Row(
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
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFF2C5545),
                    width: 1,
                  ),
                ),
              ),
              child: const Text(
                'Utility',
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildButton(
                      'Company Edit',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EditCompanyScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      'Backup',
                      onPressed: () {
                        // TODO: Implement Backup
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      'Backup And Mail',
                      onPressed: () {
                        // TODO: Implement Backup And Mail
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      'Restore',
                      onPressed: () {
                        // TODO: Implement Restore
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      'Split Company',
                      onPressed: () {
                        // TODO: Implement Split Company
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      'Delete Company',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DeleteCompanyScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      'Settings',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CompanySettingsSelection(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      'Emergency Backup',
                      onPressed: () {
                        // TODO: Implement Emergency Backup
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      'Emergency Restore',
                      onPressed: () {
                        // TODO: Implement Emergency Restore
                      },
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

  Widget _buildButton(String text, {required VoidCallback onPressed}) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF4C7380),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DeleteCompanyScreen extends StatefulWidget {
  const DeleteCompanyScreen({Key? key}) : super(key: key);

  @override
  State<DeleteCompanyScreen> createState() => _DeleteCompanyScreenState();
}

class _DeleteCompanyScreenState extends State<DeleteCompanyScreen> {
  List<Map<String, dynamic>> companies = [];
  Set<int> selectedCompanies = {};
  bool isLoading = true;
  bool isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    try {
      final loadedCompanies = await StorageService.loadCompanies();
      setState(() {
        companies = loadedCompanies;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading companies: $e')),
        );
      }
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      isSelectionMode = !isSelectionMode;
      if (!isSelectionMode) {
        selectedCompanies.clear();
      }
    });
  }

  void _toggleCompanySelection(int companyId) {
    setState(() {
      if (selectedCompanies.contains(companyId)) {
        selectedCompanies.remove(companyId);
      } else {
        selectedCompanies.add(companyId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      selectedCompanies = Set.from(companies.map((c) => c['id'] as int));
    });
  }

  void _deselectAll() {
    setState(() {
      selectedCompanies.clear();
    });
  }

  void _showDeleteConfirmationDialog() {
    final selectedCompanyNames = companies
        .where((c) => selectedCompanies.contains(c['id']))
        .map((c) => c['name'] as String)
        .toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            selectedCompanies.length == 1
                ? 'Delete Company?'
                : 'Delete ${selectedCompanies.length} Companies?',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Warning: All data for the following companies will be permanently deleted from this device. This action cannot be undone.',
                style: TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              const Text(
                'Companies to be deleted:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...selectedCompanyNames.map((name) => Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Text('• $name'),
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteSelectedCompanies();
              },
              child: const Text(
                'Yes, Delete All',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteSelectedCompanies() async {
    setState(() {
      isLoading = true;
    });

    try {
      for (final companyId in selectedCompanies) {
        await StorageService.deleteCompany(companyId);
      }

      final deletedCount = selectedCompanies.length;
      
      // Navigate back to Gateway
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Gateway()),
        (route) => false,
      );

      // Show confirmation message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deletedCount == 1
                ? 'Company deleted successfully'
                : '$deletedCount companies deleted successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting companies: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF5F0),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C5545),
        title: Row(
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
        actions: [
          if (isSelectionMode) ...[
            IconButton(
              icon: Icon(
                selectedCompanies.length == companies.length
                    ? Icons.deselect
                    : Icons.select_all,
              ),
              onPressed: selectedCompanies.length == companies.length
                  ? _deselectAll
                  : _selectAll,
            ),
            TextButton(
              onPressed: _toggleSelectionMode,
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: _toggleSelectionMode,
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF2C5545),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(15),
                bottomRight: Radius.circular(15),
              ),
            ),
            child: Text(
              isSelectionMode
                  ? '${selectedCompanies.length} Selected'
                  : 'Select Company to Delete',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : companies.isEmpty
                    ? const Center(
                        child: Text(
                          'No companies found.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                        itemCount: companies.length,
                        itemBuilder: (context, index) {
                          final company = companies[index];
                          final companyId = company['id'] as int;
                          final isSelected = selectedCompanies.contains(companyId);
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            height: 56,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF2C5545)
                                  : const Color(0xFF4C7380),
                              borderRadius: BorderRadius.circular(4),
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 2)
                                  : null,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  if (isSelectionMode) {
                                    _toggleCompanySelection(companyId);
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    children: [
                                      if (isSelectionMode)
                                        Checkbox(
                                          value: isSelected,
                                          onChanged: (_) {
                                            _toggleCompanySelection(companyId);
                                          },
                                          activeColor: Colors.white,
                                          checkColor: const Color(0xFF2C5545),
                                        ),
                                      Expanded(
                                        child: Text(
                                          company['name'] as String,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: isSelectionMode && selectedCompanies.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showDeleteConfirmationDialog,
              backgroundColor: Colors.red,
              icon: const Icon(Icons.delete),
              label: Text(
                'Delete (${selectedCompanies.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }
}
