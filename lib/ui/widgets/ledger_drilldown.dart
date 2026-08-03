import 'package:flutter/material.dart';

import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/ui/ledger_view.dart';

/// Opens the ledger report for [ledgerName] over the report's period.
///
/// Used by the Trial Balance and the financial statements so tapping a
/// line item drills into the ledger behind it.
Future<void> openLedgerDrilldown(
  BuildContext context, {
  required String ledgerName,
  DateTime? startDate,
  DateTime? endDate,
}) async {
  try {
    final ledgers = await StorageService.getLedgers();
    final matches = ledgers.where(
      (l) => (l['name'] as String).toLowerCase() == ledgerName.toLowerCase(),
    );
    if (matches.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ledger "$ledgerName" not found')),
        );
      }
      return;
    }
    final ledger = matches.first;
    final entries = await StorageService.getLedgerReport(ledger['id'] as int);
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LedgerView(
          ledger: ledger,
          initialEntries: entries,
          initialStartDate: startDate,
          initialEndDate: endDate,
        ),
      ),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ledger: $e')),
      );
    }
  }
}

/// Ledgers belonging to a report group, for drilling into a group row.
Future<List<Map<String, dynamic>>> ledgersInGroup(String classification) async {
  final ledgers = await StorageService.getLedgers();
  return ledgers
      .where((l) => (l['classification'] as String? ?? '') == classification)
      .toList();
}
