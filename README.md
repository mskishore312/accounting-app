# Accounting App

A mobile-styled double-entry accounting web app modelled on the
Tally-on-Mobile UI designs (Google Drive: "App UI designs").

## Features

- **Companies** — create/edit/delete companies (name, address,
  contact, TIN/GST, state, security flag, financial year, books
  beginning date); switch between companies.
- **Masters** — 28 default Tally account groups seeded per company,
  custom groups, ledger creation with opening balance (Dr/Cr),
  TIN/GST, address and contact; quick "+" group creation from the
  ledger form; searchable Account Master list.
- **Inventory masters** — Units, Stock Groups (hierarchical) and
  Stock Items with opening qty/rate and a per-item costing method
  (Avg. Cost default, FIFO, LIFO, Last Purchase Cost, Std. Cost, At
  Zero Cost — as in Tally).
- **Vouchers** — Receipt, Payment, Journal, Contra, Sales, Purchase,
  Debit Note and Credit Note with per-type auto numbering, ledger
  pickers (cash/bank restricted where appropriate), narration, edit
  and delete. Sales/Purchase/Debit Note/Credit Note carry stock item
  lines (qty × rate, amount auto-totalled). Inventory vouchers:
  Stock Journal (consumption → production) and Physical Stock
  (counted quantity resets book stock).
- **Tally-principle P&L** — horizontal statement with a Trading
  section (Opening Stock, Purchases, Direct Expenses vs Sales,
  Direct Incomes, Closing Stock) carrying **Gross Profit c/o** down
  to the income statement (Indirect Expenses vs Gross Profit b/f +
  Indirect Income) ending in **Nett Profit**.
- **Stock figures, two ways (F11)** — "Integrate Accounts with
  Inventory" (Utility → Settings):
  - **On**: Opening/Closing Stock valued from stock items using each
    item's costing method.
  - **Off**: taken from Stock-in-hand ledgers — opening balance plus
    manually entered *dated* closing values (the value dated on or
    before the report date applies), exactly like Tally; such
    ledgers never appear in vouchers.
- **Reports** — Day Book, Ledger (with running balance and
  opening/current/closing totals), Cash/Bank Book, Group Summary,
  Stock Summary (opening/inwards/outwards/closing with valuation,
  drill-down to item movement register), Registers, List of
  Accounts, Address Book, Trial Balance and Final Reports (Profit &
  Loss, Balance Sheet with detailed/condensed views, Stock-in-hand
  and "Diff. In Opening Balance").
- **Report tools** — in-report search ("Type of info": Date,
  Particulars, Voucher Type, Debit/Credit Amount, Narration with
  Contains/Equals/Starts With/Ends With), report with narration,
  change period, export to Excel (CSV) and PDF (print).
- **Utility** — company edit, JSON backup, backup-and-mail, restore,
  delete company.

Data is stored client-side in `localStorage` — no server required.

## Development

```bash
npm install
npm run dev      # start dev server on :5173
npm run build    # type-check + production build to dist/
```

Built with Vite, React 18, TypeScript and react-router.
