import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/ui/payment_voucher.dart';
import 'package:accounting_app/services/period_service.dart';
import 'package:provider/provider.dart';

class PaymentVoucherList extends StatefulWidget {
  const PaymentVoucherList({Key? key}) : super(key: key);

  @override
  State<PaymentVoucherList> createState() => _PaymentVoucherListState();
}

class _PaymentVoucherListState extends State<PaymentVoucherList> {
  List<Map<String, dynamic>> paymentVouchers = [];
  bool isLoading = true;

  // Multi-select state
  final Set<int> _selectedIds = {};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentVouchers();
  }

  Future<void> _loadPaymentVouchers() async {
    try {
      // Get payment vouchers with enhanced information and chronological order
      final payments = await StorageService.getPaymentVouchersWithParticulars();

      setState(() {
        paymentVouchers = payments;
        isLoading = false;
        // If reloading the list, clear selection if some IDs are no longer present
        _selectedIds.removeWhere(
          (id) => !paymentVouchers.any((v) => (v['id'] as int) == id),
        );
        if (_selectedIds.isEmpty) _selectionMode = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading payment vouchers: $e')),
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

  // Selection helpers
  void _enterSelectionMode(int id) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      if (_selectedIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  bool get _allSelected =>
      paymentVouchers.isNotEmpty &&
      _selectedIds.length == paymentVouchers.length;

  void _toggleSelectAll(bool? value) {
    setState(() {
      if (value == true) {
        _selectedIds
          ..clear()
          ..addAll(paymentVouchers.map((v) => v['id'] as int));
        _selectionMode = true;
      } else {
        _selectedIds.clear();
        _selectionMode = false;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete selected vouchers?'),
          content: Text(
              'Are you sure you want to delete ${_selectedIds.length} selected voucher(s)? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final ids = _selectedIds.toList();
      final deletedCount = await StorageService.deleteVouchers(ids);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $deletedCount voucher(s)'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _clearSelection();
      await _loadPaymentVouchers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting vouchers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = const Color(0xFF2C5545);

    return Scaffold(
      backgroundColor: const Color(0xFFE0F2E9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C5545),
        title: Text(
          _selectionMode
              ? '${_selectedIds.length} selected'
              : 'Kishore',
          style: const TextStyle(
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
        actions: [
          if (_selectionMode) ...[
            IconButton(
              tooltip: 'Delete selected',
              onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
              icon: const Icon(Icons.delete, color: Colors.white),
            ),
            IconButton(
              tooltip: 'Clear selection',
              onPressed: _clearSelection,
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Title container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: const Color(0xFFE0F2E9),
            child: const Text(
              'Payment Vouchers',
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
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: borderColor, width: 1),
                bottom: BorderSide(color: borderColor, width: 1),
              ),
            ),
            child: Row(
              children: [
                if (_selectionMode)
                  Container(
                    width: 48,
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: borderColor, width: 1),
                      ),
                    ),
                    child: Center(
                      child: Checkbox(
                        value: _allSelected,
                        onChanged: (v) => _toggleSelectAll(v),
                        activeColor: const Color(0xFF2C5545),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: borderColor, width: 1),
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
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: borderColor, width: 1),
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
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: const Text(
                      'Debit',
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
                : paymentVouchers.isEmpty
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
                            'No payment vouchers found.\nCreate a new payment voucher to get started.',
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
                        itemCount: paymentVouchers.length,
                        itemBuilder: (context, index) {
                          final voucher = paymentVouchers[index];
                          final voucherId = voucher['id'] as int;
                          final formattedDate =
                              _formatDate(voucher['voucher_date'] as String?);
                          final particulars =
                              voucher['particulars'] as String? ?? 'Unknown';
                          final total = (voucher['total'] as num?)?.toDouble() ?? 0.0;

                          final selected = _selectedIds.contains(voucherId);

                          return GestureDetector(
                            onLongPress: () {
                              if (!_selectionMode) {
                                _enterSelectionMode(voucherId);
                              }
                            },
                            onTap: () {
                              if (_selectionMode) {
                                _toggleSelection(voucherId);
                              } else {
                                // Navigate to edit the voucher
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        PaymentVoucher(voucherId: voucherId),
                                  ),
                                ).then((_) => _loadPaymentVouchers());
                              }
                            },
                            child: Container(
                              color: selected
                                  ? const Color(0x332C5545) // light selection overlay
                                  : const Color(0xFFE0F2E9),
                              child: Row(
                                children: [
                                  if (_selectionMode)
                                    Container(
                                      width: 48,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                              color: borderColor, width: 1),
                                          bottom: BorderSide(
                                              color: borderColor, width: 1),
                                        ),
                                      ),
                                      child: Center(
                                        child: Checkbox(
                                          value: selected,
                                          onChanged: (_) => _toggleSelection(voucherId),
                                          activeColor: const Color(0xFF2C5545),
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    ),
                                  // Date column
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 8),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                              color: borderColor, width: 1),
                                          bottom: BorderSide(
                                              color: borderColor, width: 1),
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
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 8),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                              color: borderColor, width: 1),
                                          bottom: BorderSide(
                                              color: borderColor, width: 1),
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
                                  // Debit column
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 8),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                              color: borderColor, width: 1),
                                        ),
                                      ),
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
          // Bottom actions
          if (!_selectionMode)
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PaymentVoucher(),
                      ),
                    ).then((_) => _loadPaymentVouchers());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4C7380),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 24),
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
          if (_selectionMode)
            Container(
              width: double.infinity,
              color: const Color(0xFFE0F2E9),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete Selected'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _clearSelection,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Color(0xFF2C5545)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
