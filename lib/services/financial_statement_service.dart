import 'package:accounting_app/data/storage_service.dart';

/// Service for handling financial statement calculations and classifications
class FinancialStatementService {
  // Classification mapping for Balance Sheet - ASSETS
  static const List<String> fixedAssetGroups = ['Fixed Assets'];
  static const List<String> investmentGroups = ['Investments'];
  static const List<String> currentAssetGroups = [
    'Cash-in-hand',
    'Bank Accounts',
    'Current Assets',
    'Stock-in-hand',
    'Sundry Debtors',
    'Deposits (Assets)',
  ];
  static const List<String> loansAssetGroups = ['Loans & Advances (Asset)'];
  static const List<String> miscAssetGroups = ['Misc. Expenses (ASSET)'];

  // Classification mapping for Balance Sheet - LIABILITIES
  static const List<String> capitalGroups = ['Capital Account', 'Reserves & Surplus'];
  static const List<String> loanLiabilityGroups = [
    'Loans (Liability)',
    'Secured Loans',
    'Unsecured Loans',
  ];
  static const List<String> bankODGroups = ['Bank OD A/c'];
  static const List<String> currentLiabilityGroups = [
    'Current Liabilities',
    'Sundry Creditors',
    'Duties & Taxes',
    'Provisions',
  ];

  // Classification mapping for Trading Account
  static const List<String> purchaseGroups = ['Purchase Accounts'];
  static const List<String> directExpenseGroups = ['Direct Expenses'];
  static const List<String> salesGroups = ['Sales Accounts'];
  static const List<String> directIncomeGroups = ['Direct Incomes'];

  // Classification mapping for Profit & Loss Account
  static const List<String> indirectExpenseGroups = ['Indirect Expenses'];
  static const List<String> indirectIncomeGroups = ['Indirect Income'];

  // Other/Special groups
  static const List<String> otherGroups = ['Branch / Division', 'Suspense A/c'];

  /// Determines if a ledger group has a debit nature by default
  static bool isDebitNature(String classification) {
    return fixedAssetGroups.contains(classification) ||
        investmentGroups.contains(classification) ||
        currentAssetGroups.contains(classification) ||
        loansAssetGroups.contains(classification) ||
        miscAssetGroups.contains(classification) ||
        purchaseGroups.contains(classification) ||
        directExpenseGroups.contains(classification) ||
        indirectExpenseGroups.contains(classification);
  }

  /// Determines if a ledger group has a credit nature by default
  static bool isCreditNature(String classification) {
    return capitalGroups.contains(classification) ||
        loanLiabilityGroups.contains(classification) ||
        bankODGroups.contains(classification) ||
        currentLiabilityGroups.contains(classification) ||
        salesGroups.contains(classification) ||
        directIncomeGroups.contains(classification) ||
        indirectIncomeGroups.contains(classification);
  }

