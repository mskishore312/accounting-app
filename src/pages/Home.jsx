import React from 'react'
import { useApp } from '../store/AppContext'

export default function Home({ onNavigate }) {
  const { vouchers, ledgers, getLedgerBalance } = useApp()

  const today = new Date().toISOString().split('T')[0]
  const todayVouchers = vouchers.filter(v => v.date === today)

  const totalSales = todayVouchers
    .filter(v => v.type === 'Sales')
    .reduce((sum, v) => sum + v.totalAmount, 0)

  const totalPurchase = todayVouchers
    .filter(v => v.type === 'Purchase')
    .reduce((sum, v) => sum + v.totalAmount, 0)

  const cashLedger = ledgers.find(l => l.name === 'Cash')
  const bankLedger = ledgers.find(l => l.name === 'Bank Account')
  const cashBalance = cashLedger ? getLedgerBalance(cashLedger.id) : 0
  const bankBalance = bankLedger ? getLedgerBalance(bankLedger.id) : 0

  const fmt = n => '₹' + Math.abs(n).toLocaleString('en-IN', { minimumFractionDigits: 2 })

  return (
    <div className="page">
      <div className="page-header">
        <h1 className="page-title">Tally Mobile</h1>
        <span className="page-date">{new Date().toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })}</span>
      </div>

      <div className="summary-grid">
        <div className="summary-card green">
          <div className="summary-label">Today's Sales</div>
          <div className="summary-value">{fmt(totalSales)}</div>
        </div>
        <div className="summary-card red">
          <div className="summary-label">Today's Purchase</div>
          <div className="summary-value">{fmt(totalPurchase)}</div>
        </div>
        <div className="summary-card blue">
          <div className="summary-label">Cash Balance</div>
          <div className="summary-value">{fmt(cashBalance)}</div>
          <div className="summary-sub">{cashBalance >= 0 ? 'Dr' : 'Cr'}</div>
        </div>
        <div className="summary-card purple">
          <div className="summary-label">Bank Balance</div>
          <div className="summary-value">{fmt(bankBalance)}</div>
          <div className="summary-sub">{bankBalance >= 0 ? 'Dr' : 'Cr'}</div>
        </div>
      </div>

      <div className="section-title">Quick Entry</div>
      <div className="quick-actions">
        {['Sales', 'Purchase', 'Receipt', 'Payment'].map(type => (
          <button
            key={type}
            className="quick-btn"
            onClick={() => onNavigate('voucher', { type })}
          >
            <span className="quick-icon">
              {type === 'Sales' ? '💰' : type === 'Purchase' ? '🛒' : type === 'Receipt' ? '📥' : '📤'}
            </span>
            <span>{type}</span>
          </button>
        ))}
      </div>

      <div className="section-title">Today's Vouchers ({todayVouchers.length})</div>
      {todayVouchers.length === 0 ? (
        <div className="empty-state">No vouchers today. Tap a quick entry above.</div>
      ) : (
        <div className="voucher-list">
          {todayVouchers.slice(0, 5).map(v => (
            <div key={v.id} className="voucher-item">
              <div className="voucher-meta">
                <span className={`voucher-type-badge ${v.type.toLowerCase()}`}>{v.type}</span>
                <span className="voucher-no">{v.voucherNo}</span>
              </div>
              <div className="voucher-amount">₹{v.totalAmount.toLocaleString('en-IN', { minimumFractionDigits: 2 })}</div>
            </div>
          ))}
          {todayVouchers.length > 5 && (
            <button className="see-all-btn" onClick={() => onNavigate('daybook')}>
              See all {todayVouchers.length} vouchers →
            </button>
          )}
        </div>
      )}
    </div>
  )
}
