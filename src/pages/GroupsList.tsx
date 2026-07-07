import { AppBar } from '../components/ui'
import { useStore } from '../store'

/** "Account Master" categories view: the list of groups (Sr.No/Name/Under) */
export default function GroupsList() {
  const { company, companyGroups } = useStore()
  return (
    <div className="phone">
      <AppBar title={company?.name} />
      <div className="subtitle">Account Master</div>
      <div className="table-wrap">
        <table className="rpt">
          <thead>
            <tr>
              <th>Sr.No</th>
              <th>Name</th>
              <th>Under</th>
            </tr>
          </thead>
          <tbody>
            {companyGroups.map((g, i) => (
              <tr key={g.id}>
                <td>{i}</td>
                <td>{g.name}</td>
                <td>{g.under}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
