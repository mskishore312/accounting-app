import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/ui/receipt_voucher_list.dart';
import 'package:accounting_app/ui/payment_voucher_list.dart';
import 'package:accounting_app/ui/journal_voucher_list.dart';
import 'package:provider/provider.dart';
import 'package:accounting_app/services/period_service.dart';

class AccountingVouchers extends StatefulWidget {
  const AccountingVouchers({Key? key}) : super(key: key);

  @override
  State<AccountingVouchers> createState() => _AccountingVouchersState();
}

class _AccountingVouchersState extends State<AccountingVouchers> {
  List<Map<String, dynamic>> vouchers = [];
  bool isLoading = true;
  
  // Voucher type counts
  Map<String, int> voucherCounts = {
    'Receipt': 0,
    'Payment': 0,
    'Journal': 0,
    'Contra': 0,
    'Sales': 0,
    'Purchase': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadVouchers();
  }

  Future<void> _loadVouchers() async {
    try {
      final periodService = Provider.of<PeriodService>(context, listen: false);
      final loadedVouchers = await StorageService.getVouchers();
      
      // Reset counts
      voucherCounts = {
        'Receipt': 0,
        'Payment': 0,
        'Journal': 0,
        'Contra': 0,
        'Sales': 0,
        'Purchase': 0,
      };
      
      // Filter vouchers by period and count by type
      final filteredVouchers = loadedVouchers.where((voucher) {
        final voucherDate = voucher['voucher_date'] as String?;
        if (voucherDate == null || voucherDate.isEmpty) return false;
        
        // Compare with period dates
        if (periodService.startDateString.isNotEmpty && 
            voucherDate.compareTo(periodService.startDateString) < 0) {
          return false;
        }
        if (periodService.endDateString.isNotEmpty && 
            voucherDate.compareTo(periodService.endDateString) > 0) {
          return false;
        }
        return true;
      }).toList();
      
      // Count filtered vouchers by type
      for (var voucher in filteredVouchers) {
        final type = voucher['type'] as String;
        if (voucherCounts.containsKey(type)) {
          voucherCounts[type] = (voucherCounts[type] ?? 0) + 1;
        }
      }
      
      setState(() {
        vouchers = filteredVouchers;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading vouchers: $e')),
        );
      }
    }
  }

  Widget _buildVoucherButton(String type, {required VoidCallback onPressed}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4C7380),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          elevation: 2,
        ),
        child: Text(
          '$type (${voucherCounts[type] ?? 0})',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate total vouchers
    final totalVouchers = voucherCounts.values.fold(0, (sum, count) => sum + count);
    
    return Consumer<PeriodService>(
      builder: (context, periodService, child) {
        // Reload vouchers when period changes
        if (!isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadVouchers();
          });
        }
        
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
              'Vouchers',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Expanded(
                        child: ListView(
                          children: [
                            _buildVoucherButton(
                              'Receipt',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ReceiptVoucherList(),
                                  ),
                                ).then((_) => _loadVouchers());
                              },
                            ),
                            _buildVoucherButton(
                              'Payment',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const PaymentVoucherList(),
                                  ),
                                ).then((_) => _loadVouchers());
                              },
                            ),
                            _buildVoucherButton(
                              'Journal',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const JournalVoucherList(),
                                  ),
                                ).then((_) => _loadVouchers());
                              },
                            ),
                            _buildVoucherButton(
                              'Contra',
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Contra Voucher coming soon')),
                                );
                              },
                            ),
                            _buildVoucherButton(
                              'Sales',
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Sales Voucher coming soon')),
                                );
                              },
                            ),
                            _buildVoucherButton(
                              'Purchase',
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Purchase Voucher coming soon')),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Total Vouchers: $totalVouchers',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C5545),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
        );
      },
    );
  }
}