  /// Calculate ledger balance for a given period
  static Future<double> calculateLedgerBalance({
    required int ledgerId,
    required Map<String, dynamic> ledger,
    DateTime? startDate,
    DateTime? endDate,
    String? booksBeginningDate,
  }) async {
    final classification = ledger['classification'] as String? ?? '';

    // Special handling for Stock-in-Hand ledgers - use date-specific valuations
    if (classification == 'Stock-in-hand') {
      return await getStockBalanceForDate(ledgerId, endDate);
    }

    final report = await StorageService.getLedgerReport(ledgerId);
    final userOpeningBalance = (ledger['balance'] as num?)?.toDouble() ?? 0.0;

    // Format dates for comparison (YYYY-MM-DD)
    String? startDateStr;
    String? endDateStr;
    if (startDate != null) {
      startDateStr =
          '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    }
    if (endDate != null) {
      endDateStr =
          '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
    }

    // Determine if we should use user-provided opening balance
    bool useUserProvidedBalance = false;
    if (booksBeginningDate != null && startDateStr != null) {
      if (startDateStr == booksBeginningDate) {
        useUserProvidedBalance = true;
      }
    }

    double balance = 0.0;

    // Start with user-provided balance if applicable
    if (useUserProvidedBalance) {
      // Apply sign based on nature of the account
      balance = isDebitNature(classification)
          ? userOpeningBalance
          : -userOpeningBalance;
    }

    // Process all entries
    for (var entry in report) {
      final entryDate = entry['voucher_date'] as String? ?? '';
      if (entryDate.isEmpty) continue;

      final debit = (entry['debit'] as num?)?.toDouble() ?? 0.0;
      final credit = (entry['credit'] as num?)?.toDouble() ?? 0.0;

      // If not using user balance, accumulate everything before start date
      if (!useUserProvidedBalance &&
          startDateStr != null &&
          entryDate.compareTo(startDateStr) < 0) {
        balance += debit - credit;
        continue;
      }

      // Skip entries before start date if using user balance
      if (useUserProvidedBalance &&
          startDateStr != null &&
          entryDate.compareTo(startDateStr) < 0) {
        continue;
      }

      // Skip entries after end date
      if (endDateStr != null && entryDate.compareTo(endDateStr) > 0) {
        continue;
      }

      // Include in the period
      if (startDateStr == null || entryDate.compareTo(startDateStr) >= 0) {
        balance += debit - credit;
      }
    }

    return balance;
  }

  /// Get stock balance for a specific date (for Stock-in-Hand ledgers)
  static Future<double> getStockBalanceForDate(int ledgerId, DateTime? date) async {
    if (date == null) {
      // No date specified, get latest valuation
      final valuations = await StorageService.getStockValuations(ledgerId);
      if (valuations.isEmpty) return 0.0;

      valuations.sort((a, b) =>
        (b['valuation_date'] as String).compareTo(a['valuation_date'] as String));
      return (valuations.first['amount'] as num).toDouble();
    }

    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final valuation = await StorageService.getStockValuationForDate(ledgerId, dateStr);

    return valuation != null ? (valuation['amount'] as num).toDouble() : 0.0;
  }

  /// Get detailed stock info including valuation dates for notes
  static Future<Map<String, dynamic>> getStockInfoForPeriod({
    required int ledgerId,
    required String ledgerName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Map<String, dynamic> result = {
      'balance': 0.0,
      'note': null,
      'opening_date': null,
      'closing_date': null,
    };

    if (endDate == null) {
      // No period, use latest
      final valuations = await StorageService.getStockValuations(ledgerId);
      if (valuations.isEmpty) {
        result['note'] = {
          'ledger': ledgerName,
          'message': 'No stock valuations recorded',
          'type': 'warning',
        };
        return result;
      }

      valuations.sort((a, b) => (b['valuation_date'] as String).compareTo(a['valuation_date'] as String));
      result['balance'] = (valuations.first['amount'] as num).toDouble();
      result['closing_date'] = valuations.first['valuation_date'];
      return result;
    }

    // Get closing stock
    final endDateStr = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
    final closingVal = await StorageService.getStockValuationForDate(ledgerId, endDateStr);

    if (closingVal == null) {
      result['note'] = {
        'ledger': ledgerName,
        'message': 'No stock valuation found on or before ${_formatDisplayDate(endDate)}',
        'type': 'warning',
      };
      return result;
    }

    final closingValDate = closingVal['valuation_date'] as String;
    result['balance'] = (closingVal['amount'] as num).toDouble();
    result['closing_date'] = closingValDate;

    // Check if date matches exactly
    if (closingValDate != endDateStr) {
      result['note'] = {
        'ledger': ledgerName,
        'message': 'Closing stock as of ${_formatDbDate(closingValDate)} (closest to ${_formatDisplayDate(endDate)})',
        'type': 'info',
      };
    }

    return result;
  }

  static String _formatDisplayDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String _formatDbDate(String dbDate) {
    final parts = dbDate.split('-');
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  /// Get all assets with their balances
  static Future<Map<String, List<Map<String, dynamic>>>> getAssets({
    DateTime? startDate,
    DateTime? endDate,
    String? booksBeginningDate,
  }) async {
    final ledgers = await StorageService.getLedgers();
    Map<String, List<Map<String, dynamic>>> assets = {
      'Fixed Assets': [],
      'Investments': [],
      'Current Assets': [],
      'Loans & Advances': [],
      'Misc. Expenses': [],
    };

    for (var ledger in ledgers) {
      final classification = ledger['classification'] as String? ?? '';
      final balance = await calculateLedgerBalance(
        ledgerId: ledger['id'] as int,
        ledger: ledger,
        startDate: startDate,
        endDate: endDate,
        booksBeginningDate: booksBeginningDate,
      );

      if (balance == 0) continue;

      final ledgerData = {
        'name': ledger['name'],
        'balance': balance.abs(),
        'group': classification,
      };

      if (fixedAssetGroups.contains(classification)) {
        assets['Fixed Assets']!.add(ledgerData);
      } else if (investmentGroups.contains(classification)) {
        assets['Investments']!.add(ledgerData);
      } else if (currentAssetGroups.contains(classification)) {
        assets['Current Assets']!.add(ledgerData);
      } else if (loansAssetGroups.contains(classification)) {
        assets['Loans & Advances']!.add(ledgerData);
      } else if (miscAssetGroups.contains(classification)) {
        assets['Misc. Expenses']!.add(ledgerData);
      }
    }

    return assets;
  }

  /// Get all liabilities with their balances
  static Future<Map<String, List<Map<String, dynamic>>>> getLiabilities({
    DateTime? startDate,
    DateTime? endDate,
    String? booksBeginningDate,
  }) async {
    final ledgers = await StorageService.getLedgers();
    Map<String, List<Map<String, dynamic>>> liabilities = {
      'Capital & Reserves': [],
      'Loans': [],
      'Bank Overdraft': [],
      'Current Liabilities': [],
    };

    for (var ledger in ledgers) {
      final classification = ledger['classification'] as String? ?? '';
      final balance = await calculateLedgerBalance(
        ledgerId: ledger['id'] as int,
        ledger: ledger,
        startDate: startDate,
        endDate: endDate,
        booksBeginningDate: booksBeginningDate,
      );

      if (balance == 0) continue;

      final ledgerData = {
        'name': ledger['name'],
        'balance': balance.abs(),
        'group': classification,
      };

      if (capitalGroups.contains(classification)) {
        liabilities['Capital & Reserves']!.add(ledgerData);
      } else if (loanLiabilityGroups.contains(classification)) {
        liabilities['Loans']!.add(ledgerData);
      } else if (bankODGroups.contains(classification)) {
        liabilities['Bank Overdraft']!.add(ledgerData);
      } else if (currentLiabilityGroups.contains(classification)) {
        liabilities['Current Liabilities']!.add(ledgerData);
      }
    }

    return liabilities;
  }

  /// Calculate Trading Account (for Gross Profit calculation)
  static Future<Map<String, dynamic>> calculateTradingAccount({
    DateTime? startDate,
    DateTime? endDate,
    String? booksBeginningDate,
  }) async {
    final ledgers = await StorageService.getLedgers();

    double purchases = 0;
    double directExpenses = 0;
    double sales = 0;
    double directIncome = 0;

    List<Map<String, dynamic>> purchasesList = [];
    List<Map<String, dynamic>> directExpensesList = [];
    List<Map<String, dynamic>> salesList = [];
    List<Map<String, dynamic>> directIncomeList = [];

    for (var ledger in ledgers) {
      final classification = ledger['classification'] as String? ?? '';
      final balance = await calculateLedgerBalance(
        ledgerId: ledger['id'] as int,
        ledger: ledger,
        startDate: startDate,
        endDate: endDate,
        booksBeginningDate: booksBeginningDate,
      );

      if (balance == 0) continue;

      final ledgerData = {
        'name': ledger['name'],
        'balance': balance.abs(),
        'group': classification,
      };

      if (purchaseGroups.contains(classification)) {
        purchases += balance.abs();
        purchasesList.add(ledgerData);
      } else if (directExpenseGroups.contains(classification)) {
        directExpenses += balance.abs();
        directExpensesList.add(ledgerData);
      } else if (salesGroups.contains(classification)) {
        sales += balance.abs();
        salesList.add(ledgerData);
      } else if (directIncomeGroups.contains(classification)) {
        directIncome += balance.abs();
        directIncomeList.add(ledgerData);
      }
    }

    final totalDebit = purchases + directExpenses;
    final totalCredit = sales + directIncome;
    final grossProfit = totalCredit - totalDebit;

    return {
      'purchases': purchasesList,
      'directExpenses': directExpensesList,
      'sales': salesList,
      'directIncome': directIncomeList,
      'totalPurchases': purchases,
      'totalDirectExpenses': directExpenses,
      'totalSales': sales,
      'totalDirectIncome': directIncome,
      'totalDebit': totalDebit,
      'totalCredit': totalCredit,
      'grossProfit': grossProfit,
    };
  }

  /// Calculate Profit & Loss Account (for Net Profit calculation)
  static Future<Map<String, dynamic>> calculateProfitAndLoss({
    DateTime? startDate,
    DateTime? endDate,
    String? booksBeginningDate,
    required double grossProfit,
  }) async {
    final ledgers = await StorageService.getLedgers();

    double indirectExpenses = 0;
    double indirectIncome = 0;

    List<Map<String, dynamic>> indirectExpensesList = [];
    List<Map<String, dynamic>> indirectIncomeList = [];

    for (var ledger in ledgers) {
      final classification = ledger['classification'] as String? ?? '';
      final balance = await calculateLedgerBalance(
        ledgerId: ledger['id'] as int,
        ledger: ledger,
        startDate: startDate,
        endDate: endDate,
        booksBeginningDate: booksBeginningDate,
      );

      if (balance == 0) continue;

      final ledgerData = {
        'name': ledger['name'],
        'balance': balance.abs(),
        'group': classification,
      };

      if (indirectExpenseGroups.contains(classification)) {
        indirectExpenses += balance.abs();
        indirectExpensesList.add(ledgerData);
      } else if (indirectIncomeGroups.contains(classification)) {
        indirectIncome += balance.abs();
        indirectIncomeList.add(ledgerData);
      }
    }

    // Net Profit = Gross Profit + Indirect Income - Indirect Expenses
    final netProfit = grossProfit + indirectIncome - indirectExpenses;

    return {
      'indirectExpenses': indirectExpensesList,
      'indirectIncome': indirectIncomeList,
      'totalIndirectExpenses': indirectExpenses,
      'totalIndirectIncome': indirectIncome,
      'grossProfit': grossProfit,
      'netProfit': netProfit,
    };
  }
}
