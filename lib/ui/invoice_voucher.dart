import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/services/pdf_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class InvoiceVoucher extends StatefulWidget {
  const InvoiceVoucher({
    super.key,
    required this.type,
    this.voucherId,
  });

  final String type;
  final int? voucherId;

  @override
  State<InvoiceVoucher> createState() => _InvoiceVoucherState();
}

class _InvoiceVoucherState extends State<InvoiceVoucher> {
  final formKey = GlobalKey<FormState>();
  final number = TextEditingController();
  final narration = TextEditingController();
  final placeOfSupply = TextEditingController();
  List<Map<String, dynamic>> ledgers = [];
  List<Map<String, dynamic>> inventoryItems = [];
  final List<_InvoiceLineDraft> lines = [];
  int? partyLedgerId;
  int? accountLedgerId;
  DateTime date = DateTime.now();
  bool withInventory = false;
  bool interstate = false;
  bool loading = true;
  bool saving = false;
  int? savedVoucherId;

  bool get isSales => widget.type == 'Sales';

  List<Map<String, dynamic>> get accountLedgers => ledgers.where((ledger) {
        final group = ledger['classification'] as String? ?? '';
        return group == (isSales ? 'Sales Accounts' : 'Purchase Accounts');
      }).toList();

  List<Map<String, dynamic>> get partyLedgers => ledgers.where((ledger) {
        final id = ledger['id'] as int;
        return id != accountLedgerId;
      }).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    number.dispose();
    narration.dispose();
    placeOfSupply.dispose();
    for (final line in lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    ledgers = await StorageService.getLedgers();
    inventoryItems = await StorageService.getInventoryItems();
    if (widget.voucherId == null) {
      number.text = await StorageService.getNextVoucherNumber(widget.type);
      if (accountLedgers.isNotEmpty) {
        accountLedgerId = accountLedgers.first['id'] as int;
      }
      final parties = partyLedgers;
      if (parties.isNotEmpty) partyLedgerId = parties.first['id'] as int;
      lines.add(_InvoiceLineDraft());
    } else {
      savedVoucherId = widget.voucherId;
      final invoice = await StorageService.getInvoiceVoucher(widget.voucherId!);
      if (invoice != null) {
        number.text = invoice['voucher_number'] as String;
        date = DateTime.tryParse(invoice['voucher_date'] as String? ?? '') ?? date;
        withInventory = invoice['invoice_mode'] == 'inventory';
        partyLedgerId = invoice['party_ledger_id'] as int?;
        accountLedgerId = invoice['account_ledger_id'] as int?;
        placeOfSupply.text = invoice['place_of_supply'] as String? ?? '';
        narration.text = invoice['narration'] as String? ?? '';
        final storedLines = invoice['lines'] as List;
        interstate = storedLines.any((line) => (line['igst'] as num).toDouble() > 0);
        for (final line in storedLines) {
          lines.add(_InvoiceLineDraft.fromMap(Map<String, dynamic>.from(line)));
        }
      }
    }
    if (lines.isEmpty) lines.add(_InvoiceLineDraft());
    if (mounted) setState(() => loading = false);
  }

