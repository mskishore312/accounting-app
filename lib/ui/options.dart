import 'package:flutter/material.dart';
import 'package:accounting_app/ui/vouchers.dart';
import 'package:accounting_app/ui/reports.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/ui/master_options.dart';
import 'package:accounting_app/ui/gateway.dart';
import 'package:provider/provider.dart';
import 'package:accounting_app/services/period_service.dart';
import 'package:accounting_app/ui/widgets/date_range_selector.dart';

class Options extends StatefulWidget {
  const Options({Key? key}) : super(key: key);

  @override
  State<Options> createState() => _OptionsState();
}

class _OptionsState extends State<Options> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadCompanyDefaultPeriod();
  }

  Future<void> _loadCompanyDefaultPeriod() async {
    if (_isInitialized) return;

    try {
      final company = await StorageService.getSelectedCompany();
      if (company != null && company['id'] != null) {
        final periodService = Provider.of<PeriodService>(context, listen: false);
        await periodService.loadCompanyDefaultPeriod(company['id'] as int);
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading company default period: $e');
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2E9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C5545),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const Gateway()),
            );
          },
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
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
              'TOM-PA 9.0 (R 7.9)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: StorageService.getSelectedCompany(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final company = snapshot.data;
          if (company == null) {
            return const Center(child: Text('No company selected'));
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF2C5545),
                  border: Border(
                    bottom: BorderSide(
                      color: Color(0xFF2C5545),
                      width: 1,
                    ),
                  ),
                ),
                child: Text(
                  company['name'] as String? ?? 'Unknown Company',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF2C5545),
                  border: Border(
                    bottom: BorderSide(
                      color: Color(0xFF2C5545),
                      width: 1,
                    ),
                  ),
                ),
                child: const Text(
                  'Options',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildButton(
                        'Create Accounts',
                        onPressed: () {
                          try {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MasterOptions(),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error accessing Masters: $e')),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildButton(
                        'Record Transactions',
                        onPressed: () {
                          try {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const Vouchers(),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error accessing Vouchers: $e')),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildButton(
                        'Reports',
                        onPressed: () {
                          try {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const Reports(),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error accessing Reports: $e')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Consumer<PeriodService>(
                builder: (context, periodService, child) {
                  return GestureDetector(
                    onTap: () {
                      _showPeriodSelector(context, periodService);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      color: Colors.transparent,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Curr. Period ${periodService.periodText}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.grey[700],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showPeriodSelector(BuildContext context, PeriodService periodService) async {
    final size = MediaQuery.of(context).size;

    // Get the book's beginning date
    DateTime? minSelectableDate;
    final company = await StorageService.getSelectedCompany();
    if (company != null && company['books_from'] != null) {
      try {
        final dateStr = company['books_from'] as String;
        minSelectableDate = dateStr.contains('-')
            ? DateTime.parse(dateStr.split('T')[0])
            : DateTime.parse(dateStr);
      } catch (e) {
        debugPrint('Error parsing books_from date: ${company['books_from']}');
      }
    }
    minSelectableDate ??= DateTime(DateTime.now().year - 20, 1, 1);

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          insetPadding: EdgeInsets.symmetric(
            horizontal: size.width * 0.08,
            vertical: size.height * 0.1,
          ),
          child: SizedBox(
            height: size.height * 0.6,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Select Date Range',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: DateRangeSelector(
                    initialStartDate: periodService.startDate,
                    initialEndDate: periodService.endDate,
                    minSelectableDate: minSelectableDate,
                    onDateRangeSelected: (start, end) {
                      periodService.setPeriod(start, end, setAsSessionDefault: true);
                      Navigator.of(context).pop(); // Close the dialog
                    },
                    onCancel: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildButton(String text, {required VoidCallback onPressed}) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFF4C7380),
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
