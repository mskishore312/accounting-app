import { useState } from 'react'
import {
  AppBar,
  ChangePeriodDialog,
  PeriodLine,
  PopupMenu,
} from '../components/ui'
import { useStore } from '../store'
import { balanceSheet, fmt } from '../accounting'
import { printReport } from '../export'

export default function BalanceSheetPage() {
  const {
    company,
    companyGroups,
    companyLedgers,
    companyVouchers,
    period,
  } = useStore()
  const [menuOpen, setMenuOpen] = useState(false)
  const [periodOpen, setPeriodOpen] = useState(false)
  const [detailed, setDetailed] = useState(true)

  const bs = balanceSheet(
    companyGroups,
    companyLedgers,
    companyVouchers,
    period,
    detailed,
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
          {
            label: detailed ? 'Condensed View' : 'Detailed View',
            onClick: () => setDetailed((d) => !d),
          },
          { label: 'Export As PDF', onClick: () => printReport() },
          {
            label: 'Change Period',
            onClick: () => setPeriodOpen(true),
          },
        ]}
      />
      <div className="subtitle">Balance Sheet</div>
      <PeriodLine />
      <div className="two-col">
        <div className="col">
          <div className="tc-head">
            <span>Particulars</span>
            <span>Amount</span>
          </div>
          {bs.liabilities.map((b) => (
            <div key={b.name}>
              <div className="tc-row bold">
                <span>{b.name}</span>
                <span>{fmt(b.amount)}</span>
              </div>
              {b.children.map((c) => (
                <div className="tc-row child" key={c.name}>
                  <span>{c.name}</span>
                  <span>{fmt(c.amount)}</span>
                </div>
              ))}
            </div>
          ))}
          {bs.netProfit !== 0 && (
            <div className="tc-row bold">
              <span>Profit &amp; Loss A/c</span>
              <span>{fmt(bs.netProfit)}</span>
            </div>
          )}
          {bs.diffOpening !== 0 && (
            <div className="tc-row">
              <span>Diff. In Opening Balance</span>
              <span>{fmt(bs.diffOpening)}</span>
            </div>
          )}
          <div className="tc-total">
            <span>Total</span>
            <span>{fmt(bs.totalLiabilities)}</span>
          </div>
        </div>
        <div className="col">
          <div className="tc-head">
            <span>Particulars</span>
            <span>Amount</span>
          </div>
          {bs.assets.map((b) => (
            <div key={b.name}>
              <div className="tc-row bold">
                <span>{b.name}</span>
                <span>{fmt(b.amount)}</span>
              </div>
              {b.children.map((c) => (
                <div className="tc-row child" key={c.name}>
                  <span>{c.name}</span>
                  <span>{fmt(c.amount)}</span>
                </div>
              ))}
            </div>
          ))}
          <div className="tc-total">
            <span>Total</span>
            <span>{fmt(bs.totalAssets)}</span>
          </div>
        </div>
      </div>
      {periodOpen && (
        <ChangePeriodDialog onClose={() => setPeriodOpen(false)} />
      )}
    </div>
  )
}
