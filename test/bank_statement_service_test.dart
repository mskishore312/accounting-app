import 'package:accounting_app/services/bank_statement_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses debit and credit bank statement rows', () {
    const text = '''
01/04/2026 UPI/DR Grocery Store 500.00 DR 9,500.00 CR
02/04/2026 NEFT CREDIT Customer Receipt 1,000.00 CR 10,500.00 CR
''';

    final transactions = BankStatementService.parseExtractedText(text);

    expect(transactions, hasLength(2));
    expect(transactions[0].amount, 500);
    expect(
      transactions[0].direction,
      BankTransactionDirection.withdrawal,
    );
    expect(transactions[1].amount, 1000);
    expect(
      transactions[1].direction,
      BankTransactionDirection.deposit,
    );
  });

  test('suggests a counterparty from narration and excludes bank ledger', () {
    final transactions = BankStatementService.parseExtractedText('''
01/04/2026 UPI/DR ACME OFFICE SUPPLIES 500.00 DR 9,500.00 CR
''');
    final ledgers = <Map<String, dynamic>>[
      {'id': 1, 'name': 'Main Bank', 'classification': 'Bank Accounts'},
      {
        'id': 2,
        'name': 'Acme Office Supplies',
        'classification': 'Indirect Expenses',
      },
    ];

    BankStatementService.suggestLedgers(
      transactions,
      ledgers,
      bankLedgerId: 1,
    );

    expect(transactions.single.suggestedLedgerId, 2);
    expect(transactions.single.suggestionLabel, 'Strong match from narration');
  });

  test('leaves ledger open when there is no responsible match', () {
    final transactions = BankStatementService.parseExtractedText('''
01/04/2026 UPI/DR UNKNOWN PARTY 500.00 DR 9,500.00 CR
''');

    BankStatementService.suggestLedgers(
      transactions,
      [
        {'id': 1, 'name': 'Main Bank', 'classification': 'Bank Accounts'},
        {'id': 2, 'name': 'Rent', 'classification': 'Indirect Expenses'},
      ],
      bankLedgerId: 1,
    );

    expect(transactions.single.suggestedLedgerId, isNull);
    expect(
      transactions.single.suggestionLabel,
      'No confident suggestion — choose a ledger',
    );
  });
}
