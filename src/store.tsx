import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from 'react'
import {
  AppData,
  Company,
  DEFAULT_GROUPS,
  Group,
  Ledger,
  Period,
  Voucher,
  VoucherType,
} from './types'

const STORAGE_KEY = 'accounting-app-data-v1'
const ACTIVE_KEY = 'accounting-app-active-company'
const PERIOD_KEY = 'accounting-app-periods'

export function uid(): string {
  return (
    Date.now().toString(36) + Math.random().toString(36).slice(2, 10)
  )
}

function loadData(): AppData {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (raw) return JSON.parse(raw) as AppData
  } catch {
    /* corrupted storage — start fresh */
  }
  return { companies: [], groups: [], ledgers: [], vouchers: [] }
}

function loadPeriods(): Record<string, Period> {
  try {
    const raw = localStorage.getItem(PERIOD_KEY)
    if (raw) return JSON.parse(raw)
  } catch {
    /* ignore */
  }
  return {}
}

interface StoreValue {
  data: AppData
  activeCompanyId: string | null
  company: Company | null
  period: Period
  setActiveCompany: (id: string | null) => void
  setPeriod: (p: Period) => void
  createCompany: (
    c: Omit<Company, 'id' | 'createdAt'>,
  ) => Company
  updateCompany: (id: string, patch: Partial<Company>) => void
  deleteCompany: (id: string) => void
  addGroup: (name: string, under: string) => Group | string
  addLedger: (
    l: Omit<Ledger, 'id' | 'companyId'>,
  ) => Ledger | string
  updateLedger: (id: string, patch: Partial<Ledger>) => void
  deleteLedger: (id: string) => string | null
  addVoucher: (
    v: Omit<Voucher, 'id' | 'companyId' | 'vchNo'>,
  ) => Voucher
  updateVoucher: (id: string, patch: Partial<Voucher>) => void
  deleteVoucher: (id: string) => void
  restoreData: (data: AppData) => void
  companyGroups: Group[]
  companyLedgers: Ledger[]
  companyVouchers: Voucher[]
  nextVchNo: (t: VoucherType) => number
}

const StoreContext = createContext<StoreValue | null>(null)

function defaultPeriodFor(company: Company | null): Period {
  if (!company) {
    return { from: '2023-04-01', to: '2025-03-31' }
  }
  const from = company.booksFrom || company.finYearFrom
  // period runs to the end of the *current* financial year
  const now = new Date()
  const endYear =
    now.getMonth() >= 3 ? now.getFullYear() + 1 : now.getFullYear()
  const to = `${endYear}-03-31`
  return { from, to: to > from ? to : from }
}

