import { useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { AppBar, PageTitle } from '../components/ui'
import { useStore } from '../store'
import { groupsUnder } from '../accounting'

/** "Select Ledger" list — for Ledger report and Cash/Bank Book */
export default function SelectLedger({
  cashBankOnly,
}: {
  cashBankOnly?: boolean
}) {
  const navigate = useNavigate()
  useParams()
  const { companyLedgers, companyGroups } = useStore()
  const [q, setQ] = useState('')

  const ledgers = useMemo(() => {
    if (!cashBankOnly) return companyLedgers
    const names = groupsUnder(companyGroups, [
      'Cash-in-hand',
      'Bank Accounts',
      'Bank OD A/c',
    ])
    return companyLedgers.filter((l) => names.has(l.under))
  }, [companyLedgers, companyGroups, cashBankOnly])

  const filtered = ledgers.filter((l) =>
    l.name.toLowerCase().includes(q.toLowerCase()),
  )

  return (
    <div className="phone">
      <AppBar />
      <PageTitle>
        {cashBankOnly ? 'Cash/Bank Book' : 'Select Ledger'}
      </PageTitle>
      <div className="searchbar">
        <span>&#128269;</span>
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder=""
        />
      </div>
      <ul className="row-list">
        {filtered.map((l) => (
          <li
            key={l.id}
            onClick={() => navigate(`/reports/ledger/${l.id}`)}
          >
            {l.name}
          </li>
        ))}
      </ul>
      {!filtered.length && (
        <div className="empty-note">No ledgers found.</div>
      )}
    </div>
  )
}
