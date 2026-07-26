# App Completeness Assessment — vs "UI Designs" folder

> **Update (2026-07-26):** All gaps listed below have since been implemented and
> the app has been consolidated onto `main` (newest feature branch + report
> drill-down merge). Gateway dialogs, Utility backup/restore/split, the five
> report screens, Tax/GST masters, ledger Excel/SMS exports and the Inventory
> Voucher are all done. This document is kept as the assessment that drove
> that work.

Date: 2026-07-26. Assessed branch: `claude/contra-sales-purchase-gst` (newest, 2026-07-11), which contains the most complete version of the Flutter app, including the bank-import OCR and editable-OCR work.

**Verdict: the app is close to complete against the UI Designs folder, but not complete.** Every designed screen has an implemented counterpart, and the core accounting flow (companies → masters → all six voucher types → daybook/ledger/TB/P&L/BS) works end to end. However, a number of buttons that appear in the design screenshots are stubbed with `TODO` or "coming soon" handlers, and the work is scattered across unmerged branches.

## Repository state (affects "completeness" itself)

- The default branch `main` is **empty** (just a README). The app only exists on feature branches.
- Newest and most complete Flutter branch: `claude/contra-sales-purchase-gst`.
- `master` is a stale, older copy (last commit 2026-05-24) — it is where the `UI Designs/` folder lives, and the newer claude branches carry it too.
- Two branches hold features **not merged** into the newest branch:
  - `claude/report-group-drilldown` — per-group report drill-down.
  - `claude/journal-bank-pdf-import` — largely superseded by `claude/bank-import-ocr-final` (which *is* included), but has some diverging report changes.
- `claude/app-ui-designs-impl-g10493` is a separate React/Vite web prototype of the same designs — a parallel implementation, not part of the Flutter app.

## Design coverage — implemented ✅

All 48 design images map to existing screens in `lib/ui/`:

| Design | Implementation |
|---|---|
| Gateway.jpeg | `gateway.dart` (menu present; see gaps) |
| Options.jpeg (Masters/Vouchers/Reports + period footer) | `options.dart` |
| Select Company / create company | `select_company.dart`, `new_company.dart`, `new_company_form.dart` |
| Utility.jpg | `utility.dart` (menu present; see gaps) |
| Masters (categories, default ledgers, ledger creation, under-options) | `master_options.dart`, `account_masters.dart`, `ledger_creation.dart`, `data/ledger_defaults.dart` |
| Vouchers page / Accounting Vouchers (6 types + counts + total) | `vouchers.dart`, `accounting_vouchers.dart` |
| Receipt / Payment / Journal creation + list pages | `receipt_voucher*.dart`, `payment_voucher*.dart`, `journal_voucher*.dart` |
| Contra / Sales / Purchase (incl. GST invoices, inventory lines) | `contra_voucher.dart`, `invoice_voucher.dart`, `voucher_type_list.dart` |
| Reports/Daybook page.jpg | `daybook.dart` |
| Ledger list, cash/capital ledger pages, opening balance | `ledger_list.dart`, `ledger_view.dart` |
| The 9 ledger **search** mockups (by date, particulars contains/equal, voucher type, debit amount modes, narration) | fully implemented in `ledger_view.dart` search dialog |
| Date picker / date range picker | `widgets/voucher_date_picker.dart`, `date_range_selector.dart`, `custom_date_spinner_wheel.dart` |
| Trial Balance (tb screenshot) | `trial_balance.dart` |
| P&L format | `profit_and_loss.dart`, `trading_and_pl.dart` |
| BS detail / non-detail | `balance_sheet.dart` + `widgets/report_view_toggle.dart` (condensed/detailed toggle) |
| Final reports page | `final_reports.dart` |

## Gaps — designed but stubbed ❌

Buttons visible in the design screenshots that only show a snackbar or have empty `// TODO` handlers:

1. **Gateway** (`gateway.dart`): License Info, Help & Support, Quit, Buy Now — all TODO.
2. **Utility** (`utility.dart`) — design shows 9 buttons; 6 are TODO: Backup, Backup And Mail, Restore, Split Company, Emergency Backup, Emergency Restore. (Working: Company Edit, Delete Company, Settings.)
3. **Reports menu** (`reports.dart`) — design shows 9 buttons; 5 are "coming soon": Cash/Bank Book, Group Summary, Registers, **List Of Accounts**, Address Book.
   - Note: `lib/ui/list_of_accounts.dart` exists and matches the "list of accounts.jpg" design, but it is **dead code — never wired to the Reports menu**. Easy win.
4. **Masters** (`master_options.dart`): Tax Masters and GST Tax Masters — "coming soon" (Account Masters and Inventory Masters work).
5. **Ledger options menu** (`ledger_view.dart`): Export as Excel, Excel + Mail, Send SMS, Send WhatsApp — "coming soon" (PDF export + mail works).
6. **Vouchers menu** (`vouchers.dart`): Inventory Voucher — "coming soon" (inventory *items* master and inventory lines on Sales/Purchase invoices do exist).

## Other observations

- Tests exist (`test/bank_statement_service_test.dart`, `widget_test.dart`) and a GitHub Actions APK build workflow (`.github/workflows/build-apk.yml`) is present on the newest branch.
- Could not compile/run in this environment (no Flutter SDK installed), so this assessment is static: code review + design-image comparison.

## Suggested next steps

1. Consolidate: merge `claude/contra-sales-purchase-gst` (and cherry-pick `report-group-drilldown`) into `main`/`master` so one branch is the source of truth.
2. Wire up the existing `ListOfAccounts` screen to the Reports menu.
3. Implement Backup/Restore (highest-value Utility stubs for an accounting app).
4. Decide whether Gateway's License/Help/Buy Now and the SMS/WhatsApp/Excel exports are in scope, or remove the buttons to match a finished product.
