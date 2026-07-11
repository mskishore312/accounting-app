import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/services/pdf_service.dart';
import 'package:accounting_app/ui/contra_voucher.dart';
import 'package:accounting_app/ui/invoice_voucher.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class VoucherTypeList extends StatefulWidget {
  const VoucherTypeList({super.key, required this.type});

  final String type;

  @override
  State<VoucherTypeList> createState() => _VoucherTypeListState();
}

class _VoucherTypeListState extends State<VoucherTypeList> {
  List<Map<String, dynamic>> vouchers = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await StorageService.getVouchersByType(widget.type);
    if (!mounted) return;
    setState(() {
      vouchers = rows;
      loading = false;
    });
  }

  Future<void> _open([int? id]) async {
    final page = widget.type == 'Contra'
        ? ContraVoucher(voucherId: id)
        : InvoiceVoucher(type: widget.type, voucherId: id);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    await _load();
  }

  Future<void> _delete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete voucher?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (widget.type == 'Sales' || widget.type == 'Purchase') {
        await StorageService.deleteInvoiceVoucher(id);
      } else {
        await StorageService.deleteVouchers(id);
      }
      await _load();
    }
  }

  Future<void> _shareInvoice(int id) async {
    final invoice = await StorageService.getInvoiceVoucher(id);
    final company = await StorageService.getSelectedCompany();
    if (invoice == null || company == null) return;
    final ledgers = await StorageService.getLedgers();
    String ledgerName(int ledgerId) => ledgers.firstWhere(
          (ledger) => ledger['id'] == ledgerId,
          orElse: () => {'name': ''},
        )['name'] as String;
    final file = await PdfService.generateTaxInvoicePdf(
      company: company,
      invoice: invoice,
      partyName: ledgerName(invoice['party_ledger_id'] as int),
    );
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: '${widget.type} ${invoice['voucher_number']}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.type} Vouchers'),
        backgroundColor: const Color(0xFF2C5545),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        icon: const Icon(Icons.add),
        label: Text('New ${widget.type}'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : vouchers.isEmpty
              ? Center(child: Text('No ${widget.type.toLowerCase()} vouchers'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: vouchers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final row = vouchers[index];
                    final rawDate = row['voucher_date'] as String? ?? '';
                    final date = DateTime.tryParse(rawDate);
                    return Card(
                      child: ListTile(
                        onTap: () => _open(row['id'] as int),
                        title: Text(
                          '${row['voucher_number']}  •  ${row['particulars']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          date == null
                              ? rawDate
                              : DateFormat('dd/MM/yyyy').format(date),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('₹${(row['total'] as num).toStringAsFixed(2)}'),
                            if (widget.type != 'Contra')
                              IconButton(
                                tooltip: 'Export PDF',
                                onPressed: () => _shareInvoice(row['id'] as int),
                                icon: const Icon(Icons.picture_as_pdf),
                              ),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: () => _delete(row['id'] as int),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
