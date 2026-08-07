import 'dart:io';
import 'dart:typed_data';

import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/services/bank_statement_service.dart';
import 'package:accounting_app/ui/ledger_creation.dart';
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

  Future<void> _pickStatement() async {
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
          'No transactions were detected. Try a clearer image or a statement showing date, narration, amount and balance.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showMessage('Unable to read the statement: $error');
    }
  }

  Future<void> _createLedger() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LedgerCreation()),
    );
    if (created == true) {
      await _loadLedgers();
      if (mounted) _showMessage('Ledger created. You can select it now.');
    }
  }

  Future<void> _chooseCounterpartLedger(
    BankStatementTransaction transaction,
  ) async {
    final controller = TextEditingController();
    var filtered = List<Map<String, dynamic>>.from(counterpartLedgers);
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
            ),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.7,
              child: Column(
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Search counterparty ledger',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (query) => setSheetState(() {
                      final value = query.trim().toLowerCase();
                      filtered = counterpartLedgers.where((ledger) {
                        final name = (ledger['name'] as String).toLowerCase();
                        final group =
                            (ledger['classification'] as String? ?? '')
                                .toLowerCase();
                        return name.contains(value) || group.contains(value);
                      }).toList();
                    }),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _createLedger();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create a new ledger'),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No matching ledgers'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, index) {
                              final ledger = filtered[index];
                              return ListTile(
                                title: Text(ledger['name'] as String),
                                subtitle: Text(
                                  ledger['classification'] as String? ?? '',
                                ),
                                onTap: () => Navigator.pop(
                                  sheetContext,
                                  ledger['id'] as int,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    controller.dispose();
    if (selected != null && mounted) {
      setState(() {
        transaction.suggestedLedgerId = selected;
        transaction.suggestionLabel = 'Selected manually';
      });
    }
  }

  String _ledgerName(int? id) {
    if (id == null) return 'Choose counterparty ledger';
    for (final ledger in ledgers) {
      if (ledger['id'] == id) return ledger['name'] as String;
    }
    return 'Choose counterparty ledger';
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
    if (selected.any(
      (item) => item.amountError != null || item.amount <= 0,
    )) {
      _showMessage('Correct every invalid amount before posting');
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
                        isExpanded: true,
                        value: bankLedgerId,
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
                        onPressed: bankLedgerId == null ? null : _pickStatement,
                        icon: const Icon(Icons.document_scanner),
                        label: Text(
                          fileName == null
                              ? 'Import Statement PDF'
                              : 'Import Another Statement',
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
                              'Select the bank ledger, then import a statement PDF. '
                              'Review every suggestion before posting.\n\n'
                              'For a photo or scan of a statement, use the AI '
                              'assistant button instead — it reads images.',
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
                                        SizedBox(
                                          width: 135,
                                          child: TextFormField(
                                            key: ValueKey(item),
                                            initialValue:
                                                item.amount.toStringAsFixed(2),
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                              decimal: true,
                                            ),
                                            textAlign: TextAlign.end,
                                            decoration: InputDecoration(
                                              labelText: 'Amount',
                                              prefixText: '₹ ',
                                              errorText: item.amountError,
                                              isDense: true,
                                              border:
                                                  const OutlineInputBorder(),
                                            ),
                                            onChanged: (value) {
                                              final parsed = double.tryParse(
                                                value
                                                    .replaceAll(',', '')
                                                    .trim(),
                                              );
                                              setState(() {
                                                if (parsed == null ||
                                                    parsed <= 0) {
                                                  item.amountError =
                                                      'Invalid amount';
                                                } else {
                                                  item.amount = parsed;
                                                  item.amountError = null;
                                                }
                                              });
                                            },
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
                                      isExpanded: true,
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
                                    InkWell(
                                      onTap: () =>
                                          _chooseCounterpartLedger(item),
                                      child: InputDecorator(
                                        decoration: InputDecoration(
                                          labelText: 'Counterparty ledger',
                                          helperText: item.suggestionLabel,
                                          border: const OutlineInputBorder(),
                                          suffixIcon:
                                              const Icon(Icons.arrow_drop_down),
                                        ),
                                        child: Text(
                                          _ledgerName(item.suggestedLedgerId),
                                          overflow: TextOverflow.ellipsis,
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