export function StoreProvider({
  children,
}: {
  children: React.ReactNode
}) {
  const [data, setData] = useState<AppData>(loadData)
  const [activeCompanyId, setActiveCompanyId] = useState<
    string | null
  >(() => localStorage.getItem(ACTIVE_KEY))
  const [periods, setPeriods] = useState<Record<string, Period>>(
    loadPeriods,
  )

  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(data))
  }, [data])

  useEffect(() => {
    if (activeCompanyId)
      localStorage.setItem(ACTIVE_KEY, activeCompanyId)
    else localStorage.removeItem(ACTIVE_KEY)
  }, [activeCompanyId])

  useEffect(() => {
    localStorage.setItem(PERIOD_KEY, JSON.stringify(periods))
  }, [periods])

  const company = useMemo(
    () =>
      data.companies.find((c) => c.id === activeCompanyId) ?? null,
    [data.companies, activeCompanyId],
  )

  const period = useMemo(() => {
    if (activeCompanyId && periods[activeCompanyId])
      return periods[activeCompanyId]
    return defaultPeriodFor(company)
  }, [activeCompanyId, periods, company])

  const setPeriod = useCallback(
    (p: Period) => {
      if (!activeCompanyId) return
      setPeriods((prev) => ({ ...prev, [activeCompanyId]: p }))
    },
    [activeCompanyId],
  )

  const createCompany: StoreValue['createCompany'] = useCallback(
    (c) => {
      const comp: Company = {
        ...c,
        id: uid(),
        createdAt: new Date().toISOString(),
      }
      const groups: Group[] = DEFAULT_GROUPS.map(
        ([name, under]) => ({
          id: uid(),
          companyId: comp.id,
          name,
          under,
          reserved: true,
        }),
      )
      const ledgers: Ledger[] = [
        {
          id: uid(),
          companyId: comp.id,
          name: 'Cash',
          under: 'Cash-in-hand',
          openingBalance: 0,
          openingType: 'Dr',
          reserved: true,
        },
        {
          id: uid(),
          companyId: comp.id,
          name: 'Profit & Loss A/c',
          under: 'Primary',
          openingBalance: 0,
          openingType: 'Dr',
          reserved: true,
        },
      ]
      setData((prev) => ({
        ...prev,
        companies: [...prev.companies, comp],
        groups: [...prev.groups, ...groups],
        ledgers: [...prev.ledgers, ...ledgers],
      }))
      return comp
    },
    [],
  )

  const updateCompany: StoreValue['updateCompany'] = useCallback(
    (id, patch) => {
      setData((prev) => ({
        ...prev,
        companies: prev.companies.map((c) =>
          c.id === id ? { ...c, ...patch } : c,
        ),
      }))
    },
    [],
  )

  const deleteCompany: StoreValue['deleteCompany'] = useCallback(
    (id) => {
      setData((prev) => ({
        companies: prev.companies.filter((c) => c.id !== id),
        groups: prev.groups.filter((g) => g.companyId !== id),
        ledgers: prev.ledgers.filter((l) => l.companyId !== id),
        vouchers: prev.vouchers.filter((v) => v.companyId !== id),
      }))
      setActiveCompanyId((cur) => (cur === id ? null : cur))
    },
    [],
  )

  const addGroup: StoreValue['addGroup'] = useCallback(
    (name, under) => {
      if (!activeCompanyId) return 'No company selected'
      const trimmed = name.trim()
      if (!trimmed) return 'Group name is required'
      const exists = data.groups.some(
        (g) =>
          g.companyId === activeCompanyId &&
          g.name.toLowerCase() === trimmed.toLowerCase(),
      )
      if (exists) return 'Group already exists'
      const g: Group = {
        id: uid(),
        companyId: activeCompanyId,
        name: trimmed,
        under,
        reserved: false,
      }
      setData((prev) => ({ ...prev, groups: [...prev.groups, g] }))
      return g
    },
    [activeCompanyId, data.groups],
  )

  const addLedger: StoreValue['addLedger'] = useCallback(
    (l) => {
      if (!activeCompanyId) return 'No company selected'
      const trimmed = l.name.trim()
      if (!trimmed) return 'Ledger name is required'
      const exists = data.ledgers.some(
        (x) =>
          x.companyId === activeCompanyId &&
          x.name.toLowerCase() === trimmed.toLowerCase(),
      )
      if (exists) return 'Ledger already exists'
      const led: Ledger = {
        ...l,
        name: trimmed,
        id: uid(),
        companyId: activeCompanyId,
      }
      setData((prev) => ({
        ...prev,
        ledgers: [...prev.ledgers, led],
      }))
      return led
    },
    [activeCompanyId, data.ledgers],
  )

  const updateLedger: StoreValue['updateLedger'] = useCallback(
    (id, patch) => {
      setData((prev) => ({
        ...prev,
        ledgers: prev.ledgers.map((l) =>
          l.id === id ? { ...l, ...patch } : l,
        ),
      }))
    },
    [],
  )

  const deleteLedger: StoreValue['deleteLedger'] = useCallback(
    (id) => {
      const used = data.vouchers.some((v) =>
        v.lines.some((ln) => ln.ledgerId === id),
      )
      if (used) return 'Ledger is used in vouchers'
      setData((prev) => ({
        ...prev,
        ledgers: prev.ledgers.filter((l) => l.id !== id),
      }))
      return null
    },
    [data.vouchers],
  )

  const nextVchNo: StoreValue['nextVchNo'] = useCallback(
    (t) => {
      if (!activeCompanyId) return 1
      const nums = data.vouchers
        .filter(
          (v) =>
            v.companyId === activeCompanyId && v.vchType === t,
        )
        .map((v) => v.vchNo)
      return nums.length ? Math.max(...nums) + 1 : 1
    },
    [activeCompanyId, data.vouchers],
  )

  const addVoucher: StoreValue['addVoucher'] = useCallback(
    (v) => {
      const vch: Voucher = {
        ...v,
        id: uid(),
        companyId: activeCompanyId!,
        vchNo: nextVchNo(v.vchType),
      }
      setData((prev) => ({
        ...prev,
        vouchers: [...prev.vouchers, vch],
      }))
      return vch
    },
    [activeCompanyId, nextVchNo],
  )

  const updateVoucher: StoreValue['updateVoucher'] = useCallback(
    (id, patch) => {
      setData((prev) => ({
        ...prev,
        vouchers: prev.vouchers.map((v) =>
          v.id === id ? { ...v, ...patch } : v,
        ),
      }))
    },
    [],
  )

  const deleteVoucher: StoreValue['deleteVoucher'] = useCallback(
    (id) => {
      setData((prev) => ({
        ...prev,
        vouchers: prev.vouchers.filter((v) => v.id !== id),
      }))
    },
    [],
  )

  const restoreData: StoreValue['restoreData'] = useCallback(
    (d) => {
      setData(d)
      setActiveCompanyId(null)
    },
    [],
  )

  const companyGroups = useMemo(
    () =>
      data.groups
        .filter((g) => g.companyId === activeCompanyId)
        .sort((a, b) => a.name.localeCompare(b.name)),
    [data.groups, activeCompanyId],
  )

  const companyLedgers = useMemo(
    () =>
      data.ledgers
        .filter((l) => l.companyId === activeCompanyId)
        .sort((a, b) => a.name.localeCompare(b.name)),
    [data.ledgers, activeCompanyId],
  )

  const companyVouchers = useMemo(
    () =>
      data.vouchers
        .filter((v) => v.companyId === activeCompanyId)
        .sort(
          (a, b) =>
            a.date.localeCompare(b.date) || a.vchNo - b.vchNo,
        ),
    [data.vouchers, activeCompanyId],
  )

  const value: StoreValue = {
    data,
    activeCompanyId,
    company,
    period,
    setActiveCompany: setActiveCompanyId,
    setPeriod,
    createCompany,
    updateCompany,
    deleteCompany,
    addGroup,
    addLedger,
    updateLedger,
    deleteLedger,
    addVoucher,
    updateVoucher,
    deleteVoucher,
    restoreData,
    companyGroups,
    companyLedgers,
    companyVouchers,
    nextVchNo,
  }

  return (
    <StoreContext.Provider value={value}>
      {children}
    </StoreContext.Provider>
  )
}

export function useStore(): StoreValue {
  const ctx = useContext(StoreContext)
  if (!ctx) throw new Error('useStore outside provider')
  return ctx
}
