import { AppBar } from '../components/ui'
import { useStore } from '../store'

export default function AddressBook() {
  const { company, companyLedgers } = useStore()
  const rows = companyLedgers.filter(
    (l) => l.address || l.contactNo || l.tinGst,
  )
  return (
    <div className="phone">
      <AppBar title={company?.name} />
      <div className="subtitle">Address Book</div>
      <div className="table-wrap">
        <table className="rpt">
          <thead>
            <tr>
              <th>Name</th>
              <th>Address</th>
              <th>Contact No</th>
              <th>Tin/GST No</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((l) => (
              <tr key={l.id}>
                <td>{l.name}</td>
                <td>{l.address ?? ''}</td>
                <td>{l.contactNo ?? ''}</td>
                <td>{l.tinGst ?? ''}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {!rows.length && (
          <div className="empty-note">
            No ledgers with address details yet.
          </div>
        )}
      </div>
    </div>
  )
}
