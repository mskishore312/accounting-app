import 'package:flutter/material.dart';
import 'package:accounting_app/ui/balance_sheet.dart';
import 'package:accounting_app/ui/profit_and_loss.dart';
import 'package:accounting_app/ui/trading_and_pl.dart';

class FinalReports extends StatelessWidget {
  final String companyName;

  const FinalReports({Key? key, required this.companyName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2E9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C5545),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          companyName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: const Color(0xFF2C5545),
            child: const Text(
              'Final Reports',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildButton(
                    'Profit & Loss',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfitAndLoss(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildButton(
                    'Trading & P&L (Detailed)',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TradingAndPL(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildButton(
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
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF4C7380),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 17,
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
