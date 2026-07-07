import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { AppBar } from '../components/ui'
import { useStore } from '../store'
import { fmt } from '../accounting'
import { stockQtyValue } from '../inventory'

/** Stock Item masters list: Name | Under | Unit | Op. Qty | Op. Value */
export default function StockItemList() {
  const navigate = useNavigate()
  const { company, companyStockItems, companyVouchers, period } =
    useStore()
  const [q, setQ] = useState('')

  const filtered = companyStockItems.filter((s) =>
    s.name.toLowerCase().includes(q.toLowerCase()),
  )

  return (
    <div className="phone">
      <AppBar title={company?.name} />
      <div className="subtitle">Stock Items</div>
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
              <th>Name</th>
              <th>Under</th>
              <th>Unit</th>
              <th className="num">Cl. Qty</th>
              <th className="num">Cl. Value</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((s) => {
              const cl = stockQtyValue(
                s,
                companyVouchers,
                period.to,
              )
              return (
                <tr
                  key={s.id}
                  style={{ cursor: 'pointer' }}
                  onClick={() =>
                    navigate(`/masters/stockitems/${s.id}`)
                  }
                >
                  <td>{s.name}</td>
                  <td>{s.group === 'Primary' ? '' : s.group}</td>
                  <td>{s.unit}</td>
                  <td className="num">{cl.qty}</td>
                  <td className="num">{fmt(cl.value)}</td>
                </tr>
              )
            })}
          </tbody>
        </table>
        {!filtered.length && (
          <div className="empty-note">No stock items yet.</div>
        )}
      </div>
      <div className="bottom-action">
        <button onClick={() => navigate('/masters/stockitems/new')}>
          Add
        </button>
      </div>
    </div>
  )
}
