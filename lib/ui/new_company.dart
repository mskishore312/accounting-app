import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/ui/options.dart';

class NewCompany extends StatefulWidget {
  const NewCompany({Key? key}) : super(key: key);

  @override
  State<NewCompany> createState() => _NewCompanyState();
}

class _NewCompanyState extends State<NewCompany> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _tinController = TextEditingController();

  bool _useSecurity = false;
  String? _selectedState = 'Andaman and Nicobar (AN)';
  DateTime _financialYearFrom = DateTime.now();
  DateTime _booksFrom = DateTime.now();

  final List<String> _states = [
    'Andaman and Nicobar (AN)',
    'Andhra Pradesh (AP)',
    'Arunachal Pradesh (AR)',
    'Assam (AS)',
    'Bihar (BR)',
    'Chandigarh (CH)',
    'Chhattisgarh (CG)',
    'Dadra and Nagar Haveli (DN)',
    'Daman and Diu (DD)',
    'Delhi (DL)',
    'Goa (GA)',
    'Gujarat (GJ)',
    'Haryana (HR)',
    'Himachal Pradesh (HP)',
    'Jammu and Kashmir (JK)',
    'Jharkhand (JH)',
    'Karnataka (KA)',
    'Kerala (KL)',
    'Ladakh (LA)',
    'Lakshadweep (LD)',
    'Madhya Pradesh (MP)',
    'Maharashtra (MH)',
    'Manipur (MN)',
    'Meghalaya (ML)',
    'Mizoram (MZ)',
    'Nagaland (NL)',
    'Odisha (OD)',
    'Puducherry (PY)',
    'Punjab (PB)',
    'Rajasthan (RJ)',
    'Sikkim (SK)',
    'Tamil Nadu (TN)',
    'Telangana (TS)',
    'Tripura (TR)',
    'Uttar Pradesh (UP)',
    'Uttarakhand (UK)',
    'West Bengal (WB)',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _tinController.dispose();
    super.dispose();
  }

  Future<void> _saveCompany() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final company = {
        'name': _nameController.text,
        'country': 'India',
        'state': _selectedState,
        'address': _addressController.text,
        'contact': _contactController.text,
        'tin': _tinController.text,
        'security': _useSecurity ? 1 : 0,
        'financial_year_from': _financialYearFrom.toIso8601String(),
        'books_from': _booksFrom.toIso8601String(),
      };

      final companyId = await StorageService.saveCompany(company);
      await StorageService.selectCompany(companyId);
      await _createDefaultLedgers(companyId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company created successfully')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Options()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating company: $e')),
        );
      }
    }
  }

  Future<void> _createDefaultLedgers(int companyId) async {
    // Create default account masters
    final cashMaster = {
      'company_id': companyId,
      'name': 'Cash & Bank',
      'classification': 'Assets',
    };
    final cashMasterId = await StorageService.insertAccountMaster(cashMaster);

    // Create only Cash account as default ledger
    await StorageService.insertLedger({
      'company_id': companyId,
      'account_master_id': cashMasterId,
      'name': 'Cash',
      'classification': 'Cash-in-hand',
      'balance': 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD6F0E0),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C5545),
        title: Row(
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
              'TOM-PA (V 4.5, R 73)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFF2C5545),
                  width: 1,
                ),
              ),
            ),
            child: const Text(
              'New Company',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C5545),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Padding(
                  padding: const EdgeInsets.all(0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFormField(
                        label: 'Company Name :',
                        child: TextFormField(
                          controller: _nameController,
                          decoration: _buildInputDecoration('Your Company Name'),
                          validator: (value) =>
                              value?.isEmpty == true ? 'Company name is required' : null,
                        ),
                      ),
                      _buildFormField(
                        label: 'Company Address:',
                        child: TextFormField(
                          controller: _addressController,
                          decoration: _buildInputDecoration('Company Address'),
                          maxLines: 3,
                        ),
                      ),
                      _buildFormField(
                        label: 'Contact No :',
                        child: TextFormField(
                          controller: _contactController,
                          decoration: _buildInputDecoration('8072197432'),
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                      _buildFormField(
                        label: 'TIN/GST :',
                        child: TextFormField(
                          controller: _tinController,
                          decoration: _buildInputDecoration('TIN/GST No.'),
                        ),
                      ),
                      _buildFormField(
                        label: 'State :',
                        child: DropdownButtonFormField<String>(
                          value: _selectedState,
                          decoration: _buildInputDecoration(''),
                          items: _states
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (value) {
                            setState(() => _selectedState = value);
                          },
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ),
                      ),
                      _buildFormField(
                        label: 'Security:',
                        child: Row(
                          children: [
                            Checkbox(
                              value: _useSecurity,
                              onChanged: (value) {
                                setState(() {
                                  _useSecurity = value ?? false;
                                });
                              },
                              activeColor: const Color(0xFF2C5545),
                            ),
                            const Text(
                              'Yes',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF2C5545),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildFormField(
                        label: 'Fin. Year From:',
                        child: TextFormField(
                          readOnly: true,
                          decoration: _buildInputDecoration(''),
                          controller: TextEditingController(
                            text: _financialYearFrom.toIso8601String().split('T')[0],
                          ),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _financialYearFrom,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (date != null) {
                              setState(() {
                                _financialYearFrom = date;
                                // Reset books from date if it's outside the new financial year
                                final financialYearEnd = DateTime(
                                  date.year + 1, 
                                  date.month, 
                                  date.day
                                ).subtract(const Duration(days: 1));
                                
                                if (_booksFrom.isBefore(date) || _booksFrom.isAfter(financialYearEnd)) {
                                  _booksFrom = date;
                                }
                              });
                            }
                          },
                        ),
                      ),
                      _buildFormField(
                        label: 'Books beginning From:',
                        child: TextFormField(
                          readOnly: true,
                          decoration: _buildInputDecoration(''),
                          controller: TextEditingController(
                            text: _booksFrom.toIso8601String().split('T')[0],
                          ),
                          onTap: () async {
                            // Calculate financial year end date
                            final financialYearEnd = DateTime(
                              _financialYearFrom.year + 1, 
                              _financialYearFrom.month, 
                              _financialYearFrom.day
                            ).subtract(const Duration(days: 1));
                            
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _booksFrom.isAfter(financialYearEnd) 
                                  ? _financialYearFrom 
                                  : (_booksFrom.isBefore(_financialYearFrom) 
                                      ? _financialYearFrom 
                                      : _booksFrom),
                              firstDate: _financialYearFrom,
                              lastDate: financialYearEnd,
                              helpText: 'Books beginning date must be within the financial year',
                            );
                            if (date != null) {
                              setState(() => _booksFrom = date);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ElevatedButton(
                          onPressed: _saveCompany,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4C7380),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Text(
                            'Save',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({required String label, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFD6F0E0),
        border: Border(
          bottom: BorderSide(
            color: Colors.transparent,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF2C5545),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFF2C5545), width: 1),
      ),
    );
  }
}
