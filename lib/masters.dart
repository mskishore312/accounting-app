import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';

class Masters extends StatefulWidget {
  final String companyName;

  const Masters({Key? key, required this.companyName}) : super(key: key);

  @override
  _MastersState createState() => _MastersState();
}

class _MastersState extends State<Masters> {
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

      // Load ledgers for the company
      final companies = await StorageService.loadCompanies();
      final company = companies.firstWhere(
        (c) => c['id'] == selectedCompany['id'],
        orElse: () => throw Exception('Company not found'),
      );

      final ledgers = company['ledgers'] as List<dynamic>? ?? [];

      if (mounted) {
        setState(() {
          // Add 1 for the default Cash ledger
          accountMastersCount = ledgers.length + 1;
          _isLoading = false;
        });
      }
    } catch (e) {
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
        title: const Text('Masters'),
        backgroundColor: const Color(0xFF4C7380),
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
                      color: const Color(0xFF4C7380),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'Options',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.companyName,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
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
                                Navigator.pushNamed(
                                  context,
                                  '/account_masters',
                                  arguments: {
                                    'companyName': widget.companyName,
                                  },
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
        ),
        child: Text(title),
      ),
    );
  }
}
