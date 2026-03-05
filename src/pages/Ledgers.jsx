import React, { useState } from 'react'
import { useApp } from '../store/AppContext'

const GROUPS = [
  'Cash-in-Hand', 'Bank Accounts',
  'Sundry Debtors', 'Sundry Creditors',
  'Sales Accounts', 'Purchase Accounts',
  'Duties & Taxes',
  'Expenses (Direct)', 'Expenses (Indirect)',
  'Fixed Assets', 'Capital Account',
]

export default function Ledgers() {
  const { ledgers, addLedger, deleteLedger, getLedgerBalance } = useApp()
  const [showForm, setShowForm] = useState(false)
  const [search, setSearch] = useState('')
  const [form, setForm] = useState({ name: '', group: 'Sundry Debtors', gstin: '', openingBalance: '', balanceType: 'Dr' })

  function handleSubmit(e) {
    e.preventDefault()
    if (!form.name.trim()) return
    addLedger({ ...form, openingBalance: parseFloat(form.openingBalance) || 0 })
    setForm({ name: '', group: 'Sundry Debtors', gstin: '', openingBalance: '', balanceType: 'Dr' })
    setShowForm(false)
  }

  const filtered = ledgers.filter(l => l.name.toLowerCase().includes(search.toLowerCase()))

  const fmt = n => '₹' + Math.abs(n).toLocaleString('en-IN', { minimumFractionDigits: 2 })

  return (
    <div className="page">
      <div className="page-header">
        <h1 className="page-title">Ledgers</h1>
        <button className="header-btn" onClick={() => setShowForm(!showForm)}>
          {showForm ? '✕ Cancel' : '+ New'}
        </button>
      </div>

      {showForm && (
        <form onSubmit={handleSubmit} className="form card">
          <div className="field">
            <label className="label">Ledger Name *</label>
            <input className="input" placeholder="e.g. Ramesh Traders" value={form.name}
              onChange={e => setForm({ ...form, name: e.target.value })} required />
          </div>
          <div className="field">
            <label className="label">Group *</label>
            <select className="input" value={form.group} onChange={e => setForm({ ...form, group: e.target.value })}>
              {GROUPS.map(g => <option key={g} value={g}>{g}</option>)}
            </select>
          </div>
          <div className="field">
            <label className="label">GSTIN</label>
            <input className="input" placeholder="22AAAAA0000A1Z5" value={form.gstin}
              onChange={e => setForm({ ...form, gstin: e.target.value.toUpperCase() })} maxLength={15} />
          </div>
          <div className="field-row">
            <div className="field flex-1">
              <label className="label">Opening Balance (₹)</label>
              <input className="input" type="number" inputMode="decimal" placeholder="0.00"
                value={form.openingBalance} onChange={e => setForm({ ...form, openingBalance: e.target.value })} />
            </div>
            <div className="field">
              <label className="label">Type</label>
              <div className="type-tabs">
                {['Dr', 'Cr'].map(t => (
                  <button key={t} type="button"
                    className={`type-tab ${form.balanceType === t ? 'active' : ''}`}
                    onClick={() => setForm({ ...form, balanceType: t })}>{t}</button>
                ))}
              </div>
            </div>
          </div>
          <button type="submit" className="submit-btn">Add Ledger</button>
        </form>
      )}

      <input className="search-input" placeholder="🔍  Search ledgers..." value={search}
        onChange={e => setSearch(e.target.value)} />

      <div className="ledger-list">
        {filtered.map(l => {
          const bal = getLedgerBalance(l.id)
          return (
            <div key={l.id} className="ledger-item">
              <div className="ledger-info">
                <div className="ledger-name">{l.name}</div>
                <div className="ledger-group">{l.group}</div>
                {l.gstin && <div className="ledger-gstin">GSTIN: {l.gstin}</div>}
              </div>
              <div className="ledger-right">
                <div className={`ledger-balance ${bal >= 0 ? 'dr' : 'cr'}`}>
                  {fmt(bal)} <span className="bal-type">{bal >= 0 ? 'Dr' : 'Cr'}</span>
                </div>
                <button className="delete-btn" onClick={() => deleteLedger(l.id)}>🗑</button>
              </div>
            </div>
          )
        })}
        {filtered.length === 0 && <div className="empty-state">No ledgers found.</div>}
      </div>
    </div>
  )
}
