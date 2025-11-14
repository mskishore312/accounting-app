import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/ui/daybook.dart';
import 'package:accounting_app/ui/ledger_list.dart';
import 'package:accounting_app/final_reports.dart';
import 'package:accounting_app/trial_balance.dart';
import 'package:accounting_app/services/period_service.dart'; // Added
import 'package:accounting_app/ui/widgets/date_range_selector.dart'; // Added
import 'package:provider/provider.dart'; // Added

class Reports extends StatefulWidget { // Changed to StatefulWidget
  const Reports({Key? key}) : super(key: key);

  @override
  State<Reports> createState() => _ReportsState(); // Added
}

class _ReportsState extends State<Reports> { // Added State class
  late PeriodService _periodService;
  DateTime? _booksStartingFromDate; // To be fetched, placeholder for now

  @override
  void initState() {
    super.initState();
    _periodService = Provider.of<PeriodService>(context, listen: false);
    if (_periodService.startDate == null || _periodService.endDate == null) {
      _periodService.initializeDefaultPeriod();
    }
    _fetchBooksStartingDate();
  }

  Future<void> _fetchBooksStartingDate() async {
    final company = await StorageService.getSelectedCompany();
    if (company != null && company['books_from'] != null) {
      String? booksFromStr = company['books_from'] as String?;
      DateTime? parsedDate;
      if (booksFromStr != null && booksFromStr.isNotEmpty) {
        try {
          final parts = booksFromStr.split('/');
          if (parts.length == 3) {
            final day = int.tryParse(parts[0]);
            final month = int.tryParse(parts[1]);
            final year = int.tryParse(parts[2]);
            if (day != null && month != null && year != null) {
              // Basic validation for date components
              if (year > 0 && month >= 1 && month <= 12 && day >= 1 && day <= DateTime(year, month + 1, 0).day) {
                parsedDate = DateTime(year, month, day);
              } else {
                print("Invalid date components in books_from: $booksFromStr");
              }
            }
          } else {
            print("Invalid date format (DD/MM/YYYY expected) for books_from: $booksFromStr");
          }
        } catch (e) {
          print("Error parsing books_from date in Reports: $booksFromStr. Error: $e");
        }
      }

      setState(() {
        _booksStartingFromDate = parsedDate ?? DateTime(DateTime.now().year - 20, 1, 1); // Use existing fallback
      });
    } else {
       setState(() {
        _booksStartingFromDate = DateTime(DateTime.now().year - 20, 1, 1); // Fallback if no company or books_from date
       });
    }
  }

  Future<void> _showDateRangePicker(BuildContext context) async {
    // Ensure _booksStartingFromDate is initialized, if not, use a fallback.
    // This might happen if initState/fetchBooksStartingDate hasn't completed or failed.
    final minDateForPicker = _booksStartingFromDate ?? DateTime(DateTime.now().year - 20, 1, 1);

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          child: DateRangeSelector(
            initialStartDate: _periodService.startDate,
            initialEndDate: _periodService.endDate,
            minSelectableDate: minDateForPicker, // Use fetched or fallback books_from date
            showResetButton: true,
            onDateRangeSelected: (start, end) {
              _periodService.setPeriod(start, end);
            },
            onCancel: () {
              // Optional: handle cancel if needed
            },
            onResetToDefault: () {
              _periodService.resetToSessionDefault();
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Period reset to session default'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildButton(String text, {required VoidCallback onPressed}) {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 16),
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

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to PeriodService changes for UI updates if needed, though AppBar might not auto-update
    // without specific Provider.of(context) in its direct build path or if it's not rebuilt.
    // For simplicity, direct usage of _periodService instance is fine for dialog invocation.
    // If AppBar title needed to reflect period, it would need more careful Provider integration.
    _periodService = Provider.of<PeriodService>(context, listen: false); // To ensure it's available

    return Scaffold(
      backgroundColor: const Color(0xFFE0F2E9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C5545),
        title: FutureBuilder<Map<String, dynamic>?>(
          future: StorageService.getSelectedCompany(),
          builder: (context, snapshot) {
            final company = snapshot.data;
            return Text(
              company?['name'] as String? ?? 'Unknown Company',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          },
        ),
        leading: IconButton( // Changed from menu to back arrow, assuming standard navigation
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [ // Added actions for the calendar icon
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            tooltip: 'Select Period',
            onPressed: () {
              _showDateRangePicker(context);
            },
          ),
        ],
      ),
      body: Column(
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
            child: const Text(
              'Reports',
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
                    'Day Book',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const Daybook(),
                      ),
                    ),
                  ),
                  _buildButton(
                    'Ledger',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LedgerList(),
                      ),
                    ),
                  ),
                  _buildButton(
                    'Cash/Bank Book',
                    onPressed: () => _showComingSoon(context, 'Cash/Bank Book'),
                  ),
                  _buildButton(
                    'Group Summary',
                    onPressed: () => _showComingSoon(context, 'Group Summary'),
                  ),
                  _buildButton(
                    'Registers',
                    onPressed: () => _showComingSoon(context, 'Registers'),
                  ),
                  _buildButton(
                    'List Of Accounts',
                    onPressed: () => _showComingSoon(context, 'List Of Accounts'),
                  ),
                  _buildButton(
                    'Address Book',
                    onPressed: () => _showComingSoon(context, 'Address Book'),
                  ),
                  _buildButton(
                    'Trial Balance',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TrialBalance(),
                      ),
                    ),
                  ),
                  _buildButton(
                    'Final Reports',
                    onPressed: () {
                      final company = StorageService.getSelectedCompany();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FutureBuilder<Map<String, dynamic>?>(
                            future: company,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Scaffold(
                                  body: Center(child: CircularProgressIndicator()),
                                );
                              }
                              final companyData = snapshot.data;
                              return FinalReports(
                                companyName: companyData?['name'] as String? ?? 'Unknown Company',
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
