import { useState } from 'react'
import {
  AppBar,
  ChangePeriodDialog,
  PeriodLine,
  PopupMenu,
} from '../components/ui'
import { useStore } from '../store'
import { fmt, PLRow, profitAndLoss } from '../accounting'
import { printReport } from '../export'

function Rows({
  rows,
  detailed,
}: {
  rows: PLRow[]
  detailed: boolean
}) {
  return (
    <>
      {rows.map((r) => (
        <div key={r.name}>
          <div
            className="tc-row bold"
            style={
              r.emphasis
                ? { color: '#14453c', fontStyle: 'italic' }
                : undefined
            }
          >
            <span>{r.name}</span>
            <span>{fmt(r.amount)}</span>
          </div>
          {detailed &&
            r.children.map((c) => (
              <div className="tc-row child" key={c.name}>
                <span style={{ paddingLeft: 12 }}>{c.name}</span>
                <span>{fmt(c.amount)}</span>
              </div>
            ))}
        </div>
      ))}
    </>
  )
}

/**
 * Tally-principle horizontal P&L with Gross Profit:
 * trading section (Opening Stock, Purchases, Direct Expenses vs
 * Sales, Direct Incomes, Closing Stock) carries Gross Profit c/o
 * down to the income statement, which nets Indirect Expenses
 * against Gross Profit b/f + Indirect Income into Nett Profit.
 */
export default function ProfitLoss() {
  const {
    company,
    companyGroups,
    companyLedgers,
    companyStockItems,
    companyVouchers,
    period,
  } = useStore()
  const [menuOpen, setMenuOpen] = useState(false)
  const [periodOpen, setPeriodOpen] = useState(false)
  const [detailed, setDetailed] = useState(false)

  const pl = profitAndLoss(
    companyGroups,
    companyLedgers,
    companyStockItems,
    companyVouchers,
    period,
    company?.integrateInventory ?? true,
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
      <div className="subtitle">Profit And Loss</div>
      <PeriodLine />
      <div className="two-col" style={{ flex: 'initial' }}>
        <div className="col">
          <div className="tc-head">
            <span>Particulars</span>
            <span>Amount</span>
          </div>
          <Rows rows={pl.tradingLeft} detailed={detailed} />
          <div className="tc-total">
            <span>Total</span>
            <span>{fmt(pl.tradingTotal)}</span>
          </div>
        </div>
        <div className="col">
          <div className="tc-head">
            <span>Particulars</span>
            <span>Amount</span>
          </div>
          <Rows rows={pl.tradingRight} detailed={detailed} />
          <div className="tc-total">
            <span>Total</span>
            <span>{fmt(pl.tradingTotal)}</span>
          </div>
        </div>
      </div>
      <div
        className="two-col"
        style={{ borderTop: 'none', flex: 'initial' }}
      >
        <div className="col">
          <Rows rows={pl.lowerLeft} detailed={detailed} />
          <div className="tc-total">
            <span>Total</span>
            <span>{fmt(pl.lowerTotal)}</span>
          </div>
        </div>
        <div className="col">
          <Rows rows={pl.lowerRight} detailed={detailed} />
          <div className="tc-total">
            <span>Total</span>
            <span>{fmt(pl.lowerTotal)}</span>
          </div>
        </div>
      </div>
      {periodOpen && (
        <ChangePeriodDialog onClose={() => setPeriodOpen(false)} />
      )}
    </div>
  )
}
