import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { AppBar } from '../components/ui'
import { useStore } from '../store'
import { closingAt, drcr, fmt, openingSigned } from '../accounting'

/** "Account Master" ledger list: Name | Under | Op. Balance | Tin/GST No */
export default function LedgerList({
  balances,
}: {
  /** 'opening' → masters view; 'closing' → List Of Accounts report */
  balances: 'opening' | 'closing'
}) {
  const navigate = useNavigate()
  const { company, companyLedgers, companyVouchers, period } =
    useStore()
  const [q, setQ] = useState('')

  const filtered = companyLedgers.filter((l) =>
    l.name.toLowerCase().includes(q.toLowerCase()),
  )

  return (
    <div className="phone">
      <AppBar title={company?.name} />
      <div className="subtitle">
        {balances === 'opening' ? 'Account Master' : 'List of Accounts'}
      </div>
      <div className="searchbar">
        <span>&#128269;</span>
        <input
          placeholder="Search"
          value={q}
          onChange={(e) => setQ(e.target.value)}
        />
      </div>
      <div className="table-wrap">
        <table className="rpt">
          <thead>
            <tr>
              {balances === 'closing' && <th>Sr.No</th>}
              <th>Name</th>
              <th>Under</th>
              <th className="num">
                {balances === 'opening' ? 'Op. Balance' : 'Balance'}
              </th>
              <th>Tin/GST No</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((l, i) => {
              const bal =
                balances === 'opening'
                  ? openingSigned(l)
                  : closingAt(companyVouchers, l, period)
              return (
                <tr
                  key={l.id}
                  onClick={() =>
                    balances === 'opening' &&
                    navigate(`/masters/ledgers/${l.id}`)
                  }
                  style={{
                    cursor:
                      balances === 'opening' ? 'pointer' : 'default',
                  }}
                >
                  {balances === 'closing' && <td>{i + 1}</td>}
                  <td>{l.name}</td>
                  <td>{l.under === 'Primary' ? '' : l.under}</td>
                  <td className="num">
                    {fmt(Math.abs(bal))}{' '}
                    <span className="drcr">{drcr(bal)}.</span>
                  </td>
                  <td>{l.tinGst ?? ''}</td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
      {balances === 'opening' && (
        <div className="bottom-action">
          <button onClick={() => navigate('/masters/ledgers/new')}>
            Add
          </button>
        </div>
      )}
    </div>
  )
}
