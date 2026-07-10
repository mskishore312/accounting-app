import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

enum BankTransactionDirection { deposit, withdrawal }

class BankStatementTransaction {
  BankStatementTransaction({
    required this.date,
    required this.description,
    required this.amount,
    required this.direction,
    required this.rawText,
  });

  final DateTime date;
  final String description;
  final double amount;
  BankTransactionDirection direction;
  final String rawText;
  bool selected = true;
  int? suggestedLedgerId;
  String suggestionLabel = 'Review ledger';
}

class BankStatementService {
  static final RegExp _dateAtStart = RegExp(
    r'^\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{1,2}\s+(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+\d{2,4})\b',
    caseSensitive: false,
  );
  static final RegExp _amountPattern = RegExp(
    r'(?:₹|inr|rs\.?\s*)?([0-9][0-9,]*\.\d{2})\s*(cr|dr)?',
    caseSensitive: false,
  );

  static List<BankStatementTransaction> extractTransactions(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      final text = PdfTextExtractor(document).extractText();
      return parseExtractedText(text);
    } finally {
      document.dispose();
    }
  }

  static List<BankStatementTransaction> parseExtractedText(String text) {
    final records = <String>[];
    StringBuffer? current;

    for (final rawLine in text.replaceAll('\r', '').split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (_dateAtStart.hasMatch(line)) {
        if (current != null) records.add(current.toString());
        current = StringBuffer(line);
      } else if (current != null) {
        current.write(' $line');
      }
    }
    if (current != null) records.add(current.toString());

    final parsed = <_ParsedBankRow>[];
    for (final record in records) {
      final dateMatch = _dateAtStart.firstMatch(record);
      if (dateMatch == null) continue;
      final date = _parseDate(dateMatch.group(1)!);
      if (date == null) continue;

      final amountMatches = _amountPattern.allMatches(record).toList();
      if (amountMatches.isEmpty) continue;
      final numbers = amountMatches
          .map((match) => _parseAmount(match.group(1)!))
          .whereType<double>()
          .toList();
      if (numbers.isEmpty) continue;

      final transactionAmount =
          numbers.length >= 2 ? numbers[numbers.length - 2] : numbers.last;
      final balance = numbers.length >= 2 ? numbers.last : null;
      if (transactionAmount <= 0) continue;

      final lower = record.toLowerCase();
      BankTransactionDirection? direction;
      final transactionAmountMatch = amountMatches[
          amountMatches.length >= 2 ? amountMatches.length - 2 : amountMatches.length - 1];
      final transactionSuffix = transactionAmountMatch.group(2)?.toLowerCase();
      if (transactionSuffix == 'cr' ||
          lower.contains(' credit ') ||
          lower.contains(' deposit ') ||
          lower.contains('received')) {
        direction = BankTransactionDirection.deposit;
      } else if (transactionSuffix == 'dr' ||
          lower.contains(' debit ') ||
          lower.contains(' withdrawal ') ||
          lower.contains(' atm ') ||
          lower.contains(' pos ')) {
        direction = BankTransactionDirection.withdrawal;
      }

      var description = record.substring(dateMatch.end).trim();
      description = description.replaceAll(_amountPattern, ' ');
      description = description.replaceAll(RegExp(r'\s+'), ' ').trim();
      parsed.add(
        _ParsedBankRow(
          date: date,
          description: description.isEmpty ? 'Bank transaction' : description,
          amount: transactionAmount,
          balance: balance,
          direction: direction,
          rawText: record,
        ),
      );
    }

    for (var index = 0; index < parsed.length; index++) {
      final row = parsed[index];
      if (row.direction != null) continue;
      if (index > 0 && row.balance != null && parsed[index - 1].balance != null) {
        final movement = row.balance! - parsed[index - 1].balance!;
        row.direction = movement >= 0
            ? BankTransactionDirection.deposit
            : BankTransactionDirection.withdrawal;
        if ((movement.abs() - row.amount).abs() > 0.01 && movement != 0) {
          row.amount = movement.abs();
        }
      } else {
        row.direction = BankTransactionDirection.withdrawal;
      }
    }

    return parsed
        .map(
          (row) => BankStatementTransaction(
            date: row.date,
            description: row.description,
            amount: row.amount,
            direction: row.direction!,
            rawText: row.rawText,
          ),
        )
        .toList();
  }

  static void suggestLedgers(
    List<BankStatementTransaction> transactions,
    List<Map<String, dynamic>> ledgers, {
    int? bankLedgerId,
  }) {
    final candidates = ledgers
        .where((ledger) => ledger['id'] != bankLedgerId)
        .toList();

    for (final transaction in transactions) {
      final description = transaction.description.toLowerCase();
      Map<String, dynamic>? match;

      for (final ledger in candidates) {
        final name = (ledger['name'] as String).toLowerCase().trim();
        if (name.length >= 4 && description.contains(name)) {
          match = ledger;
          transaction.suggestionLabel = 'Matched ledger name';
          break;
        }
      }

      if (match == null) {
        final keywords = transaction.direction == BankTransactionDirection.deposit
            ? <String, List<String>>{
                'interest': ['interest'],
                'sales': ['sale', 'customer', 'receipt'],
                'salary': ['salary', 'payroll'],
              }
            : <String, List<String>>{
                'bank charges': ['charge', 'fee', 'commission'],
                'salary': ['salary', 'payroll'],
                'rent': ['rent'],
                'electricity': ['electric', 'eb bill', 'power'],
                'fuel': ['fuel', 'petrol', 'diesel'],
                'tax': ['gst', 'tax', 'tds'],
                'cash': ['atm', 'cash withdrawal'],
              };

        for (final keywordEntry in keywords.entries) {
          if (!keywordEntry.value.any(description.contains)) continue;
          match = candidates.cast<Map<String, dynamic>?>().firstWhere(
                (ledger) => (ledger!['name'] as String)
                    .toLowerCase()
                    .contains(keywordEntry.key),
                orElse: () => null,
              );
          if (match != null) {
            transaction.suggestionLabel = 'Suggested from narration';
            break;
          }
        }
      }

      match ??= candidates.cast<Map<String, dynamic>?>().firstWhere(
            (ledger) =>
                (ledger!['classification'] as String? ?? '') == 'Suspense A/c',
            orElse: () => null,
          );
      if (match != null) {
        transaction.suggestedLedgerId = match['id'] as int;
        if (transaction.suggestionLabel == 'Review ledger') {
          transaction.suggestionLabel = 'Posted to Suspense — review';
        }
      }
    }
  }

  static DateTime? _parseDate(String value) {
    final formats = <DateFormat>[
      DateFormat('d/M/yyyy'),
      DateFormat('d-M-yyyy'),
      DateFormat('d/M/yy'),
      DateFormat('d-M-yy'),
      DateFormat('d MMM yyyy'),
      DateFormat('d MMM yy'),
    ];
    for (final format in formats) {
      try {
        return format.parseStrict(value);
      } catch (_) {}
    }
    return null;
  }

  static double? _parseAmount(String value) {
    return double.tryParse(value.replaceAll(',', ''));
  }
}

class _ParsedBankRow {
  _ParsedBankRow({
    required this.date,
    required this.description,
    required this.amount,
    required this.balance,
    required this.direction,
    required this.rawText,
  });

  final DateTime date;
  final String description;
  double amount;
  final double? balance;
  BankTransactionDirection? direction;
  final String rawText;
}
