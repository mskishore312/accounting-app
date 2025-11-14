import 'package:flutter/material.dart';
import 'package:accounting_app/balance_sheet.dart';
import 'package:accounting_app/profit_and_loss.dart';

class FinalReports extends StatelessWidget {
  final String companyName;

  const FinalReports({Key? key, required this.companyName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(companyName),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(40),
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Final Reports',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildReportButton(
              context,
              'Profit & Loss',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfitAndLoss(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildReportButton(
              context,
              'Balance Sheet',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BalanceSheet(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportButton(
    BuildContext context,
    String title,
    VoidCallback onPressed,
  ) {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          backgroundColor: const Color(0xFF4C7380),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
