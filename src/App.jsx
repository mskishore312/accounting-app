import React, { useState } from 'react'
import { AppProvider } from './store/AppContext'
import BottomNav from './components/BottomNav'
import Home from './pages/Home'
import VoucherEntry from './pages/VoucherEntry'
import Ledgers from './pages/Ledgers'
import DayBook from './pages/DayBook'

export default function App() {
  const [tab, setTab] = useState('home')
  const [voucherType, setVoucherType] = useState(null)

  function handleNavigate(page, opts = {}) {
    if (page === 'voucher' && opts.type) setVoucherType(opts.type)
    setTab(page)
  }

  function handleTabChange(t) {
    setTab(t)
    if (t !== 'voucher') setVoucherType(null)
  }

  return (
    <AppProvider>
      <div className="app">
        <main className="main-content">
          {tab === 'home'    && <Home onNavigate={handleNavigate} />}
          {tab === 'voucher' && <VoucherEntry initialType={voucherType} onSuccess={() => setTab('home')} />}
          {tab === 'ledger'  && <Ledgers />}
          {tab === 'daybook' && <DayBook />}
        </main>
        <BottomNav active={tab} onChange={handleTabChange} />
      </div>
    </AppProvider>
  )
}
