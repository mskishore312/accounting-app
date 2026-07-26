import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';

/// App bar title showing the currently selected company's name.
class CompanyTitle extends StatelessWidget {
  const CompanyTitle({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: StorageService.getSelectedCompany(),
      builder: (context, snapshot) {
        return Text(
          snapshot.data?['name'] as String? ?? '',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        );
      },
    );
  }
}
