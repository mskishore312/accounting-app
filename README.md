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
- **Vouchers** — Receipt, Payment, Journal, Contra, Sales and
  Purchase vouchers with per-type auto numbering, ledger pickers
  (cash/bank restricted where appropriate), narration, edit and
  delete. Contra is restricted to cash/bank ledgers.
- **Reports** — Day Book, Ledger (with running balance and
  opening/current/closing totals), Cash/Bank Book, Group Summary,
  Registers, List of Accounts, Address Book, Trial Balance and Final
  Reports (Profit & Loss, Balance Sheet with detailed/condensed
  views and "Diff. In Opening Balance").
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
