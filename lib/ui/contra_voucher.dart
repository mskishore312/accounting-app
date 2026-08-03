import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/ui/widgets/voucher_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ContraVoucher extends StatefulWidget {
  const ContraVoucher({super.key, this.voucherId});

  final int? voucherId;

  @override
  State<ContraVoucher> createState() => _ContraVoucherState();
}

class _ContraVoucherState extends State<ContraVoucher> {
  final formKey = GlobalKey<FormState>();
  final number = TextEditingController();
  final amount = TextEditingController();
  final narration = TextEditingController();
  List<Map<String, dynamic>> ledgers = [];
  final List<String> _pendingImages = [];
  int? fromLedgerId;
  int? toLedgerId;
  DateTime date = DateTime.now();
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    number.dispose();
    amount.dispose();
    narration.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final all = await StorageService.getLedgers();
    ledgers = all.where((ledger) {
      final group = ledger['classification'] as String? ?? '';
      return ['Bank Accounts', 'Bank OD A/c', 'Cash-in-hand'].contains(group);
    }).toList();
    if (widget.voucherId == null) {
      number.text = await StorageService.getNextVoucherNumber('Contra');
      if (ledgers.isNotEmpty) fromLedgerId = ledgers.first['id'] as int;
      if (ledgers.length > 1) toLedgerId = ledgers[1]['id'] as int;
    } else {
      final voucher = await StorageService.getVoucherById(widget.voucherId!);
      if (voucher != null) {
        number.text = voucher['voucher_number'] as String;
        date = DateTime.tryParse(voucher['voucher_date'] as String? ?? '') ?? date;
        amount.text = (voucher['total'] as num).toStringAsFixed(2);
        final entries = voucher['entries'] as List;
        for (final entry in entries) {
          if ((entry['credit'] as num).toDouble() > 0) {
            fromLedgerId = entry['ledger_id'] as int;
          }
          if ((entry['debit'] as num).toDouble() > 0) {
            toLedgerId = entry['ledger_id'] as int;
          }
          narration.text = entry['description'] as String? ?? '';
        }
      }
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null) setState(() => date = selected);
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    if (fromLedgerId == toLedgerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select two different cash/bank ledgers')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      final savedId = await StorageService.saveContraVoucher(
        voucherId: widget.voucherId,
        voucherNumber: number.text.trim(),
        voucherDate: DateFormat('yyyy-MM-dd').format(date),
        fromLedgerId: fromLedgerId!,
        toLedgerId: toLedgerId!,
        amount: double.parse(amount.text.replaceAll(',', '')),
        narration: narration.text.trim(),
      );
      if (_pendingImages.isNotEmpty) {
        await VoucherImagePicker.saveAllPending(savedId, _pendingImages);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save contra voucher: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.voucherId == null ? 'New Contra' : 'Edit Contra'),
        backgroundColor: const Color(0xFF2C5545),
        foregroundColor: Colors.white,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: number,
                    decoration: const InputDecoration(
                      labelText: 'Voucher number',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    title: const Text('Date'),
                    subtitle: Text(DateFormat('dd/MM/yyyy').format(date)),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 12),
                  _ledgerDropdown('From cash/bank', fromLedgerId, (value) {
                    setState(() => fromLedgerId = value);
                  }),
                  const SizedBox(height: 12),
                  _ledgerDropdown('To cash/bank', toLedgerId, (value) {
                    setState(() => toLedgerId = value);
                  }),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final parsed = double.tryParse((value ?? '').replaceAll(',', ''));
                      return parsed == null || parsed <= 0 ? 'Enter a valid amount' : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: narration,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Narration',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  VoucherImagePicker(
                    voucherId: widget.voucherId,
                    pendingImages: _pendingImages,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: saving || ledgers.length < 2 ? null : _save,
                    icon: const Icon(Icons.save),
                    label: Text(saving ? 'Saving…' : 'Save Contra Voucher'),
                  ),
                  if (ledgers.length < 2)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Create at least two Cash/Bank ledgers before recording a contra voucher.',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _ledgerDropdown(
    String label,
    int? value,
    ValueChanged<int?> onChanged,
  ) {
    return DropdownButtonFormField<int>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: ledgers
          .map((ledger) => DropdownMenuItem<int>(
                value: ledger['id'] as int,
                child: Text(ledger['name'] as String),
              ))
          .toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'Required' : null,
    );
  }
}
