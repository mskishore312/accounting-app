import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/ui/receipt_voucher.dart';
import 'package:accounting_app/services/period_service.dart';
import 'package:provider/provider.dart';


class ReceiptVoucherList extends StatefulWidget {
  const ReceiptVoucherList({Key? key}) : super(key: key);

  @override
  State<ReceiptVoucherList> createState() => _ReceiptVoucherListState();
}

class _ReceiptVoucherListState extends State<ReceiptVoucherList> {
  List<Map<String, dynamic>> receiptVouchers = [];
  bool isLoading = true;
  final Set<int> _selectedVoucherIds = {}; // Track selected voucher IDs
  bool _isSelecting = false; // Flag for selection mode

  @override
  void initState() {
    super.initState();
    _loadReceiptVouchers();
  }

  Future<void> _loadReceiptVouchers() async {
    try {
      // Get receipt vouchers with particulars (credit ledger name)
      final receipts = await StorageService.getReceiptVouchersWithParticulars();
      
      setState(() {
        receiptVouchers = receipts;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading receipt vouchers: $e')),
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

  // Toggle selection state for a voucher
  void _toggleSelection(int voucherId) {
    setState(() {
      if (_selectedVoucherIds.contains(voucherId)) {
        _selectedVoucherIds.remove(voucherId);
        if (_selectedVoucherIds.isEmpty) {
          _isSelecting = false; // Exit selection mode if nothing is selected
        }
      } else {
        _selectedVoucherIds.add(voucherId);
        _isSelecting = true; // Enter selection mode if not already in it
      }
    });
  }

  // Clear current selection
  void _clearSelection() {
    setState(() {
      _selectedVoucherIds.clear();
      _isSelecting = false;
    });
  }

  // Show confirmation and delete selected vouchers
  Future<void> _deleteSelectedVouchers() async {
    if (_selectedVoucherIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete ${_selectedVoucherIds.length} selected voucher(s)? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false); // Not confirmed
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop(true); // Confirmed
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final count = await StorageService.deleteVouchers(_selectedVoucherIds.toList());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$count voucher(s) deleted successfully')),
          );
        }
        _clearSelection(); // Clear selection after deletion
        _loadReceiptVouchers(); // Refresh the list
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting vouchers: $e')),
          );
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // Determine AppBar content based on selection mode
    final appBar = _isSelecting
        ? AppBar(
            elevation: 0,
            backgroundColor: Colors.blueGrey[700], // Different color for selection mode
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _clearSelection, // Button to clear selection
            ),
            title: Text(
              '${_selectedVoucherIds.length} selected',
              style: const TextStyle(color: Colors.white),
            ),
            actions: [
              PopupMenuButton<String>(
                onSelected: (String result) {
                  if (result == 'delete') {
                    _deleteSelectedVouchers();
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
                icon: const Icon(Icons.more_vert, color: Colors.white),
              ),
            ],
          )
        : AppBar( // Default AppBar
            elevation: 0,
            backgroundColor: const Color(0xFF2C5545),
            title: const Text(
              'Kishore', // Consider making this dynamic or removing if not needed
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
          );

    return Scaffold(
      backgroundColor: const Color(0xFFE0F2E9),
      appBar: appBar, // Use the dynamically determined AppBar
      body: Column(
        children: [
          // Title container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: const Color(0xFFE0F2E9),
            child: const Text(
              'Receipt Vouchers',
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
                      'Credit',
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
                : receiptVouchers.isEmpty
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
                            'No receipt vouchers found.\nCreate a new receipt voucher to get started.',
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
                        itemCount: receiptVouchers.length,
                        itemBuilder: (context, index) {
                          final voucher = receiptVouchers[index];
                          final voucherId = voucher['id'] as int;
                          final formattedDate = _formatDate(voucher['voucher_date']);
                          final particulars = voucher['particulars'] as String? ?? 'Unknown';
                          final total = voucher['total'] as double? ?? 0.0;
                          final isSelected = _selectedVoucherIds.contains(voucherId); // Check if item is selected

                          return GestureDetector(
                             onTap: () {
                              if (_isSelecting) {
                                _toggleSelection(voucherId); // Toggle selection if in selection mode
                              } else {
                                // Navigate to edit the voucher
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ReceiptVoucher(voucherId: voucherId),
                                  ),
                                ).then((_) => _loadReceiptVouchers()); // Refresh list after edit
                              }
                            },
                            onLongPress: () {
                              if (!_isSelecting) {
                                _toggleSelection(voucherId); // Enter selection mode and select item
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                // Highlight selected items
                                color: isSelected ? Colors.blue.withOpacity(0.3) : const Color(0xFFE0F2E9),
                                border: Border(
                                  bottom: BorderSide(color: const Color(0xFF2C5545), width: 0.5), // Thinner border
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
                                  // Credit column
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
                      builder: (context) => const ReceiptVoucher(),
                    ),
                  ).then((_) => _loadReceiptVouchers());
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
