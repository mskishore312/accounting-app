import 'dart:io';
import 'dart:typed_data';

import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/services/bank_statement_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BankStatementImport extends StatefulWidget {
  const BankStatementImport({super.key});

  @override
  State<BankStatementImport> createState() => _BankStatementImportState();
}

class _BankStatementImportState extends State<BankStatementImport> {
  List<Map<String, dynamic>> ledgers = [];
  List<BankStatementTransaction> transactions = [];
  int? bankLedgerId;
  String? fileName;
  bool isLoading = true;
  bool isPosting = false;

  List<Map<String, dynamic>> get bankLedgers => ledgers.where((ledger) {
        final classification = ledger['classification'] as String? ?? '';
        return const ['Bank Accounts', 'Bank OD A/c', 'Cash-in-hand']
            .contains(classification);
      }).toList();

  List<Map<String, dynamic>> get counterpartLedgers =>
      ledgers.where((ledger) => ledger['id'] != bankLedgerId).toList();

  @override
  void initState() {
    super.initState();
    _loadLedgers();
  }

  Future<void> _loadLedgers() async {
    try {
      final loaded = await StorageService.getLedgers();
      if (!mounted) return;
      setState(() {
        ledgers = loaded;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showMessage('Unable to load ledgers: $error');
    }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );
      if (result == null) return;

      setState(() => isLoading = true);
      final selectedFile = result.files.single;
      Uint8List? bytes = selectedFile.bytes;
      if (bytes == null && selectedFile.path != null) {
        bytes = await File(selectedFile.path!).readAsBytes();
      }
      if (bytes == null) throw Exception('Could not read the selected PDF');

      final extracted = BankStatementService.extractTransactions(bytes);
      BankStatementService.suggestLedgers(
        extracted,
        ledgers,
        bankLedgerId: bankLedgerId,
      );
      if (!mounted) return;
      setState(() {
        fileName = selectedFile.name;
        transactions = extracted;
        isLoading = false;
      });
      if (extracted.isEmpty) {
        _showMessage(
          'No transactions were detected. The PDF may be scanned or use an unsupported layout.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showMessage('Unable to read bank statement: $error');
    }
  }

  void _setBankLedger(int? value) {
    setState(() {
      bankLedgerId = value;
      for (final transaction in transactions) {
        if (transaction.suggestedLedgerId == value) {
          transaction.suggestedLedgerId = null;
        }
      }
      BankStatementService.suggestLedgers(
        transactions,
        ledgers,
        bankLedgerId: value,
      );
    });
  }

  Future<void> _postTransactions() async {
    final selected = transactions.where((item) => item.selected).toList();
    if (bankLedgerId == null) {
      _showMessage('Select the bank ledger first');
      return;
    }
    if (selected.isEmpty) {
      _showMessage('Select at least one transaction');
      return;
    }
    if (selected.any((item) => item.suggestedLedgerId == null)) {
      _showMessage('Choose a ledger for every selected transaction');
      return;
    }

    setState(() => isPosting = true);
    try {
      final imported = await StorageService.importBankStatementTransactions(
        bankLedgerId: bankLedgerId!,
        transactions: selected
            .map(
              (item) => {
                'voucher_date': DateFormat('yyyy-MM-dd').format(item.date),
                'description': item.description,
                'amount': item.amount,
                'is_deposit':
                    item.direction == BankTransactionDirection.deposit,
                'counterpart_ledger_id': item.suggestedLedgerId,
              },
            )
            .toList(),
      );
      if (!mounted) return;
      setState(() {
        transactions.removeWhere(selected.contains);
        isPosting = false;
      });
      _showMessage('$imported bank transactions posted successfully');
    } catch (error) {
      if (!mounted) return;
      setState(() => isPosting = false);
      _showMessage('Import failed; no partial entries were saved: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2E9),
      appBar: AppBar(
        title: const Text(
          'AI Bank Statement',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2C5545),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<int>(
                        value: bankLedgerId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Bank ledger',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: bankLedgers
                            .map(
                              (ledger) => DropdownMenuItem<int>(
                                value: ledger['id'] as int,
                                child: Text(
                                  ledger['name'] as String,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _setBankLedger,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _pickPdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: Text(
                          fileName == null
                              ? 'Import Bank Statement PDF'
                              : 'Import Another PDF',
                        ),
                      ),
                      if (fileName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '$fileName • ${transactions.length} transactions detected',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF2C5545)),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: transactions.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Select the bank ledger, then import a text-based PDF statement. Suggestions must be reviewed before posting.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF2C5545)),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: transactions.length,
                          itemBuilder: (context, index) {
                            final item = transactions[index];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: item.selected,
                                          onChanged: (value) => setState(
                                            () => item.selected = value ?? false,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            DateFormat('dd/MM/yyyy')
                                                .format(item.date),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '₹${item.amount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      item.description,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<
                                        BankTransactionDirection>(
                                      value: item.direction,
                                      decoration: const InputDecoration(
                                        labelText: 'Bank movement',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value:
                                              BankTransactionDirection.deposit,
                                          child: Text('Money received'),
                                        ),
                                        DropdownMenuItem(
                                          value: BankTransactionDirection
                                              .withdrawal,
                                          child: Text('Money paid'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setState(() => item.direction = value);
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<int>(
                                      value: item.suggestedLedgerId,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: 'Counterpart ledger',
                                        helperText: item.suggestionLabel,
                                        border: const OutlineInputBorder(),
                                      ),
                                      items: counterpartLedgers
                                          .map(
                                            (ledger) => DropdownMenuItem<int>(
                                              value: ledger['id'] as int,
                                              child: Text(
                                                ledger['name'] as String,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) => setState(
                                        () => item.suggestedLedgerId = value,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (transactions.isNotEmpty)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: isPosting ? null : _postTransactions,
                          icon: isPosting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.post_add),
                          label: const Text('Post Selected Transactions'),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
