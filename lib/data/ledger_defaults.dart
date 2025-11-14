/// This file contains the default ledger accounts and their groups
/// as shown in the account masters page.

class LedgerDefaults {
  /// Get the default ledger accounts with their groups
  static List<Map<String, dynamic>> getDefaultLedgers() {
    return [
      // Only Cash account should be available by default
      {
        'name': 'Cash',
        'classification': 'Cash-in-hand',
        'balance': 0.0,
      },
    ];
  }

  /// Get the primary account groups
  static List<String> getPrimaryGroups() {
    return [
      'Primary',
      'Capital Account',
      'Current Assets',
      'Current Liabilities',
      'Loans (Liability)',
    ];
  }
}
