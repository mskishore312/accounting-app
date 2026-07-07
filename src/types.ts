export type DrCr = 'Dr' | 'Cr'

export type VoucherType =
  | 'Receipt'
  | 'Payment'
  | 'Journal'
  | 'Contra'
  | 'Sales'
  | 'Purchase'

export const VOUCHER_TYPES: VoucherType[] = [
  'Receipt',
  'Payment',
  'Journal',
  'Contra',
  'Sales',
  'Purchase',
]

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
}

export interface VoucherLine {
  ledgerId: string
  type: DrCr
  amount: number
}

export interface Voucher {
  id: string
  companyId: string
  vchType: VoucherType
  vchNo: number
  date: string // ISO date
  lines: VoucherLine[]
  narration: string
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
