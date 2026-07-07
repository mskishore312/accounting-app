import {
  AppData,
  DrCr,
  Group,
  Ledger,
  Period,
  Voucher,
} from './types'

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
): { particulars: string; debit: number; credit: number } {
  const drLines = v.lines.filter((l) => l.type === 'Dr')
  const crLines = v.lines.filter((l) => l.type === 'Cr')
  const total = drLines.reduce((s, l) => s + l.amount, 0)
  if (v.vchType === 'Receipt') {
    return {
      particulars: crLines.map((l) => nameOf(l.ledgerId)).join(', '),
      debit: 0,
      credit: total,
    }
  }
  if (v.vchType === 'Payment') {
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

export interface PLResult {
  left: Array<{ name: string; amount: number }>
  right: Array<{ name: string; amount: number }>
  totalLeft: number
  totalRight: number
  /** positive = profit */
  netProfit: number
}

function groupTotal(
  groups: Group[],
  ledgers: Ledger[],
  vouchers: Voucher[],
  p: Period,
  root: string,
): number {
  const names = groupsUnder(groups, [root])
  let sum = 0
  for (const l of ledgersInGroups(ledgers, names)) {
    sum += closingAt(vouchers, l, p)
  }
  return sum
}

export function profitAndLoss(
  groups: Group[],
  ledgers: Ledger[],
  vouchers: Voucher[],
  p: Period,
): PLResult {
  const purchase = groupTotal(groups, ledgers, vouchers, p, 'Purchase Accounts')
  const directExp = groupTotal(groups, ledgers, vouchers, p, 'Direct Expenses')
  const indirectExp = groupTotal(groups, ledgers, vouchers, p, 'Indirect Expenses')
  const sales = -groupTotal(groups, ledgers, vouchers, p, 'Sales Accounts')
  const directInc = -groupTotal(groups, ledgers, vouchers, p, 'Direct Incomes')
  const indirectInc = -groupTotal(groups, ledgers, vouchers, p, 'Indirect Income')
  const openingStock = 0
  const closingStock = groupTotal(groups, ledgers, vouchers, p, 'Stock-in-hand')

  const left = [
    { name: 'Opening Stock', amount: openingStock },
    { name: 'Purchase Accounts', amount: purchase },
    { name: 'Direct Expenses', amount: directExp },
    { name: 'Indirect Expenses', amount: indirectExp },
  ]
  const right = [
    { name: 'Sales Accounts', amount: sales },
    { name: 'Direct Incomes', amount: directInc },
    { name: 'Closing Stock', amount: closingStock },
    { name: 'Indirect Income', amount: indirectInc },
  ]
  const totalLeft = left.reduce((s, r) => s + r.amount, 0)
  const totalRight = right.reduce((s, r) => s + r.amount, 0)
  return {
    left,
    right,
    totalLeft,
    totalRight,
    netProfit: totalRight - totalLeft,
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
  vouchers: Voucher[],
  p: Period,
  detailed: boolean,
): BSResult {
  const block = (root: string, flip: boolean): BSGroupBlock => {
    const names = groupsUnder(groups, [root])
    const members = ledgersInGroups(ledgers, names)
    const children = members
      .map((l) => {
        const raw = closingAt(vouchers, l, p)
        return { name: l.name, amount: flip ? -raw : raw }
      })
      .filter((c) => c.amount !== 0)
    const amount = children.reduce((s, c) => s + c.amount, 0)
    return {
      name: root,
      amount,
      children: detailed ? children : [],
    }
  }

  const pl = profitAndLoss(groups, ledgers, vouchers, p)

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
