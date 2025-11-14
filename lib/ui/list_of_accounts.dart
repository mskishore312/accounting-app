import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';

class ListOfAccounts extends StatefulWidget {
  const ListOfAccounts({Key? key}) : super(key: key);

  @override
  _ListOfAccountsState createState() => _ListOfAccountsState();
}

class _ListOfAccountsState extends State<ListOfAccounts> {
  List<Map<String, dynamic>> accounts = [];
  List<Map<String, dynamic>> filteredAccounts = [];
  TextEditingController searchController = TextEditingController();
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final company = await StorageService.getSelectedCompany();
      if (company == null) throw Exception('No company selected');

      final loadedAccounts = await StorageService.getLedgers(company['id']);

      setState(() {
        accounts = loadedAccounts;
        filteredAccounts = accounts;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Error loading accounts: $e';
        isLoading = false;
      });
    }
  }

  void _filterAccounts(String query) {
    setState(() {
      filteredAccounts = accounts.where((account) {
        return account['name'].toString().toLowerCase().contains(query.toLowerCase()) ||
               account['under'].toString().toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2E9),
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
              'TOM-PA 9.0 (R 7.9)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
              'List of Accounts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x1A000000),  // 10% opacity black
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or category...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF2C5545)),
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
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: _filterAccounts,
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              error!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadAccounts,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2C5545),
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0x1A000000),  // 10% opacity black
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFF1B3834),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _buildHeaderCell('Sr.No', 1),
                                  _buildHeaderCell('Name', 3),
                                  _buildHeaderCell('Under', 3),
                                  _buildHeaderCell('Balance', 2),
                                  _buildHeaderCell('Tin/GST No', 2),
                                ],
                              ),
                            ),
                            Expanded(
                              child: filteredAccounts.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No accounts found',
                                        style: TextStyle(
                                          color: Color(0xFF2C5545),
                                          fontSize: 16,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: filteredAccounts.length,
                                      itemBuilder: (context, index) {
                                        final account = filteredAccounts[index];
                                        return Container(
                                          decoration: BoxDecoration(
                                            color: index.isEven
                                                ? const Color(0xFFF5F9F7)
                                                : Colors.white,
                                            border: Border(
                                              bottom: BorderSide(
                                                color: const Color(0xFF2C5545)
                                                    .withAlpha(26),  // 10% opacity
                                              ),
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                            child: Row(
                                              children: [
                                                _buildCell((index + 1).toString(), 1),
                                                _buildCell(account['name'], 3),
                                                _buildCell(account['under'], 3),
                                                _buildCell(
                                                    '${account['opening_balance'] ?? '0.00'} ${account['balance_type'] ?? 'Dr.'}',
                                                    2),
                                                _buildCell(
                                                    account['tin_gst_no'] ?? '-', 2),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildCell(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF2C5545),
          height: 1.5,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
