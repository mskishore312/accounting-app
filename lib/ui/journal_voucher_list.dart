import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/ui/journal_voucher.dart';
import 'package:accounting_app/services/period_service.dart';
import 'package:provider/provider.dart';


class JournalVoucherList extends StatefulWidget {
  const JournalVoucherList({Key? key}) : super(key: key);

  @override
  State<JournalVoucherList> createState() => _JournalVoucherListState();
}

class _JournalVoucherListState extends State<JournalVoucherList> {
  List<Map<String, dynamic>> journalVouchers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJournalVouchers();
  }

  Future<void> _loadJournalVouchers() async {
    try {
      // Get journal vouchers with enhanced information
      final journals = await StorageService.getVouchers(null, 'Journal');
      
      setState(() {
        journalVouchers = journals;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading journal vouchers: $e')),
        );
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      // Parse the date string (assuming it's in format YYYY-MM-DD)
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        // It's in YYYY-MM-DD format, convert to DD/MM/YYYY
        final year = parts[0];
        final month = parts[1];
        final day = parts[2];
        return '$day/$month/$year';
      }
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2E9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C5545),
        title: const Text(
          'Kishore',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
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
          // Title container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: const Color(0xFFE0F2E9),
            child: const Text(
              'Journal Vouchers',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C5545),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Period container
          Consumer<PeriodService>(
            builder: (context, periodService, child) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: const Color(0xFFE0F2E9),
                child: Text(
                  'Curr. Period ${periodService.periodText}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF2C5545),
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
          // Table header
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFF2C5545), width: 1),
                bottom: BorderSide(color: Color(0xFF2C5545), width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: const BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Color(0xFF2C5545), width: 1),
                      ),
                    ),
                    child: const Text(
                      'Date',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C5545),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: const BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Color(0xFF2C5545), width: 1),
                      ),
                    ),
                    child: const Text(
                      'Particulars',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C5545),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: const Text(
                      'Amount',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C5545),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Table content
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : journalVouchers.isEmpty
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0x1A000000), // 10% opacity black
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            'No journal vouchers found.\nCreate a new journal voucher to get started.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF2C5545),
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: journalVouchers.length,
                        itemBuilder: (context, index) {
                          final voucher = journalVouchers[index];
                          final voucherId = voucher['id'] as int;
                          final formattedDate = _formatDate(voucher['voucher_date']);
                          final particulars = voucher['particulars'] as String? ?? 'Unknown';
                          final total = voucher['total'] as double? ?? 0.0;
                          
                          return GestureDetector(
                            onTap: () {
                              // Navigate to edit the voucher
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => JournalVoucher(voucherId: voucherId),
                                ),
                              ).then((_) => _loadJournalVouchers());
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2E9),
                                border: Border(
                                  bottom: BorderSide(color: const Color(0xFF2C5545), width: 1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Date column
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          right: BorderSide(color: Color(0xFF2C5545), width: 1),
                                        ),
                                      ),
                                      child: Text(
                                        formattedDate,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF2C5545),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Particulars column
                                  Expanded(
                                    flex: 3,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          right: BorderSide(color: Color(0xFF2C5545), width: 1),
                                        ),
                                      ),
                                      child: Text(
                                        particulars,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF2C5545),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  // Amount column
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                      child: Text(
                                        total.toStringAsFixed(2),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF2C5545),
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          // Add button
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const JournalVoucher(),
                    ),
                  ).then((_) => _loadJournalVouchers());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4C7380),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                ),
                child: const Text(
                  'Add',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}