import 'package:flutter/material.dart';

import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/services/ai_chat_service.dart';
import 'package:accounting_app/trial_balance.dart';
import 'package:accounting_app/ui/account_masters.dart';
import 'package:accounting_app/ui/balance_sheet.dart';
import 'package:accounting_app/ui/cash_bank_book.dart';
import 'package:accounting_app/ui/daybook.dart';
import 'package:accounting_app/ui/final_reports.dart';
import 'package:accounting_app/ui/group_summary.dart';
import 'package:accounting_app/ui/ledger_view.dart';
import 'package:accounting_app/ui/list_of_accounts.dart';
import 'package:accounting_app/ui/registers.dart';
import 'package:accounting_app/ui/reports.dart';
import 'package:accounting_app/ui/trading_and_pl.dart';
import 'package:accounting_app/ui/vouchers.dart';

/// Turns a [ChatNavigation] into the screen it names.
///
/// Kept apart from the chat panel so the mapping is one readable table rather
/// than a switch buried in a widget, and so a target the app cannot open
/// fails by returning null instead of throwing at the user.
class AiNavigator {
  const AiNavigator._();

  static Future<Widget?> build(ChatNavigation nav) async {
    switch (nav.target) {
      case 'daybook':
        return const Daybook();
      case 'trial_balance':
        return const TrialBalance();
      case 'balance_sheet':
        return const BalanceSheet();
      case 'profit_and_loss':
        return const TradingAndPL();
      case 'cash_bank_book':
        return const CashBankBook();
      case 'group_summary':
        return const GroupSummary();
      case 'list_of_accounts':
        return const ListOfAccounts();
      case 'registers':
        return const Registers();
      case 'reports':
        return const Reports();
      case 'vouchers':
        return const Vouchers();
      case 'account_masters':
        return const AccountMasters();
      case 'final_reports':
        final company = await StorageService.getSelectedCompany();
        if (company == null) return null;
        return FinalReports(
          companyName: company['name'] as String? ?? 'Company',
        );
      case 'ledger':
        return _ledger(nav);
      default:
        return null;
    }
  }

  /// A named ledger, opened on the period the assistant asked for.
  static Future<Widget?> _ledger(ChatNavigation nav) async {
    final wanted = nav.ledgerName?.trim();
    if (wanted == null || wanted.isEmpty) return const ListOfAccounts();

    final ledgers = await StorageService.getLedgers();
    final target = wanted.toLowerCase();

    Map<String, dynamic>? match;
    for (final ledger in ledgers) {
      final name = (ledger['name'] as String? ?? '').toLowerCase();
      if (name == target) {
        match = ledger;
        break;
      }
      // Fall back to a partial hit so "rent" opens "Rent Paid".
      match ??= name.contains(target) || target.contains(name) ? ledger : null;
    }
    if (match == null) return const ListOfAccounts();

    final entries = await StorageService.getLedgerReport(match['id'] as int);
    return LedgerView(
      ledger: match,
      initialEntries: entries,
      initialStartDate: nav.startDate,
      initialEndDate: nav.endDate,
    );
  }
}
