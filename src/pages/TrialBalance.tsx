import { useState } from 'react'
import {
  AppBar,
  ChangePeriodDialog,
  PeriodLine,
  PopupMenu,
} from '../components/ui'
import { useStore } from '../store'
import { fmt, trialBalance } from '../accounting'
import { exportCsv, printReport } from '../export'

export default function TrialBalancePage() {
  const { company, companyLedgers, companyVouchers, period } =
    useStore()
  const [menuOpen, setMenuOpen] = useState(false)
  const [periodOpen, setPeriodOpen] = useState(false)

  const tb = trialBalance(companyLedgers, companyVouchers, period)

  const csv = () =>
    exportCsv(
      'trial-balance',
      ['Particulars', 'Debit', 'Credit'],
      tb.rows.map((r) => [
        r.name,
        r.debit ? fmt(r.debit) : '0',
        r.credit ? fmt(r.credit) : '0',
      ]),
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
          { label: 'Export as Excel Sheet', onClick: csv },
          { label: 'Export As PDF', onClick: () => printReport() },
          {
            label: 'Change Period',
            onClick: () => setPeriodOpen(true),
          },
        ]}
      />
      <div className="subtitle">Trial Balance</div>
      <PeriodLine />
      <div className="table-wrap">
        <table className="rpt">
          <thead>
            <tr>
              <th>Particulars</th>
              <th className="num">Debit</th>
              <th className="num">Credit</th>
            </tr>
          </thead>
          <tbody>
            {tb.rows.map((r) => (
              <tr key={r.name}>
                <td>{r.name}</td>
                <td className="num">
                  {r.debit ? fmt(r.debit) : '0'}
                </td>
                <td className="num">
                  {r.credit ? fmt(r.credit) : '0'}
                </td>
              </tr>
            ))}
          </tbody>
          <tfoot>
            <tr>
              <td>Total</td>
              <td className="num">{fmt(tb.totalDebit)}</td>
              <td className="num">{fmt(tb.totalCredit)}</td>
            </tr>
          </tfoot>
        </table>
        {!tb.rows.length && (
          <div className="empty-note">No balances to report.</div>
        )}
      </div>
      {periodOpen && (
        <ChangePeriodDialog onClose={() => setPeriodOpen(false)} />
      )}
    </div>
  )
}
