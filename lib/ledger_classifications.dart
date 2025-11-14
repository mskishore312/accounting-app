class LedgerClassifications {
  static const Map<String, String> groupClassifications = {
    'Bank Accounts': 'Current Assets',
    'Bank OD A/c': 'Loans (Liability)',
    'Branch / Division': 'Primary',
    'Capital Account': 'Primary',
    'Cash-in-hand': 'Current Assets',
    'Current Assets': 'Primary',
    'Current Liabilities': 'Primary',
    'Deposits (Assets)': 'Current Assets',
    'Direct Expenses': 'Primary',
    'Direct Incomes': 'Primary',
    'Duties & Taxes': 'Current Liabilities',
    'Fixed Assets': 'Primary',
    'Indirect Expenses': 'Primary',
    'Indirect Income': 'Primary',
    'Investments': 'Primary',
    'Loans & Advances (Asset)': 'Current Assets',
    'Loans (Liability)': 'Primary',
    'Misc. Expenses (ASSET)': 'Primary',
    'Provisions': 'Current Liabilities',
    'Purchase Accounts': 'Primary',
    'Reserves & Surplus': 'Capital Account',
    'Sales Accounts': 'Primary',
    'Secured Loans': 'Loans (Liability)',
    'Stock-in-hand': 'Current Assets',
    'Sundry Creditors': 'Current Liabilities',
    'Sundry Debtors': 'Current Assets',
    'Suspense A/c': 'Primary',
    'Unsecured Loans': 'Loans (Liability)',
  };

  static String getClassification(String group) {
    return groupClassifications[group] ?? 'Primary';
  }

  static List<String> getGroupsUnderClassification(String classification) {
    return groupClassifications.entries
        .where((entry) => entry.value == classification)
        .map((entry) => entry.key)
        .toList();
  }
}
