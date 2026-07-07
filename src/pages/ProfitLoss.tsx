import { useState } from 'react'
import {
  AppBar,
  ChangePeriodDialog,
  PeriodLine,
  PopupMenu,
} from '../components/ui'
import { useStore } from '../store'
import { fmt, profitAndLoss } from '../accounting'
import { printReport } from '../export'

export default function ProfitLoss() {
  const {
    company,
    companyGroups,
    companyLedgers,
    companyVouchers,
    period,
  } = useStore()
  const [menuOpen, setMenuOpen] = useState(false)
  const [periodOpen, setPeriodOpen] = useState(false)

  const pl = profitAndLoss(
    companyGroups,
    companyLedgers,
    companyVouchers,
    period,
  )

  const gross = pl.netProfit
  const left = [...pl.left]
  const right = [...pl.right]
  // Balance both sides with Nett Profit / Nett Loss
  if (gross > 0) left.push({ name: 'Nett Profit', amount: gross })
  else if (gross < 0)
    right.push({ name: 'Nett Loss', amount: -gross })
  const total = Math.max(
    left.reduce((s, r) => s + r.amount, 0),
    right.reduce((s, r) => s + r.amount, 0),
  )

  return (
    <div className="phone">
      <AppBar
        title={company?.name}
        onMenu={() => setMenuOpen((o) => !o)}
      />
      <PopupMenu
        open={menuOpen}
        onClose={() => setMenuOpen(false)}
        items={[
          { label: 'Export As PDF', onClick: () => printReport() },
          {
            label: 'Change Period',
            onClick: () => setPeriodOpen(true),
          },
        ]}
      />
      <div className="subtitle">Profit And Loss</div>
      <PeriodLine />
      <div className="two-col">
        <div className="col">
          <div className="tc-head">
            <span>Particulars</span>
            <span>Amount</span>
          </div>
          {left.map((r) => (
            <div className="tc-row bold" key={r.name}>
              <span>{r.name}</span>
              <span>{fmt(r.amount)}</span>
            </div>
          ))}
          <div className="tc-total">
            <span>Total</span>
            <span>{fmt(total)}</span>
          </div>
        </div>
        <div className="col">
          <div className="tc-head">
            <span>Particulars</span>
            <span>Amount</span>
          </div>
          {right.map((r) => (
            <div className="tc-row bold" key={r.name}>
              <span>{r.name}</span>
              <span>{fmt(r.amount)}</span>
            </div>
          ))}
          <div className="tc-total">
            <span>Total</span>
            <span>{fmt(total)}</span>
          </div>
        </div>
      </div>
      {periodOpen && (
        <ChangePeriodDialog onClose={() => setPeriodOpen(false)} />
      )}
    </div>
  )
}
