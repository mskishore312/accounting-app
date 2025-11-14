import 'package:flutter/material.dart';
import 'package:accounting_app/ui/select_company.dart';
import 'package:accounting_app/ui/new_company.dart';
import 'package:accounting_app/ui/utility.dart';

class Gateway extends StatelessWidget {
  const Gateway({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF5F0),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF2C5545),
              ),
              child: Row(
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
                    'TOM-PA (Tally On Mobile)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
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
                'Gateway',
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
                      'Select Company',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SelectCompany(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildButton(
                      'Create Company',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NewCompany(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildButton(
                      'Utility',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Utility(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildButton(
                      'License Info',
                      onPressed: () {
                        // TODO: Implement License Info
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildButton(
                      'Help & Support',
                      onPressed: () {
                        // TODO: Implement Help & Support
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildButton(
                      'Quit',
                      onPressed: () {
                        // TODO: Implement Quit
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildButton(
                      'Buy Now',
                      onPressed: () {
                        // TODO: Implement Buy Now
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
