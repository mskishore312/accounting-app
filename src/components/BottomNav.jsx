import React from 'react'

const tabs = [
  { id: 'home',    label: 'Home',    icon: '🏠' },
  { id: 'voucher', label: 'Voucher', icon: '📄' },
  { id: 'ledger',  label: 'Ledgers', icon: '📒' },
  { id: 'daybook', label: 'Day Book', icon: '📅' },
]

export default function BottomNav({ active, onChange }) {
  return (
    <nav className="bottom-nav">
      {tabs.map(t => (
        <button
          key={t.id}
          className={`nav-item ${active === t.id ? 'active' : ''}`}
          onClick={() => onChange(t.id)}
        >
          <span className="nav-icon">{t.icon}</span>
          <span className="nav-label">{t.label}</span>
        </button>
      ))}
    </nav>
  )
}
