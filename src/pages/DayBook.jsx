import React, { useState } from 'react'
import { useApp } from '../store/AppContext'

export default function DayBook() {
  const { vouchers, getLedgerById, deleteVoucher } = useApp()
  const [date, setDate] = useState(new Date().toISOString().split('T')[0])
  const [expanded, setExpanded] = useState(null)

  const dayVouchers = vouchers.filter(v => v.date === date)

  const totalDebit = dayVouchers.reduce((sum, v) =>
    sum + v.entries.filter(e => e.type === 'Dr').reduce((s, e) => s + e.amount, 0), 0)

  const fmt = n => '₹' + n.toLocaleString('en-IN', { minimumFractionDigits: 2 })

  const TYPE_COLORS = {
    sales: '#2e7d32', purchase: '#c62828',
    receipt: '#1565c0', payment: '#6a1b9a',
    journal: '#e65100', contra: '#37474f',
  }

  return (
    <div className="page">
      <div className="page-header">
        <h1 className="page-title">Day Book</h1>
      </div>

      <div className="field" style={{ padding: '0 1rem' }}>
        <input className="input" type="date" value={date} onChange={e => setDate(e.target.value)} />
      </div>

      {dayVouchers.length > 0 && (
        <div className="daybook-summary">
          <div><span>Vouchers</span><strong>{dayVouchers.length}</strong></div>
          <div><span>Total Debit</span><strong>{fmt(totalDebit)}</strong></div>
        </div>
      )}

      {dayVouchers.length === 0 ? (
        <div className="empty-state">No vouchers for {new Date(date + 'T00:00:00').toLocaleDateString('en-IN', { day: 'numeric', month: 'long', year: 'numeric' })}</div>
      ) : (
        <div className="voucher-list">
          {dayVouchers.map(v => (
            <div key={v.id} className="daybook-item">
              <div className="daybook-header" onClick={() => setExpanded(expanded === v.id ? null : v.id)}>
                <div className="daybook-left">
                  <span
                    className="voucher-type-badge"
                    style={{ background: TYPE_COLORS[v.type.toLowerCase()] || '#555' }}
                  >
                    {v.type}
                  </span>
                  <span className="voucher-no">{v.voucherNo}</span>
                </div>
                <div className="daybook-right">
                  <span className="daybook-amount">{fmt(v.totalAmount)}</span>
                  <span className="expand-icon">{expanded === v.id ? '▲' : '▼'}</span>
                </div>
              </div>

              {expanded === v.id && (
                <div className="daybook-detail">
                  <table className="entry-table">
                    <thead>
                      <tr><th>Ledger</th><th>Dr</th><th>Cr</th></tr>
                    </thead>
                    <tbody>
                      {v.entries.map((e, i) => {
                        const ledger = getLedgerById(e.ledgerId)
                        return (
                          <tr key={i}>
                            <td>{ledger?.name || 'Unknown'}</td>
                            <td>{e.type === 'Dr' ? fmt(e.amount) : ''}</td>
                            <td>{e.type === 'Cr' ? fmt(e.amount) : ''}</td>
                          </tr>
                        )
                      })}
                    </tbody>
                  </table>

                  {v.gstRate > 0 && (
                    <div className="gst-breakdown">
                      <div className="gst-row"><span>Base Amount</span><span>{fmt(v.baseAmount)}</span></div>
                      {v.igst > 0
                        ? <div className="gst-row"><span>IGST ({v.gstRate}%)</span><span>{fmt(v.igst)}</span></div>
                        : <>
                            <div className="gst-row"><span>CGST ({v.gstRate/2}%)</span><span>{fmt(v.cgst)}</span></div>
                            <div className="gst-row"><span>SGST ({v.gstRate/2}%)</span><span>{fmt(v.sgst)}</span></div>
                          </>
                      }
                      <div className="gst-row total"><span>Total</span><span>{fmt(v.totalAmount)}</span></div>
                    </div>
                  )}

                  {v.narration && <div className="narration">📝 {v.narration}</div>}

                  <button className="delete-voucher-btn" onClick={() => deleteVoucher(v.id)}>
                    🗑 Delete Voucher
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
