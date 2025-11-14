import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/ui/ledger_view.dart';

class LedgerList extends StatefulWidget {
  const LedgerList({Key? key}) : super(key: key);

  @override
  State<LedgerList> createState() => _LedgerListState();
}

class _LedgerListState extends State<LedgerList> {
  List<Map<String, dynamic>> ledgers = [];
  List<Map<String, dynamic>> filteredLedgers = [];
  bool isLoading = true;
  final _searchController = TextEditingController();

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
      final loadedLedgers = await StorageService.getLedgers();
      setState(() {
        ledgers = loadedLedgers;
        filteredLedgers = loadedLedgers;
        isLoading = false;
      });
    } catch (e) {
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
      if (query.isEmpty) {
        filteredLedgers = ledgers;
      } else {
        final searchQuery = query.toLowerCase();
        filteredLedgers = ledgers.where((ledger) {
          final name = ledger['name'].toString().toLowerCase();

          // Check if name starts with the query (prefix match)
          if (name.startsWith(searchQuery)) {
            return true;
          }

          // Also check if any word in the name starts with the query
          final nameWords = name.split(' ');
          for (final word in nameWords) {
            if (word.startsWith(searchQuery)) {
              return true;
            }
          }

          return false;
        }).toList();
      }
    });
  }

  Future<void> _viewLedgerReport(Map<String, dynamic> ledger) async {
    try {
      final report = await StorageService.getLedgerReport(ledger['id'] as int);
      if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LedgerView(
                            ledger: ledger,
                            initialEntries: report, // Ensure this uses the fetched report data
                          ),
                        ),
                      );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading ledger report: $e')),
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
              'Select Ledger',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFE0F2E9),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterLedgers,
                    decoration: InputDecoration(
                      hintText: 'Search ledgers...',
                      prefixIcon: const Icon(Icons.search),
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF2C5545)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF2C5545), width: 2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredLedgers.isEmpty
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
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
                          child: const Text(
                            'No ledgers found.\nCreate ledgers to view their reports.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF2C5545),
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filteredLedgers.length,
                        separatorBuilder: (context, index) => const Divider(
                          color: Color(0xFF2C5545),
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final ledger = filteredLedgers[index];
                          return InkWell(
                            onTap: () => _viewLedgerReport(ledger),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                              child: Text(
                                ledger['name'] as String,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.normal,
                                  color: Color(0xFF2C5545),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
