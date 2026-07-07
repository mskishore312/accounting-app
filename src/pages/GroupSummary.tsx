import { useState } from 'react'
import { AppBar, PageTitle, PeriodLine } from '../components/ui'
import { useStore } from '../store'
import {
  closingAt,
  drcr,
  fmt,
  groupsUnder,
  ledgersInGroups,
} from '../accounting'

export default function GroupSummary() {
  const {
    company,
    companyGroups,
    companyLedgers,
    companyVouchers,
    period,
  } = useStore()
  const [selected, setSelected] = useState<string | null>(null)

  if (!selected) {
    return (
      <div className="phone">
        <AppBar />
        <PageTitle>Group Summary</PageTitle>
        <ul className="row-list">
          {companyGroups.map((g) => (
            <li key={g.id} onClick={() => setSelected(g.name)}>
              {g.name}
            </li>
          ))}
        </ul>
      </div>
    )
  }

  const names = groupsUnder(companyGroups, [selected])
  const members = ledgersInGroups(companyLedgers, names)
  const rows = members.map((l) => ({
    l,
    bal: closingAt(companyVouchers, l, period),
  }))
  const total = rows.reduce((s, r) => s + r.bal, 0)

  return (
    <div className="phone">
      <AppBar title={company?.name} />
      <div className="subtitle">Group Summary: {selected}</div>
      <PeriodLine />
      <div className="table-wrap">
        <table className="rpt">
          <thead>
            <tr>
              <th>Name</th>
              <th>Under</th>
              <th className="num">Balance</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.l.id}>
                <td>{r.l.name}</td>
                <td>{r.l.under}</td>
                <td className="num">
                  {fmt(Math.abs(r.bal))}{' '}
                  <span className="drcr">{drcr(r.bal)}.</span>
                </td>
              </tr>
            ))}
          </tbody>
          <tfoot>
            <tr>
              <td colSpan={2}>Total</td>
              <td className="num">
                {fmt(Math.abs(total))}{' '}
                <span className="drcr">{drcr(total)}.</span>
              </td>
            </tr>
          </tfoot>
        </table>
        {!rows.length && (
          <div className="empty-note">
            No ledgers under this group.
          </div>
        )}
      </div>
      <div className="bottom-action">
        <button onClick={() => setSelected(null)}>
          Select Group
        </button>
      </div>
    </div>
  )
}
