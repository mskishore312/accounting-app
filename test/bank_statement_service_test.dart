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
}
