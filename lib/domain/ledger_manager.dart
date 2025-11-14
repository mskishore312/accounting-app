import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';

class LedgerManager extends StatefulWidget {
  final Map<String, dynamic>? existingLedger;
  final String companyName;

  const LedgerManager({
    Key? key,
    this.existingLedger,
    required this.companyName,
  }) : super(key: key);

  @override
  _LedgerManagerState createState() => _LedgerManagerState();
}

class _LedgerManagerState extends State<LedgerManager> {
  late TextEditingController _nameController;
  late TextEditingController _balanceController;
  late TextEditingController _tinGstController;
  late TextEditingController _searchController;
  late String _underGroup;
  late String _type;
  bool _isSearching = false;
  List<String> _filteredGroups = [];
  bool _isSaving = false;

  final List<String> _underGroupOptions = [
    'Bank Accounts', 'Bank OD A/c', 'Branch / Division', 'Capital Account',
    'Cash-in-hand', 'Current Assets', 'Current Liabilities', 'Deposits (Assets)',
    'Direct Expenses', 'Direct Incomes', 'Duties & Taxes', 'Fixed Assets',
    'Indirect Expenses', 'Indirect Income', 'Investments', 'Loans & Advances (Asset)',
    'Loans (Liability)', 'Misc. Expenses (ASSET)', 'Provisions', 'Purchase Accounts',
    'Reserves & Surplus', 'Sales Accounts', 'Secured Loans', 'Stock-in-hand',
    'Sundry Creditors', 'Sundry Debtors', 'Suspense A/c', 'Unsecured Loans'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingLedger?['name'] ?? '');
    _balanceController = TextEditingController(text: widget.existingLedger?['balance'] ?? '');
    _tinGstController = TextEditingController(text: widget.existingLedger?['tinGst'] ?? '');
    _searchController = TextEditingController();
    _underGroup = widget.existingLedger?['underGroup'] ?? '';
    _type = widget.existingLedger?['type'] ?? 'Dr.';
    _filteredGroups = List.from(_underGroupOptions);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _tinGstController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterGroups(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredGroups = List.from(_underGroupOptions);
      } else {
        _filteredGroups = _underGroupOptions
            .where((group) => group.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Widget _buildUnderGroupField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Under Group*', style: TextStyle(fontSize: 16, color: Colors.black)),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchController.clear();
                      _filteredGroups = List.from(_underGroupOptions);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: _isSearching
                      ? TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search groups...',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onChanged: _filterGroups,
                        )
                      : Text(_underGroup.isEmpty ? 'Select under group' : _underGroup,
                          style: const TextStyle(color: Colors.black87)),
                ),
              ),
              if (_isSearching)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredGroups.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        dense: true,
                        title: Text(_filteredGroups[index]),
                        onTap: () {
                          setState(() {
                            _underGroup = _filteredGroups[index];
                            _isSearching = false;
                            _searchController.clear();
                            _filteredGroups = List.from(_underGroupOptions);
                          });
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2E9),
      appBar: AppBar(
        title: Text(widget.existingLedger == null ? 'Create Ledger' : 'Edit Ledger'),
        backgroundColor: const Color(0xFF4C7380),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Company: ${widget.companyName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Ledger Name*',
                    hintText: 'Enter ledger name',
                  ),
                  controller: _nameController,
                ),
                const SizedBox(height: 16),
                _buildUnderGroupField(),
                const SizedBox(height: 16),
                const Text('Amount :', style: TextStyle(fontSize: 16, color: Colors.black)),
                TextField(
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    hintText: 'Enter amount (optional)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  controller: _balanceController,
                ),
                const SizedBox(height: 16),
                const Text('Type :', style: TextStyle(fontSize: 16, color: Colors.black)),
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  ),
                  items: ['Dr.', 'Cr.'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _type = newValue!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Tin/GST No',
                    hintText: 'Enter Tin/GST No (optional)',
                  ),
                  controller: _tinGstController,
                ),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveLedger,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4C7380),
                      foregroundColor: Colors.white,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
          if (_isSaving)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x80FFFFFF),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _saveLedger() async {
    if (_nameController.text.isEmpty || _underGroup.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields (Ledger Name and Under Group)'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Get current company data with type safety
      final selectedCompany = await StorageService.getSelectedCompany();
      if (selectedCompany == null) {
        throw Exception('No company selected');
      }
      
      final companyId = selectedCompany['id'];
      if (companyId == null || (companyId is! int && companyId is! String)) {
        throw Exception('Invalid company ID');
      }
      
      // Convert company ID to int if it's a string
      final int normalizedCompanyId = companyId is String ? int.parse(companyId) : companyId;

      // Format balance to always have two decimal places if not empty
      String formattedBalance = '';
      if (_balanceController.text.isNotEmpty) {
        final balanceValue = double.tryParse(_balanceController.text);
        if (balanceValue == null) {
          throw Exception('Invalid balance amount');
        }
        formattedBalance = balanceValue.toStringAsFixed(2);
      }

      final ledgerData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'underGroup': _underGroup,
        'balance': formattedBalance,
        'type': _type,
        'tinGst': _tinGstController.text.trim(),
        'companyId': normalizedCompanyId,
        'isDefault': widget.existingLedger?['isDefault'] ?? false,
      };

      // Save ledger
      final result = await StorageService.saveLedger(ledgerData);

      if (result <= 0) {
        throw Exception('Failed to save ledger');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ledger saved successfully')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
