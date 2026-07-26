import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Exports ledger reports as CSV spreadsheets (opens in Excel/Sheets).
class ExcelExportService {
  static String _csvEscape(Object? value) {
    final text = value?.toString() ?? '';
    if (text.contains(',') || text.contains('"') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  static String _formatDate(String isoDate) {
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(isoDate));
    } catch (_) {
      return isoDate;
    }
  }

  /// Build the CSV file for a ledger report and return it.
  static Future<File> generateLedgerCsv({
    required String companyName,
    required String ledgerName,
    required String periodText,
    required double openingBalance,
    required bool isOpeningBalanceDebit,
    required List<Map<String, dynamic>> entries,
    required double closingBalance,
    required bool isClosingBalanceDebit,
    required double totalDebit,
    required double totalCredit,
    required bool showNarration,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln(_csvEscape(companyName));
    buffer.writeln('${_csvEscape('Ledger: $ledgerName')},${_csvEscape(periodText)}');
    buffer.writeln();

    final header = ['Date', 'Particulars', 'Vch Type', 'Vch No', 'Debit', 'Credit'];
    if (showNarration) header.add('Narration');
    buffer.writeln(header.map(_csvEscape).join(','));

    buffer.writeln([
      '',
      'Opening Balance',
      '',
      '',
      isOpeningBalanceDebit ? openingBalance.toStringAsFixed(2) : '',
      isOpeningBalanceDebit ? '' : openingBalance.toStringAsFixed(2),
      if (showNarration) '',
    ].map(_csvEscape).join(','));

    for (final entry in entries) {
      final debit = (entry['debit'] as num?)?.toDouble() ?? 0.0;
      final credit = (entry['credit'] as num?)?.toDouble() ?? 0.0;
      buffer.writeln([
        _formatDate(entry['voucher_date'] as String? ?? ''),
        entry['particulars'] ?? '',
        entry['voucher_type'] ?? '',
        entry['voucher_number'] ?? '',
        debit == 0 ? '' : debit.toStringAsFixed(2),
        credit == 0 ? '' : credit.toStringAsFixed(2),
        if (showNarration) entry['description'] ?? '',
      ].map(_csvEscape).join(','));
    }

    buffer.writeln([
      '',
      'Total',
      '',
      '',
      totalDebit.toStringAsFixed(2),
      totalCredit.toStringAsFixed(2),
      if (showNarration) '',
    ].map(_csvEscape).join(','));
    buffer.writeln([
      '',
      'Closing Balance',
      '',
      '',
      isClosingBalanceDebit ? closingBalance.toStringAsFixed(2) : '',
      isClosingBalanceDebit ? '' : closingBalance.toStringAsFixed(2),
      if (showNarration) '',
    ].map(_csvEscape).join(','));

    final dir = await getTemporaryDirectory();
    final safeName = ledgerName.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File(p.join(dir.path, 'Ledger_${safeName}_$stamp.csv'));
    await file.writeAsString(buffer.toString(), flush: true);
    return file;
  }

  /// Share the CSV via the system share sheet.
  /// With [asMail] a mail subject/body is prefilled for mail apps.
  static Future<void> shareCsv(File csvFile, String ledgerName,
      {bool asMail = false}) async {
    await Share.shareXFiles(
      [XFile(csvFile.path, mimeType: 'text/csv')],
      subject: asMail ? 'Ledger Report - $ledgerName' : null,
      text: asMail
          ? 'Please find attached the ledger report for $ledgerName (CSV, opens in Excel).'
          : 'Ledger report for $ledgerName (CSV, opens in Excel).',
    );
  }
}
