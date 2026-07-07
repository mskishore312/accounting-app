import {
  AppData,
  DrCr,
  Group,
  Ledger,
  Period,
  StockItem,
  Voucher,
} from './types'
import { closingStockValue } from './inventory'

export function fmt(n: number): string {
  return n.toLocaleString('en-IN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })
}

export function fmtDate(iso: string): string {
  if (!iso) return ''
  const [y, m, d] = iso.split('-')
  return `${d}/${m}/${y}`
}

export function inPeriod(date: string, p: Period): boolean {
  return date >= p.from && date <= p.to
}

/** Signed balance: positive = Dr, negative = Cr */
export function openingSigned(l: Ledger): number {
  return l.openingType === 'Dr'
    ? l.openingBalance
    : -l.openingBalance
}

export interface LedgerRow {
  voucher: Voucher
  /** the other side's ledger names, joined */
  particulars: string
  debit: number
  credit: number
  running: number
}

/** All group names that are (transitively) under the given root names. */
export function groupsUnder(
  groups: Group[],
  roots: string[],
): Set<string> {
  const result = new Set<string>(roots)
  let changed = true
  while (changed) {
    changed = false
    for (const g of groups) {
      if (!result.has(g.name) && result.has(g.under)) {
        result.add(g.name)
        changed = true
      }
    }
  }
  return result
}

export function ledgersInGroups(
  ledgers: Ledger[],
  groupNames: Set<string>,
): Ledger[] {
  return ledgers.filter((l) => groupNames.has(l.under))
}

/** Net movement (signed, +Dr) of a ledger from vouchers in [from..to] */
export function movement(
  vouchers: Voucher[],
  ledgerId: string,
  from: string | null,
  to: string,
): number {
  let sum = 0
  for (const v of vouchers) {
    if (from && v.date < from) continue
    if (v.date > to) continue
    for (const ln of v.lines) {
      if (ln.ledgerId !== ledgerId) continue
      sum += ln.type === 'Dr' ? ln.amount : -ln.amount
    }
  }
  return sum
}

/** Opening balance of a ledger as at the start of the period. */
export function openingAt(
  vouchers: Voucher[],
  l: Ledger,
  from: string,
): number {
  // opening + movement before the period start
  let sum = openingSigned(l)
  for (const v of vouchers) {
    if (v.date >= from) continue
    for (const ln of v.lines) {
      if (ln.ledgerId !== l.id) continue
      sum += ln.type === 'Dr' ? ln.amount : -ln.amount
    }
  }
  return sum
}

/** Closing balance (signed +Dr) of ledger at end of period incl. opening */
export function closingAt(
  vouchers: Voucher[],
  l: Ledger,
  p: Period,
): number {
  return (
    openingAt(vouchers, l, p.from) +
    movement(vouchers, l.id, p.from, p.to)
  )
}

export function drcr(n: number): DrCr {
  return n >= 0 ? 'Dr' : 'Cr'
}

export interface LedgerReport {
  rows: LedgerRow[]
  opening: number
  totalDebit: number
  totalCredit: number
  closing: number
}

export function buildLedgerReport(
  data: Pick<AppData, 'vouchers' | 'ledgers'>,
  companyVouchers: Voucher[],
  ledger: Ledger,
  p: Period,
): LedgerReport {
  const nameOf = (id: string) =>
    data.ledgers.find((l) => l.id === id)?.name ?? '?'
  const opening = openingAt(companyVouchers, ledger, p.from)
  let running = opening
  let totalDebit = 0
  let totalCredit = 0
  const rows: LedgerRow[] = []
  for (const v of companyVouchers) {
    if (!inPeriod(v.date, p)) continue
    const mine = v.lines.filter((ln) => ln.ledgerId === ledger.id)
    if (!mine.length) continue
    const others = v.lines
      .filter((ln) => ln.ledgerId !== ledger.id)
      .map((ln) => nameOf(ln.ledgerId))
    const debit = mine
      .filter((ln) => ln.type === 'Dr')
      .reduce((s, ln) => s + ln.amount, 0)
    const credit = mine
      .filter((ln) => ln.type === 'Cr')
      .reduce((s, ln) => s + ln.amount, 0)
    running += debit - credit
    totalDebit += debit
    totalCredit += credit
    rows.push({
      voucher: v,
      particulars: others.join(', ') || ledger.name,
      debit,
      credit,
      running,
    })
  }
  return { rows, opening, totalDebit, totalCredit, closing: running }
}

/** For Day Book rows: particulars = first credit ledger for receipts,
 * first debit ledger for others (Tally shows the "main" account). */
export function daybookParticulars(
  v: Voucher,
  nameOf: (id: string) => string,
  itemNameOf?: (id: string) => string,
): { particulars: string; debit: number; credit: number } {
  if (
    v.vchType === 'Stock Journal' ||
    v.vchType === 'Physical Stock'
  ) {
    const particulars = (v.invLines ?? [])
      .map((l) => (itemNameOf ? itemNameOf(l.itemId) : ''))
      .filter(Boolean)
      .join(', ')
    return { particulars, debit: 0, credit: 0 }
  }
  const drLines = v.lines.filter((l) => l.type === 'Dr')
  const crLines = v.lines.filter((l) => l.type === 'Cr')
  const total = drLines.reduce((s, l) => s + l.amount, 0)
  if (v.vchType === 'Receipt' || v.vchType === 'Credit Note') {
    return {
      particulars: crLines.map((l) => nameOf(l.ledgerId)).join(', '),
      debit: 0,
      credit: total,
    }
  }
  if (v.vchType === 'Payment' || v.vchType === 'Debit Note') {
    return {
      particulars: drLines.map((l) => nameOf(l.ledgerId)).join(', '),
      debit: total,
      credit: 0,
    }
  }
  return {
    particulars: drLines.map((l) => nameOf(l.ledgerId)).join(', '),
    debit: total,
    credit: total,
  }
}

export interface TrialRow {
  name: string
  debit: number
  credit: number
}

export function trialBalance(
  ledgers: Ledger[],
  vouchers: Voucher[],
  p: Period,
): { rows: TrialRow[]; totalDebit: number; totalCredit: number } {
  const rows: TrialRow[] = []
  for (const l of ledgers) {
    const bal = closingAt(vouchers, l, p)
    if (bal === 0 && l.openingBalance === 0) {
      // include ledgers with any activity even if net zero
      const active = vouchers.some(
        (v) =>
          inPeriod(v.date, p) &&
          v.lines.some((ln) => ln.ledgerId === l.id),
      )
      if (!active) continue
    }
    rows.push({
      name: l.name,
      debit: bal > 0 ? bal : 0,
      credit: bal < 0 ? -bal : 0,
    })
  }
  const totalDebit = rows.reduce((s, r) => s + r.debit, 0)
  const totalCredit = rows.reduce((s, r) => s + r.credit, 0)
  return { rows, totalDebit, totalCredit }
}

export interface PLRow {
  name: string
  amount: number
  children: Array<{ name: string; amount: number }>
  emphasis?: boolean
}

export interface PLResult {
  /** Trading section (determines Gross Profit) */
  tradingLeft: PLRow[]
  tradingRight: PLRow[]
  /** positive = gross profit (carried over) */
  grossProfit: number
  tradingTotal: number
  /** Income statement section */
  lowerLeft: PLRow[]
  lowerRight: PLRow[]
  /** positive = nett profit */
  netProfit: number
  lowerTotal: number
  openingStock: number
  closingStock: number
}

function groupRow(
  groups: Group[],
  ledgers: Ledger[],
  vouchers: Voucher[],
  p: Period,
  root: string,
  flip: boolean,
): PLRow {
  const names = groupsUnder(groups, [root])
  const children: Array<{ name: string; amount: number }> = []
  let sum = 0
  for (const l of ledgersInGroups(ledgers, names)) {
    const raw = closingAt(vouchers, l, p)
    const amt = flip ? -raw : raw
    sum += amt
    if (amt !== 0) children.push({ name: l.name, amount: amt })
  }
  return { name: root, amount: sum, children }
}

export interface StockFigures {
  openingStock: number
  closingStock: number
}

/**
 * Opening/Closing Stock per Tally's F11 "Integrate Accounts with
 * Inventory":
 *  - integrated: valued from stock items (per-item costing method);
 *  - manual: taken from Stock-in-hand ledgers — opening balances,
 *    plus dated closing balance entries (latest entry whose
 *    date <= report date wins; entries strictly before the period
 *    start feed the opening figure).
 */
export function stockFigures(
  groups: Group[],
  ledgers: Ledger[],
  stockItems: StockItem[],
  vouchers: Voucher[],
  p: Period,
  integrate: boolean,
): StockFigures {
  if (integrate) {
    return {
      openingStock: closingStockValue(
        stockItems,
        vouchers,
        p.from,
        true,
      ),
      closingStock: closingStockValue(stockItems, vouchers, p.to),
    }
  }
  const names = groupsUnder(groups, ['Stock-in-hand'])
  const stockLedgers = ledgers.filter((l) => names.has(l.under))
  const valueAsOn = (l: Ledger, date: string, exclusive: boolean) => {
    const entries = (l.closingBalances ?? [])
      .filter((e) => (exclusive ? e.date < date : e.date <= date))
      .sort((a, b) => a.date.localeCompare(b.date))
    if (entries.length) return entries[entries.length - 1].value
    return openingSigned(l)
  }
  return {
    openingStock: stockLedgers.reduce(
      (s, l) => s + valueAsOn(l, p.from, true),
      0,
    ),
    closingStock: stockLedgers.reduce(
      (s, l) => s + valueAsOn(l, p.to, false),
      0,
    ),
  }
}

export function profitAndLoss(
  groups: Group[],
  ledgers: Ledger[],
  stockItems: StockItem[],
  vouchers: Voucher[],
  p: Period,
  integrate: boolean,
): PLResult {
  const row = (root: string, flip: boolean) =>
    groupRow(groups, ledgers, vouchers, p, root, flip)

  const purchases = row('Purchase Accounts', false)
  const directExp = row('Direct Expenses', false)
  const indirectExp = row('Indirect Expenses', false)
  const sales = row('Sales Accounts', true)
  const directInc = row('Direct Incomes', true)
  const indirectInc = row('Indirect Income', true)

  const { openingStock, closingStock } = stockFigures(
    groups,
    ledgers,
    stockItems,
    vouchers,
    p,
    integrate,
  )

  // Trading account: Gross Profit
  const tradingDr =
    openingStock + purchases.amount + directExp.amount
  const tradingCr =
    sales.amount + directInc.amount + closingStock
  const grossProfit = tradingCr - tradingDr

  const tradingLeft: PLRow[] = [
    { name: 'Opening Stock', amount: openingStock, children: [] },
    purchases,
    directExp,
  ]
  const tradingRight: PLRow[] = [
    sales,
    directInc,
    { name: 'Closing Stock', amount: closingStock, children: [] },
  ]
  if (grossProfit >= 0)
    tradingLeft.push({
      name: 'Gross Profit c/o',
      amount: grossProfit,
      children: [],
      emphasis: true,
    })
  else
    tradingRight.push({
      name: 'Gross Loss c/o',
      amount: -grossProfit,
      children: [],
      emphasis: true,
    })
  const tradingTotal = Math.max(tradingDr, tradingCr)

  // Income statement: Nett Profit
  const netProfit =
    grossProfit + indirectInc.amount - indirectExp.amount
  const lowerLeft: PLRow[] = []
  const lowerRight: PLRow[] = []
  if (grossProfit >= 0)
    lowerRight.push({
      name: 'Gross Profit b/f',
      amount: grossProfit,
      children: [],
      emphasis: true,
    })
  else
    lowerLeft.push({
      name: 'Gross Loss b/f',
      amount: -grossProfit,
      children: [],
      emphasis: true,
    })
  lowerLeft.push(indirectExp)
  lowerRight.push(indirectInc)
  if (netProfit >= 0)
    lowerLeft.push({
      name: 'Nett Profit',
      amount: netProfit,
      children: [],
      emphasis: true,
    })
  else
    lowerRight.push({
      name: 'Nett Loss',
      amount: -netProfit,
      children: [],
      emphasis: true,
    })
  const lowerTotal = Math.max(
    lowerLeft.reduce((s, r) => s + r.amount, 0),
    lowerRight.reduce((s, r) => s + r.amount, 0),
  )

  return {
    tradingLeft,
    tradingRight,
    grossProfit,
    tradingTotal,
    lowerLeft,
    lowerRight,
    netProfit,
    lowerTotal,
    openingStock,
    closingStock,
  }
}

export interface BSGroupBlock {
  name: string
  amount: number
  children: Array<{ name: string; amount: number }>
}

export interface BSResult {
  liabilities: BSGroupBlock[]
  assets: BSGroupBlock[]
  diffOpening: number
  netProfit: number
  totalLiabilities: number
  totalAssets: number
}

const LIABILITY_ROOTS = [
  'Capital Account',
  'Loans (Liability)',
  'Current Liabilities',
  'Suspense A/c',
  'Branch / Division',
]
const ASSET_ROOTS = [
  'Fixed Assets',
  'Investments',
  'Current Assets',
  'Misc. Expenses (ASSET)',
]

export function balanceSheet(
  groups: Group[],
  ledgers: Ledger[],
  stockItems: StockItem[],
  vouchers: Voucher[],
  p: Period,
  detailed: boolean,
  integrate: boolean,
): BSResult {
  // Stock-in-hand ledgers are pure valuation carriers — their value
  // comes from stockFigures, never from postings.
  const stockNames = groupsUnder(groups, ['Stock-in-hand'])

  const block = (root: string, flip: boolean): BSGroupBlock => {
    const names = groupsUnder(groups, [root])
    const members = ledgersInGroups(ledgers, names).filter(
      (l) => !stockNames.has(l.under),
    )
    const children = members
      .map((l) => {
        const raw = closingAt(vouchers, l, p)
        return { name: l.name, amount: flip ? -raw : raw }
      })
      .filter((c) => c.amount !== 0)
    let amount = children.reduce((s, c) => s + c.amount, 0)
    if (root === 'Current Assets') {
      const { closingStock } = stockFigures(
        groups,
        ledgers,
        stockItems,
        vouchers,
        p,
        integrate,
      )
      if (closingStock !== 0) {
        children.unshift({
          name: 'Stock-in-hand',
          amount: closingStock,
        })
        amount += closingStock
      }
    }
    return {
      name: root,
      amount,
      children: detailed ? children : [],
    }
  }

  const pl = profitAndLoss(
    groups,
    ledgers,
    stockItems,
    vouchers,
    p,
    integrate,
  )

  // The reference design always shows these groups, even at zero;
  // other groups appear only when they carry a balance.
  const ALWAYS_L = [
    'Capital Account',
    'Loans (Liability)',
    'Current Liabilities',
  ]
  const ALWAYS_A = ['Fixed Assets', 'Current Assets']

  const liabilities = LIABILITY_ROOTS.map((r) => block(r, true)).filter(
    (b) => ALWAYS_L.includes(b.name) || b.amount !== 0,
  )
  // Investments appear on the liabilities side in the reference design,
  // but accounting-wise they are assets; follow the design order:
  const investments = block('Investments', false)
  liabilities.splice(3, 0, investments)

  const assets = ASSET_ROOTS.filter((r) => r !== 'Investments')
    .map((r) => block(r, false))
    .filter((b) => ALWAYS_A.includes(b.name) || b.amount !== 0)

  // P&L for the period sits on the liabilities side (profit) as
  // Profit & Loss A/c; the reserved P&L ledger holds carried balance.
  const plLedger = ledgers.find((l) => l.name === 'Profit & Loss A/c')
  const plCarried = plLedger
    ? -closingAt(vouchers, plLedger, p)
    : 0
  const plTotal = plCarried + pl.netProfit

  const totalLiabRaw =
    liabilities.reduce((s, b) => s + b.amount, 0) + plTotal
  const totalAssetsRaw = assets.reduce((s, b) => s + b.amount, 0)

  // Difference in opening balances balances the sheet
  const diffOpening = totalAssetsRaw - totalLiabRaw

  return {
    liabilities,
    assets,
    diffOpening,
    netProfit: plTotal,
    totalLiabilities: totalLiabRaw + diffOpening,
    totalAssets: totalAssetsRaw,
  }
}
