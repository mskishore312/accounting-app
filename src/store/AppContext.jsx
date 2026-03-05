import React, { createContext, useContext, useState, useEffect } from 'react'
import { v4 as uuidv4 } from 'uuid'

const AppContext = createContext()

const DEFAULT_LEDGERS = [
  { id: uuidv4(), name: 'Cash', group: 'Cash-in-Hand', gstin: '', openingBalance: 0, balanceType: 'Dr' },
  { id: uuidv4(), name: 'Bank Account', group: 'Bank Accounts', gstin: '', openingBalance: 0, balanceType: 'Dr' },
  { id: uuidv4(), name: 'Sales', group: 'Sales Accounts', gstin: '', openingBalance: 0, balanceType: 'Cr' },
  { id: uuidv4(), name: 'Purchase', group: 'Purchase Accounts', gstin: '', openingBalance: 0, balanceType: 'Dr' },
  { id: uuidv4(), name: 'CGST', group: 'Duties & Taxes', gstin: '', openingBalance: 0, balanceType: 'Cr' },
  { id: uuidv4(), name: 'SGST', group: 'Duties & Taxes', gstin: '', openingBalance: 0, balanceType: 'Cr' },
  { id: uuidv4(), name: 'IGST', group: 'Duties & Taxes', gstin: '', openingBalance: 0, balanceType: 'Cr' },
]

function load(key, fallback) {
  try {
    const val = localStorage.getItem(key)
    return val ? JSON.parse(val) : fallback
  } catch {
    return fallback
  }
}

export function AppProvider({ children }) {
  const [ledgers, setLedgers] = useState(() => load('ledgers', DEFAULT_LEDGERS))
  const [vouchers, setVouchers] = useState(() => load('vouchers', []))

  useEffect(() => { localStorage.setItem('ledgers', JSON.stringify(ledgers)) }, [ledgers])
  useEffect(() => { localStorage.setItem('vouchers', JSON.stringify(vouchers)) }, [vouchers])

  function addLedger(data) {
    const ledger = { id: uuidv4(), ...data }
    setLedgers(prev => [...prev, ledger])
    return ledger
  }

  function deleteLedger(id) {
    setLedgers(prev => prev.filter(l => l.id !== id))
  }

  function addVoucher(data) {
    const voucher = { id: uuidv4(), createdAt: new Date().toISOString(), ...data }
    setVouchers(prev => [voucher, ...prev])
    return voucher
  }

  function deleteVoucher(id) {
    setVouchers(prev => prev.filter(v => v.id !== id))
  }

  function getLedgerById(id) {
    return ledgers.find(l => l.id === id)
  }

  function getVouchersByDate(date) {
    return vouchers.filter(v => v.date === date)
  }

  // Compute ledger balance from vouchers
  function getLedgerBalance(ledgerId) {
    const ledger = getLedgerById(ledgerId)
    if (!ledger) return 0
    let balance = ledger.openingBalance * (ledger.balanceType === 'Dr' ? 1 : -1)
    vouchers.forEach(v => {
      v.entries.forEach(e => {
        if (e.ledgerId === ledgerId) {
          balance += e.type === 'Dr' ? e.amount : -e.amount
        }
      })
    })
    return balance
  }

  return (
    <AppContext.Provider value={{
      ledgers, vouchers,
      addLedger, deleteLedger,
      addVoucher, deleteVoucher,
      getLedgerById, getVouchersByDate, getLedgerBalance
    }}>
      {children}
    </AppContext.Provider>
  )
}

export function useApp() {
  return useContext(AppContext)
}
