import { AppBar, PageTitle } from '../components/ui'
import { useStore } from '../store'

/** F11-style company features */
export default function Settings() {
  const { company, updateCompany } = useStore()
  if (!company) return null
  const integrate = company.integrateInventory ?? true
  return (
    <div className="phone">
      <AppBar />
      <div className="subtitle">{company.name}</div>
      <PageTitle>Settings</PageTitle>
      <div className="form">
        <div className="checkbox-row" style={{ marginTop: 24 }}>
          <input
            type="checkbox"
            id="integrate"
            checked={integrate}
            onChange={(e) =>
              updateCompany(company.id, {
                integrateInventory: e.target.checked,
              })
            }
          />
          <label htmlFor="integrate">
            Integrate Accounts with Inventory
          </label>
        </div>
        <p style={{ fontSize: 15, color: '#345', lineHeight: 1.5 }}>
          <b>Yes</b> — Opening and Closing Stock in the Profit &amp;
          Loss A/c and Balance Sheet are calculated from your stock
          items (per-item costing method, default Avg. Cost).
          <br />
          <br />
          <b>No</b> — Stock values are taken from ledgers under the
          group <i>Stock-in-hand</i>: their opening balances, and the
          dated closing balances you enter on each ledger (the value
          whose date is nearest on or before the report date is
          used). Such ledgers are never used in vouchers.
        </p>
      </div>
    </div>
  )
}
