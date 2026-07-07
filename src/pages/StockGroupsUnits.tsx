import { useState } from 'react'
import { AppBar } from '../components/ui'
import { useStore } from '../store'
import { NameUnderDialog, UnitDialog } from './StockItemForm'

export function StockGroupsList() {
  const {
    company,
    companyStockGroups,
    addStockGroup,
    deleteStockGroup,
  } = useStore()
  const [dialog, setDialog] = useState(false)
  return (
    <div className="phone">
      <AppBar title={company?.name} />
      <div className="subtitle">Stock Groups</div>
      <div className="table-wrap">
        <table className="rpt">
          <thead>
            <tr>
              <th>Sr.No</th>
              <th>Name</th>
              <th>Under</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {companyStockGroups.map((g, i) => (
              <tr key={g.id}>
                <td>{i + 1}</td>
                <td>{g.name}</td>
                <td>{g.under}</td>
                <td>
                  <button
                    className="iconbtn"
                    style={{ color: '#8c4a3f', fontSize: 18 }}
                    title="Delete"
                    onClick={() => {
                      if (confirm(`Delete "${g.name}"?`)) {
                        const err = deleteStockGroup(g.id)
                        if (err) alert(err)
                      }
                    }}
                  >
                    &#10005;
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {!companyStockGroups.length && (
          <div className="empty-note">No stock groups yet.</div>
        )}
      </div>
      <div className="bottom-action">
        <button onClick={() => setDialog(true)}>Add</button>
      </div>
      {dialog && (
        <NameUnderDialog
          title="New Stock Group"
          unders={[
            'Primary',
            ...companyStockGroups.map((g) => g.name),
          ]}
          onAdd={(n, u) => {
            const res = addStockGroup({ name: n, under: u })
            if (typeof res === 'string') alert(res)
            else setDialog(false)
          }}
          onClose={() => setDialog(false)}
        />
      )}
    </div>
  )
}

export function UnitsList() {
  const { company, companyUnits, addUnit, deleteUnit } = useStore()
  const [dialog, setDialog] = useState(false)
  return (
    <div className="phone">
      <AppBar title={company?.name} />
      <div className="subtitle">Units</div>
      <div className="table-wrap">
        <table className="rpt">
          <thead>
            <tr>
              <th>Sr.No</th>
              <th>Symbol</th>
              <th>Formal Name</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {companyUnits.map((u, i) => (
              <tr key={u.id}>
                <td>{i + 1}</td>
                <td>{u.symbol}</td>
                <td>{u.formalName}</td>
                <td>
                  <button
                    className="iconbtn"
                    style={{ color: '#8c4a3f', fontSize: 18 }}
                    title="Delete"
                    onClick={() => {
                      if (confirm(`Delete "${u.symbol}"?`)) {
                        const err = deleteUnit(u.id)
                        if (err) alert(err)
                      }
                    }}
                  >
                    &#10005;
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {!companyUnits.length && (
          <div className="empty-note">
            No units yet. e.g. Nos, Kg, Ltr, Box
          </div>
        )}
      </div>
      <div className="bottom-action">
        <button onClick={() => setDialog(true)}>Add</button>
      </div>
      {dialog && (
        <UnitDialog
          onAdd={(s, f) => {
            const res = addUnit({ symbol: s, formalName: f })
            if (typeof res === 'string') alert(res)
            else setDialog(false)
          }}
          onClose={() => setDialog(false)}
        />
      )}
    </div>
  )
}
