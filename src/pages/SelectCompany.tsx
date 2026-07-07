import { useNavigate } from 'react-router-dom'
import { AppBar, PageTitle } from '../components/ui'
import { useStore } from '../store'

export default function SelectCompany() {
  const { data, setActiveCompany } = useStore()
  const navigate = useNavigate()
  return (
    <div className="phone">
      <AppBar />
      <PageTitle>Select Company</PageTitle>
      <ul className="row-list">
        {data.companies.map((c) => (
          <li
            key={c.id}
            onClick={() => {
              setActiveCompany(c.id)
              navigate('/gateway')
            }}
          >
            {c.name}
          </li>
        ))}
      </ul>
      {!data.companies.length && (
        <div className="empty-note">
          No companies yet. Create your first company.
        </div>
      )}
      <div className="bottom-action">
        <button onClick={() => navigate('/company/new')}>
          Create Company
        </button>
      </div>
    </div>
  )
}