  Future<void> _createInventoryItem() async {
    final name = TextEditingController();
    final hsn = TextEditingController();
    final unit = TextEditingController(text: 'Nos');
    final rate = TextEditingController();
    final gst = TextEditingController(text: '18');
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create inventory item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Item name')),
              TextField(controller: hsn, decoration: const InputDecoration(labelText: 'HSN/SAC')),
              TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unit')),
              TextField(
                controller: rate,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Default rate'),
              ),
              TextField(
                controller: gst,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'GST rate %'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      ),
    );
    if (created == true && name.text.trim().isNotEmpty) {
      try {
        await StorageService.saveInventoryItem({
          'name': name.text.trim(),
          'hsn': hsn.text.trim(),
          'unit': unit.text.trim().isEmpty ? 'Nos' : unit.text.trim(),
          'default_rate': double.tryParse(rate.text) ?? 0,
          'gst_rate': double.tryParse(gst.text) ?? 0,
          'stock_qty': 0.0,
        });
        inventoryItems = await StorageService.getInventoryItems();
        if (mounted) setState(() {});
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not create item: $error')),
          );
        }
      }
    }
    name.dispose();
    hsn.dispose();
    unit.dispose();
    rate.dispose();
    gst.dispose();
  }

  void _selectInventoryItem(_InvoiceLineDraft line, int? itemId) {
    final item = inventoryItems.cast<Map<String, dynamic>?>().firstWhere(
          (candidate) => candidate!['id'] == itemId,
          orElse: () => null,
        );
    setState(() {
      line.inventoryItemId = itemId;
      if (item != null) {
        line.description.text = item['name'] as String;
        line.hsn.text = item['hsn'] as String? ?? '';
        line.rate.text = (item['default_rate'] as num).toStringAsFixed(2);
        line.gstRate.text = (item['gst_rate'] as num).toStringAsFixed(2);
      }
    });
  }

  void _addLine() => setState(() => lines.add(_InvoiceLineDraft()));

  void _removeLine(int index) {
    if (lines.length == 1) return;
    setState(() => lines.removeAt(index).dispose());
  }

  double _number(TextEditingController controller) =>
      double.tryParse(controller.text.replaceAll(',', '').trim()) ?? 0;

  double _taxable(_InvoiceLineDraft line) =>
      _number(line.quantity) * _number(line.rate);

  double _tax(_InvoiceLineDraft line) => _taxable(line) * _number(line.gstRate) / 100;

  double get taxableTotal => lines.fold(0, (sum, line) => sum + _taxable(line));
  double get taxTotal => lines.fold(0, (sum, line) => sum + _tax(line));
  double get grandTotal => taxableTotal + taxTotal;

  List<Map<String, dynamic>> _linePayload() => lines.map((line) {
        final taxable = _taxable(line);
        final tax = _tax(line);
        return <String, dynamic>{
          'inventory_item_id': withInventory ? line.inventoryItemId : null,
          'description': line.description.text.trim(),
          'hsn': line.hsn.text.trim(),
          'quantity': _number(line.quantity),
          'rate': _number(line.rate),
          'taxable_value': taxable,
          'gst_rate': _number(line.gstRate),
          'cgst': interstate ? 0.0 : tax / 2,
          'sgst': interstate ? 0.0 : tax / 2,
          'igst': interstate ? tax : 0.0,
        };
      }).toList();

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null) setState(() => date = selected);
  }

  Future<void> _save({bool exportPdf = false}) async {
    if (!formKey.currentState!.validate()) return;
    if (withInventory && lines.any((line) => line.inventoryItemId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an inventory item for every line')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      savedVoucherId = await StorageService.saveInvoiceVoucher(
        voucherId: savedVoucherId,
        type: widget.type,
        voucherNumber: number.text.trim(),
        voucherDate: DateFormat('yyyy-MM-dd').format(date),
        invoiceMode: withInventory ? 'inventory' : 'accounting',
        partyLedgerId: partyLedgerId!,
        accountLedgerId: accountLedgerId!,
        placeOfSupply: placeOfSupply.text.trim(),
        narration: narration.text.trim(),
        lines: _linePayload(),
      );
      if (exportPdf) await _exportPdf();
      if (mounted && !exportPdf) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save ${widget.type.toLowerCase()}: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _exportPdf() async {
    if (savedVoucherId == null) return;
    final invoice = await StorageService.getInvoiceVoucher(savedVoucherId!);
    final company = await StorageService.getSelectedCompany();
    if (invoice == null || company == null) return;
    final party = ledgers.firstWhere((ledger) => ledger['id'] == partyLedgerId);
    final file = await PdfService.generateTaxInvoicePdf(
      company: company,
      invoice: invoice,
      partyName: party['name'] as String,
    );
    await Share.shareXFiles([XFile(file.path)], subject: '${widget.type} ${number.text}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.voucherId == null ? 'New' : 'Edit'} ${widget.type}'),
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
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Without inventory')),
                      ButtonSegment(value: true, label: Text('With inventory')),
                    ],
                    selected: {withInventory},
                    onSelectionChanged: (value) => setState(() => withInventory = value.first),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: number,
                          decoration: const InputDecoration(
                            labelText: 'Voucher number',
                            border: OutlineInputBorder(),
                          ),
                          validator: _required,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          title: const Text('Date'),
                          subtitle: Text(DateFormat('dd/MM/yyyy').format(date)),
                          onTap: _pickDate,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ledgerDropdown(
                    isSales ? 'Customer ledger' : 'Supplier ledger',
                    partyLedgerId,
                    partyLedgers,
                    (value) => setState(() => partyLedgerId = value),
                  ),
                  const SizedBox(height: 12),
                  _ledgerDropdown(
                    isSales ? 'Sales ledger' : 'Purchase ledger',
                    accountLedgerId,
                    accountLedgers,
                    (value) => setState(() => accountLedgerId = value),
                  ),
                  if (accountLedgers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Create a ${isSales ? 'Sales Accounts' : 'Purchase Accounts'} ledger first.',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: placeOfSupply,
                    decoration: const InputDecoration(
                      labelText: 'Place of supply',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Interstate supply (IGST)'),
                    subtitle: Text(interstate ? 'IGST applies' : 'CGST + SGST apply'),
                    value: interstate,
                    onChanged: (value) => setState(() => interstate = value),
                  ),
                  if (withInventory)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _createInventoryItem,
                        icon: const Icon(Icons.add_box_outlined),
                        label: const Text('Create inventory item'),
                      ),
                    ),
                  ...List.generate(lines.length, (index) => _lineCard(index)),
                  TextButton.icon(
                    onPressed: _addLine,
                    icon: const Icon(Icons.add),
                    label: const Text('Add line'),
                  ),
                  const Divider(),
                  _totalRow('Taxable value', taxableTotal),
                  _totalRow(interstate ? 'IGST' : 'CGST', interstate ? taxTotal : taxTotal / 2),
                  if (!interstate) _totalRow('SGST', taxTotal / 2),
                  _totalRow('Invoice total', grandTotal, bold: true),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: narration,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Narration',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: saving || accountLedgers.isEmpty ? null : () => _save(),
                          icon: const Icon(Icons.save),
                          label: Text(saving ? 'Saving…' : 'Save'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: saving || accountLedgers.isEmpty
                              ? null
                              : () => _save(exportPdf: true),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Save & PDF'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _lineCard(int index) {
    final line = lines[index];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text('Line ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
                IconButton(onPressed: lines.length > 1 ? () => _removeLine(index) : null, icon: const Icon(Icons.delete_outline)),
              ],
            ),
            if (withInventory)
              DropdownButtonFormField<int>(
                value: line.inventoryItemId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Inventory item', border: OutlineInputBorder()),
                items: inventoryItems
                    .map((item) => DropdownMenuItem<int>(
                          value: item['id'] as int,
                          child: Text('${item['name']}  (${item['stock_qty']} ${item['unit']})'),
                        ))
                    .toList(),
                onChanged: (value) => _selectInventoryItem(line, value),
              ),
            if (withInventory) const SizedBox(height: 10),
            TextFormField(
              controller: line.description,
              decoration: InputDecoration(
                labelText: withInventory ? 'Description' : 'Particulars / service',
                border: const OutlineInputBorder(),
              ),
              validator: _required,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _numberField(line.hsn, 'HSN/SAC', required: false)),
                const SizedBox(width: 8),
                Expanded(child: _numberField(line.quantity, 'Quantity')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _numberField(line.rate, 'Rate ₹')),
                const SizedBox(width: 8),
                Expanded(child: _numberField(line.gstRate, 'GST %', allowZero: true)),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '₹${(_taxable(line) + _tax(line)).toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    bool required = true,
    bool allowZero = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      onChanged: (_) => setState(() {}),
      validator: required
          ? (value) {
              final parsed = double.tryParse((value ?? '').replaceAll(',', ''));
              if (parsed == null || (allowZero ? parsed < 0 : parsed <= 0)) {
                return 'Invalid';
              }
              return null;
            }
          : null,
    );
  }

  Widget _ledgerDropdown(
    String label,
    int? value,
    List<Map<String, dynamic>> options,
    ValueChanged<int?> onChanged,
  ) {
    final validValue = options.any((item) => item['id'] == value) ? value : null;
    return DropdownButtonFormField<int>(
      value: validValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: options
          .map((ledger) => DropdownMenuItem<int>(
                value: ledger['id'] as int,
                child: Text(ledger['name'] as String),
              ))
          .toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'Required' : null,
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 17 : 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text('₹${value.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
}

class _InvoiceLineDraft {
  _InvoiceLineDraft({
    this.inventoryItemId,
    String description = '',
    String hsn = '',
    String quantity = '1',
    String rate = '',
    String gstRate = '18',
  })  : description = TextEditingController(text: description),
        hsn = TextEditingController(text: hsn),
        quantity = TextEditingController(text: quantity),
        rate = TextEditingController(text: rate),
        gstRate = TextEditingController(text: gstRate);

  factory _InvoiceLineDraft.fromMap(Map<String, dynamic> map) => _InvoiceLineDraft(
        inventoryItemId: map['inventory_item_id'] as int?,
        description: map['description'] as String? ?? '',
        hsn: map['hsn'] as String? ?? '',
        quantity: (map['quantity'] as num).toString(),
        rate: (map['rate'] as num).toStringAsFixed(2),
        gstRate: (map['gst_rate'] as num).toString(),
      );

  int? inventoryItemId;
  final TextEditingController description;
  final TextEditingController hsn;
  final TextEditingController quantity;
  final TextEditingController rate;
  final TextEditingController gstRate;

  void dispose() {
    description.dispose();
    hsn.dispose();
    quantity.dispose();
    rate.dispose();
    gstRate.dispose();
  }
}
