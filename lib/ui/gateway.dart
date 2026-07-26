import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
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
                      onPressed: () => _showLicenseInfo(context),
                    ),
                    const SizedBox(height: 24),
                    _buildButton(
                      'Help & Support',
                      onPressed: () => _showHelpAndSupport(context),
                    ),
                    const SizedBox(height: 24),
                    _buildButton(
                      'Quit',
                      onPressed: () => _confirmQuit(context),
                    ),
                    const SizedBox(height: 24),
                    _buildButton(
                      'Buy Now',
                      onPressed: () => _showBuyNow(context),
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

  static const String _appVersion = 'Version 1.0';
  static const String _supportEmail = 'support@tompa.app';

  void _showLicenseInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'License Info',
          style: TextStyle(color: Color(0xFF2C5545), fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('TOM-PA (Tally On Mobile)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(_appVersion),
            SizedBox(height: 8),
            Text('Edition: Trial'),
            SizedBox(height: 8),
            Text('Licensed for personal and small-business bookkeeping. '
                'All data is stored locally on this device.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: Color(0xFF2C5545))),
          ),
        ],
      ),
    );
  }

  void _showHelpAndSupport(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Help & Support',
          style: TextStyle(color: Color(0xFF2C5545), fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Getting started:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('1. Create a company from the Gateway.'),
            const Text('2. Add ledgers under Masters.'),
            const Text('3. Record vouchers and view reports.'),
            const SizedBox(height: 12),
            const Text('Need more help?',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            InkWell(
              onTap: () async {
                final uri = Uri(
                  scheme: 'mailto',
                  path: _supportEmail,
                  queryParameters: {'subject': 'TOM-PA Support Request'},
                );
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              child: const Text(
                _supportEmail,
                style: TextStyle(
                  color: Color(0xFF4C7380),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: Color(0xFF2C5545))),
          ),
        ],
      ),
    );
  }

  void _confirmQuit(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Quit',
          style: TextStyle(color: Color(0xFF2C5545), fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to quit the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF2C5545))),
          ),
          TextButton(
            onPressed: () => SystemNavigator.pop(),
            child: const Text('Quit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showBuyNow(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Buy Now',
          style: TextStyle(color: Color(0xFF2C5545), fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You are using the trial edition. To purchase a full license, '
          'contact us at $_supportEmail and we will get you set up.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: Color(0xFF2C5545))),
          ),
          TextButton(
            onPressed: () async {
              final uri = Uri(
                scheme: 'mailto',
                path: _supportEmail,
                queryParameters: {'subject': 'TOM-PA License Purchase'},
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            child: const Text('Contact Us', style: TextStyle(color: Color(0xFF2C5545))),
          ),
        ],
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
