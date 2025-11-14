import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:intl/intl.dart';

class CompanySettings extends StatefulWidget {
  final int companyId;
  final String companyName;

  const CompanySettings({
    Key? key,
    required this.companyId,
    required this.companyName,
  }) : super(key: key);

  @override
  State<CompanySettings> createState() => _CompanySettingsState();
}

class _CompanySettingsState extends State<CompanySettings> {
  bool isLoading = true;
  Map<String, dynamic> companySettings = {};
  String voucherNumberingMethod = 'automatic'; // Default value

  // Period settings
  String defaultPeriodType = 'current_fy'; // 'current_fy' or 'custom'
  DateTime? customPeriodStart;
  DateTime? customPeriodEnd;

  @override
  void initState() {
    super.initState();
    _loadCompanySettings();
  }

  Future<void> _loadCompanySettings() async {
    try {
      // Load company settings from the database
      final settings = await StorageService.getCompanySettings(widget.companyId);

      setState(() {
        companySettings = settings ?? {};
        // Set the voucher numbering method from settings or use default
        voucherNumberingMethod = companySettings['voucher_numbering_method'] ?? 'automatic';

        // Load period settings
        defaultPeriodType = companySettings['default_period_type'] ?? 'current_fy';
        if (companySettings['default_period_start'] != null) {
          try {
            customPeriodStart = DateTime.parse(companySettings['default_period_start']);
          } catch (e) {
            debugPrint('Error parsing period start: $e');
          }
        }
        if (companySettings['default_period_end'] != null) {
          try {
            customPeriodEnd = DateTime.parse(companySettings['default_period_end']);
          } catch (e) {
            debugPrint('Error parsing period end: $e');
          }
        }

        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading company settings: $e')),
        );
      }
    }
  }

  Future<void> _saveCompanySettings() async {
    // Validate custom period if selected
    if (defaultPeriodType == 'custom') {
      if (customPeriodStart == null || customPeriodEnd == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select both start and end dates for custom period'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (customPeriodStart!.isAfter(customPeriodEnd!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Start date must be before end date'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Update the settings map with current values
      companySettings['voucher_numbering_method'] = voucherNumberingMethod;
      companySettings['default_period_type'] = defaultPeriodType;

      if (defaultPeriodType == 'custom' && customPeriodStart != null && customPeriodEnd != null) {
        companySettings['default_period_start'] = '${customPeriodStart!.year}-${customPeriodStart!.month.toString().padLeft(2, '0')}-${customPeriodStart!.day.toString().padLeft(2, '0')}';
        companySettings['default_period_end'] = '${customPeriodEnd!.year}-${customPeriodEnd!.month.toString().padLeft(2, '0')}-${customPeriodEnd!.day.toString().padLeft(2, '0')}';
      }

      // Save to database
      await StorageService.saveCompanySettings(widget.companyId, companySettings);

      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    }
  }

  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (customPeriodStart ?? DateTime.now())
          : (customPeriodEnd ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2C5545),
              onPrimary: Colors.white,
              onSurface: Color(0xFF2C5545),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          customPeriodStart = picked;
        } else {
          customPeriodEnd = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not set';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _getCurrentFYText() {
    final now = DateTime.now();
    final year = now.month >= 4 ? now.year : now.year - 1;
    return '01/04/$year to 31/03/${year + 1}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF5F0),
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2C5545),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(15),
                      bottomRight: Radius.circular(15),
                    ),
                  ),
                  child: Text(
                    'Settings for ${widget.companyName}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'Voucher Numbering Method',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C5545),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildVoucherNumberingOption(
                          title: 'Automatic',
                          subtitle: 'Voucher numbers are automatically generated',
                          value: 'automatic',
                        ),
                        _buildVoucherNumberingOption(
                          title: 'Automatic with Manual Override',
                          subtitle: 'Voucher numbers are automatically generated but can be manually changed',
                          value: 'automatic_with_override',
                        ),
                        _buildVoucherNumberingOption(
                          title: 'Manual',
                          subtitle: 'Voucher numbers are entered manually by the user',
                          value: 'manual',
                        ),
                        const SizedBox(height: 32),
                        const Divider(thickness: 2, color: Color(0xFF2C5545)),
                        const SizedBox(height: 16),
                        const Text(
                          'Default Period Preference',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C5545),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildPeriodOption(
                          title: 'Current Financial Year',
                          subtitle: 'Automatically use the current FY (${_getCurrentFYText()})',
                          value: 'current_fy',
                        ),
                        _buildPeriodOption(
                          title: 'Custom Period',
                          subtitle: 'Set a custom date range as default',
                          value: 'custom',
                        ),
                        if (defaultPeriodType == 'custom') ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF2C5545)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Custom Period Range',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2C5545),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Start Date',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          InkWell(
                                            onTap: () => _selectDate(true),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 12,
                                              ),
                                              decoration: BoxDecoration(
                                                border: Border.all(color: Colors.grey),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    _formatDate(customPeriodStart),
                                                    style: const TextStyle(fontSize: 14),
                                                  ),
                                                  const Icon(Icons.calendar_today, size: 16),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'End Date',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          InkWell(
                                            onTap: () => _selectDate(false),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 12,
                                              ),
                                              decoration: BoxDecoration(
                                                border: Border.all(color: Colors.grey),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    _formatDate(customPeriodEnd),
                                                    style: const TextStyle(fontSize: 14),
                                                  ),
                                                  const Icon(Icons.calendar_today, size: 16),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _saveCompanySettings,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2C5545),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Save Settings',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildVoucherNumberingOption({
    required String title,
    required String subtitle,
    required String value,
  }) {
    return RadioListTile<String>(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.grey,
        ),
      ),
      value: value,
      groupValue: voucherNumberingMethod,
      activeColor: const Color(0xFF2C5545),
      onChanged: (newValue) {
        setState(() {
          voucherNumberingMethod = newValue!;
        });
      },
    );
  }

  Widget _buildPeriodOption({
    required String title,
    required String subtitle,
    required String value,
  }) {
    return RadioListTile<String>(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.grey,
        ),
      ),
      value: value,
      groupValue: defaultPeriodType,
      activeColor: const Color(0xFF2C5545),
      onChanged: (newValue) {
        setState(() {
          defaultPeriodType = newValue!;
        });
      },
    );
  }
}
