export type DrCr = 'Dr' | 'Cr'

export type VoucherType =
  | 'Receipt'
  | 'Payment'
  | 'Journal'
  | 'Contra'
  | 'Sales'
  | 'Purchase'
  | 'Debit Note'
  | 'Credit Note'
  | 'Stock Journal'
  | 'Physical Stock'

/** Accounting vouchers (two-ledger entry) */
export const VOUCHER_TYPES: VoucherType[] = [
  'Receipt',
  'Payment',
  'Journal',
  'Contra',
  'Sales',
  'Purchase',
  'Debit Note',
  'Credit Note',
]

/** Inventory-only vouchers (no ledger postings) */
export const INVENTORY_VOUCHER_TYPES: VoucherType[] = [
  'Stock Journal',
  'Physical Stock',
]

export const ALL_VOUCHER_TYPES: VoucherType[] = [
  ...VOUCHER_TYPES,
  ...INVENTORY_VOUCHER_TYPES,
]

export function vchSlug(t: VoucherType): string {
  return t.toLowerCase().replace(/\s+/g, '-')
}

export function vchFromSlug(slug: string): VoucherType {
  return (
    ALL_VOUCHER_TYPES.find((t) => vchSlug(t) === slug) ?? 'Receipt'
  )
}


export interface Company {
  id: string
  name: string
  address: string
  contactNo: string
  tinGst: string
  state: string
  security: boolean
  finYearFrom: string // ISO date
  booksFrom: string // ISO date
  createdAt: string
  /**
   * F11 feature: Integrate Accounts with Inventory.
   * true  → Opening/Closing Stock in P&L and BS come from stock item
   *         valuation.
   * false → they come from manually entered values on ledgers under
   *         Stock-in-hand (opening balance + dated closing balances),
   *         and those ledgers are excluded from voucher entry.
   */
  integrateInventory?: boolean
}

export interface Group {
  id: string
  companyId: string
  name: string
  /** Parent group name, or 'Primary' */
  under: string
  /** true for the 28 built-in Tally groups */
  reserved: boolean
}

export interface Ledger {
  id: string
  companyId: string
  name: string
  /** Group name this ledger belongs to */
  under: string
  openingBalance: number
  openingType: DrCr
  tinGst?: string
  address?: string
  contactNo?: string
  /** true for auto-created ledgers (Cash, Profit & Loss A/c) */
  reserved?: boolean
  /**
   * Stock-in-hand ledgers only: manually entered closing stock
   * values as on date (Tally style). A report as on date D uses the
   * value of the latest entry whose date <= D, falling back to the
   * opening balance.
   */
  closingBalances?: Array<{ date: string; value: number }>
}

export interface VoucherLine {
  ledgerId: string
  type: DrCr
  amount: number
}

export interface InventoryLine {
  itemId: string
  qty: number
  rate: number
  amount: number
  /**
   * Stock Journal only: 'out' = consumption (source), 'in' =
   * production (destination). Other voucher types derive direction
   * from the voucher type itself.
   */
  dir?: 'in' | 'out'
}

export interface Voucher {
  id: string
  companyId: string
  vchType: VoucherType
  vchNo: number
  date: string // ISO date
  lines: VoucherLine[]
  /** stock item allocations (Sales/Purchase/Debit Note/Credit Note) */
  invLines?: InventoryLine[]
  narration: string
}

export interface Unit {
  id: string
  companyId: string
  /** e.g. "Nos", "Kg" */
  symbol: string
  formalName: string
}

export interface StockGroup {
  id: string
  companyId: string
  name: string
  under: string // parent stock-group name or 'Primary'
}

export type ValuationMethod =
  | 'Avg. Cost'
  | 'FIFO'
  | 'LIFO'
  | 'Last Purchase Cost'
  | 'Std. Cost'
  | 'At Zero Cost'

export const VALUATION_METHODS: ValuationMethod[] = [
  'Avg. Cost',
  'FIFO',
  'LIFO',
  'Last Purchase Cost',
  'Std. Cost',
  'At Zero Cost',
]

export interface StockItem {
  id: string
  companyId: string
  name: string
  group: string // stock-group name or 'Primary'
  unit: string // unit symbol
  openingQty: number
  openingRate: number
  /** Costing method for closing stock; Tally default is Avg. Cost */
  valuation?: ValuationMethod
  /** Standard cost rate, used by the Std. Cost method */
  stdCost?: number
}

export interface Period {
  from: string
  to: string
}

export interface AppData {
  companies: Company[]
  groups: Group[]
  ledgers: Ledger[]
  vouchers: Voucher[]
  units: Unit[]
  stockGroups: StockGroup[]
  stockItems: StockItem[]
}

/** The 28 default Tally account-master groups: [name, under] */
export const DEFAULT_GROUPS: Array<[string, string]> = [
  ['Bank Accounts', 'Current Assets'],
  ['Bank OD A/c', 'Loans (Liability)'],
  ['Branch / Division', 'Primary'],
  ['Capital Account', 'Primary'],
  ['Cash-in-hand', 'Current Assets'],
  ['Current Assets', 'Primary'],
  ['Current Liabilities', 'Primary'],
  ['Deposits (Assets)', 'Current Assets'],
  ['Direct Expenses', 'Primary'],
  ['Direct Incomes', 'Primary'],
  ['Duties & Taxes', 'Current Liabilities'],
  ['Fixed Assets', 'Primary'],
  ['Indirect Expenses', 'Primary'],
  ['Indirect Income', 'Primary'],
  ['Investments', 'Primary'],
  ['Loans & Advances (Asset)', 'Current Assets'],
  ['Loans (Liability)', 'Primary'],
  ['Misc. Expenses (ASSET)', 'Primary'],
  ['Provisions', 'Current Liabilities'],
  ['Purchase Accounts', 'Primary'],
  ['Reserves & Surplus', 'Capital Account'],
  ['Sales Accounts', 'Primary'],
  ['Secured Loans', 'Loans (Liability)'],
  ['Stock-in-hand', 'Current Assets'],
  ['Sundry Creditors', 'Current Liabilities'],
  ['Sundry Debtors', 'Current Assets'],
  ['Suspense A/c', 'Primary'],
  ['Unsecured Loans', 'Loans (Liability)'],
]

export const INDIAN_STATES = [
  'Andaman and Nicobar (AN)',
  'Andhra Pradesh (AP)',
  'Arunachal Pradesh (AR)',
  'Assam (AS)',
  'Bihar (BR)',
  'Chandigarh (CH)',
  'Chhattisgarh (CG)',
  'Dadra and Nagar Haveli (DN)',
  'Daman and Diu (DD)',
  'Delhi (DL)',
  'Goa (GA)',
  'Gujarat (GJ)',
  'Haryana (HR)',
  'Himachal Pradesh (HP)',
  'Jammu and Kashmir (JK)',
  'Jharkhand (JH)',
  'Karnataka (KA)',
  'Kerala (KL)',
  'Ladakh (LA)',
  'Lakshadweep (LD)',
  'Madhya Pradesh (MP)',
  'Maharashtra (MH)',
  'Manipur (MN)',
  'Meghalaya (ML)',
  'Mizoram (MZ)',
  'Nagaland (NL)',
  'Odisha (OD)',
  'Puducherry (PY)',
  'Punjab (PB)',
  'Rajasthan (RJ)',
  'Sikkim (SK)',
  'Tamil Nadu (TN)',
  'Telangana (TS)',
  'Tripura (TR)',
  'Uttar Pradesh (UP)',
  'Uttarakhand (UK)',
  'West Bengal (WB)',
]
