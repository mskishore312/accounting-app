import React, { useState, useEffect } from 'react'
import { useApp } from '../store/AppContext'

const VOUCHER_TYPES = ['Sales', 'Purchase', 'Receipt', 'Payment', 'Journal', 'Contra']
const GST_RATES = [0, 5, 12, 18, 28]

const DEBIT_LEDGER_GROUPS = {
  Sales:    ['Sundry Debtors', 'Cash-in-Hand', 'Bank Accounts'],
  Purchase: ['Purchase Accounts'],
  Receipt:  ['Cash-in-Hand', 'Bank Accounts'],
  Payment:  ['Sundry Creditors', 'Expenses (Direct)', 'Expenses (Indirect)'],
  Journal:  null,
  Contra:   ['Cash-in-Hand', 'Bank Accounts'],
}

export default function VoucherEntry({ initialType, onSuccess }) {
  const { ledgers, addVoucher, vouchers } = useApp()

  const [type, setType] = useState(initialType || 'Sales')
  const [date, setDate] = useState(new Date().toISOString().split('T')[0])
  const [partyLedgerId, setPartyLedgerId] = useState('')
  const [accountLedgerId, setAccountLedgerId] = useState('')
  const [amount, setAmount] = useState('')
  const [gstRate, setGstRate] = useState(18)
  const [applyGst, setApplyGst] = useState(false)
  const [isInterState, setIsInterState] = useState(false)
  const [narration, setNarration] = useState('')
  const [saved, setSaved] = useState(false)

  useEffect(() => {
    setType(initialType || 'Sales')
  }, [initialType])

  // Auto-select first matching party ledger
  const partyGroups = {
    Sales: ['Sundry Debtors', 'Cash-in-Hand', 'Bank Accounts'],
    Purchase: ['Sundry Creditors', 'Cash-in-Hand', 'Bank Accounts'],
    Receipt: ['Sundry Debtors'],
    Payment: ['Sundry Creditors'],
    Journal: null,
    Contra: ['Cash-in-Hand', 'Bank Accounts'],
  }

  const accountGroups = {
    Sales: ['Sales Accounts'],
    Purchase: ['Purchase Accounts'],
    Receipt: ['Cash-in-Hand', 'Bank Accounts'],
    Payment: ['Cash-in-Hand', 'Bank Accounts'],
    Journal: null,
    Contra: ['Cash-in-Hand', 'Bank Accounts'],
  }

  const filterLedgers = (groups) => {
    if (!groups) return ledgers
    return ledgers.filter(l => groups.includes(l.group))
  }

  const partyOptions = filterLedgers(partyGroups[type])
  const accountOptions = filterLedgers(accountGroups[type])

  function getNextVoucherNo() {
    const prefix = type.substring(0, 3).toUpperCase()
    const matching = vouchers.filter(v => v.type === type)
    return `${prefix}-${String(matching.length + 1).padStart(4, '0')}`
  }

  function calcGst(baseAmount) {
    if (!applyGst || gstRate === 0) return { cgst: 0, sgst: 0, igst: 0, total: baseAmount }
    const taxAmount = (baseAmount * gstRate) / 100
    if (isInterState) return { cgst: 0, sgst: 0, igst: taxAmount, total: baseAmount + taxAmount }
    const half = taxAmount / 2
    return { cgst: half, sgst: half, igst: 0, total: baseAmount + taxAmount }
  }

  function handleSubmit(e) {
    e.preventDefault()
    const base = parseFloat(amount) || 0
    if (base <= 0) return
    const gst = calcGst(base)

    const entries = []

    if (type === 'Sales') {
      if (partyLedgerId) entries.push({ ledgerId: partyLedgerId, amount: gst.total, type: 'Dr' })
      if (accountLedgerId) entries.push({ ledgerId: accountLedgerId, amount: base, type: 'Cr' })
    } else if (type === 'Purchase') {
      if (accountLedgerId) entries.push({ ledgerId: accountLedgerId, amount: base, type: 'Dr' })
      if (partyLedgerId) entries.push({ ledgerId: partyLedgerId, amount: gst.total, type: 'Cr' })
    } else if (type === 'Receipt') {
      if (accountLedgerId) entries.push({ ledgerId: accountLedgerId, amount: base, type: 'Dr' })
      if (partyLedgerId) entries.push({ ledgerId: partyLedgerId, amount: base, type: 'Cr' })
    } else if (type === 'Payment') {
      if (partyLedgerId) entries.push({ ledgerId: partyLedgerId, amount: base, type: 'Dr' })
      if (accountLedgerId) entries.push({ ledgerId: accountLedgerId, amount: base, type: 'Cr' })
    }

    addVoucher({
      type, date, narration,
      voucherNo: getNextVoucherNo(),
      baseAmount: base,
      gstRate: applyGst ? gstRate : 0,
      cgst: gst.cgst, sgst: gst.sgst, igst: gst.igst,
      totalAmount: gst.total,
      entries,
    })

    setSaved(true)
    setTimeout(() => {
      setSaved(false)
      setAmount('')
      setNarration('')
      setPartyLedgerId('')
      setAccountLedgerId('')
      if (onSuccess) onSuccess()
    }, 1200)
  }

  const gst = calcGst(parseFloat(amount) || 0)
  const fmt = n => '₹' + n.toLocaleString('en-IN', { minimumFractionDigits: 2 })

  return (
    <div className="page">
      <div className="page-header">
        <h1 className="page-title">Voucher Entry</h1>
      </div>

      {saved && <div className="success-toast">✓ Voucher saved!</div>}

      <form onSubmit={handleSubmit} className="form">
        {/* Type selector */}
        <div className="field">
          <label className="label">Voucher Type</label>
          <div className="type-tabs">
            {VOUCHER_TYPES.map(t => (
              <button
                key={t} type="button"
                className={`type-tab ${type === t ? 'active' : ''}`}
                onClick={() => { setType(t); setPartyLedgerId(''); setAccountLedgerId('') }}
              >
                {t}
              </button>
            ))}
          </div>
        </div>

        <div className="field-row">
          <div className="field flex-1">
            <label className="label">Date</label>
            <input className="input" type="date" value={date} onChange={e => setDate(e.target.value)} required />
          </div>
          <div className="field flex-1">
            <label className="label">Voucher No</label>
            <input className="input" type="text" value={getNextVoucherNo()} readOnly />
          </div>
        </div>

        {/* Party */}
        <div className="field">
          <label className="label">
            {type === 'Sales' ? 'Customer' : type === 'Purchase' ? 'Supplier' :
             type === 'Receipt' ? 'Received From' : type === 'Payment' ? 'Paid To' : 'Party'}
          </label>
          <select className="input" value={partyLedgerId} onChange={e => setPartyLedgerId(e.target.value)} required>
            <option value="">-- Select --</option>
            {partyOptions.map(l => <option key={l.id} value={l.id}>{l.name}</option>)}
          </select>
        </div>

        {/* Account */}
        <div className="field">
          <label className="label">
            {type === 'Sales' ? 'Sales Ledger' : type === 'Purchase' ? 'Purchase Ledger' :
             type === 'Receipt' || type === 'Payment' ? 'Bank / Cash' : 'Account'}
          </label>
          <select className="input" value={accountLedgerId} onChange={e => setAccountLedgerId(e.target.value)} required>
            <option value="">-- Select --</option>
            {accountOptions.map(l => <option key={l.id} value={l.id}>{l.name}</option>)}
          </select>
        </div>

        {/* Amount */}
        <div className="field">
          <label className="label">Amount (₹)</label>
          <input
            className="input input-large"
            type="number" inputMode="decimal"
            placeholder="0.00"
            value={amount}
            onChange={e => setAmount(e.target.value)}
            min="0" step="0.01" required
          />
        </div>

        {/* GST */}
        {(type === 'Sales' || type === 'Purchase') && (
          <div className="gst-section">
            <div className="toggle-row">
              <label className="label">Apply GST</label>
              <button
                type="button"
                className={`toggle-btn ${applyGst ? 'on' : 'off'}`}
                onClick={() => setApplyGst(!applyGst)}
              >
                {applyGst ? 'ON' : 'OFF'}
              </button>
            </div>

            {applyGst && (
              <>
                <div className="field">
                  <label className="label">GST Rate</label>
                  <div className="gst-rate-tabs">
                    {GST_RATES.map(r => (
                      <button
                        key={r} type="button"
                        className={`gst-tab ${gstRate === r ? 'active' : ''}`}
                        onClick={() => setGstRate(r)}
                      >
                        {r}%
                      </button>
                    ))}
                  </div>
                </div>

                <div className="toggle-row">
                  <label className="label">Inter-State (IGST)</label>
                  <button
                    type="button"
                    className={`toggle-btn ${isInterState ? 'on' : 'off'}`}
                    onClick={() => setIsInterState(!isInterState)}
                  >
                    {isInterState ? 'Yes' : 'No'}
                  </button>
                </div>

                {amount && parseFloat(amount) > 0 && (
                  <div className="gst-breakdown">
                    <div className="gst-row"><span>Base Amount</span><span>{fmt(parseFloat(amount))}</span></div>
                    {isInterState
                      ? <div className="gst-row"><span>IGST ({gstRate}%)</span><span>{fmt(gst.igst)}</span></div>
                      : <>
                          <div className="gst-row"><span>CGST ({gstRate/2}%)</span><span>{fmt(gst.cgst)}</span></div>
                          <div className="gst-row"><span>SGST ({gstRate/2}%)</span><span>{fmt(gst.sgst)}</span></div>
                        </>
                    }
                    <div className="gst-row total"><span>Total</span><span>{fmt(gst.total)}</span></div>
                  </div>
                )}
              </>
            )}
          </div>
        )}

        {/* Narration */}
        <div className="field">
          <label className="label">Narration</label>
          <textarea
            className="input"
            rows={2}
            placeholder="Optional note..."
            value={narration}
            onChange={e => setNarration(e.target.value)}
          />
        </div>

        <button type="submit" className="submit-btn">Save Voucher</button>
      </form>
    </div>
  )
}
