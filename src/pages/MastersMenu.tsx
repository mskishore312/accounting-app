import { useNavigate } from 'react-router-dom'
import { AppBar, MenuButtons, PageTitle } from '../components/ui'
import { useStore } from '../store'

export default function MastersMenu() {
  const navigate = useNavigate()
  const {
    company,
    companyLedgers,
    companyGroups,
    companyStockItems,
    companyStockGroups,
    companyUnits,
  } = useStore()
  const invCount =
    companyStockItems.length +
    companyStockGroups.length +
    companyUnits.length
  return (
    <div className="phone">
      <AppBar />
      <div className="subtitle">{company?.name}</div>
      <PageTitle>Options</PageTitle>
      <MenuButtons
        items={[
          {
            label: `Account Masters (${companyLedgers.length})`,
            onClick: () => navigate('/masters/ledgers'),
          },
          {
            label: `Account Groups (${companyGroups.length})`,
            onClick: () => navigate('/masters/groups'),
          },
          {
            label: `Inventory Masters (${invCount})`,
            onClick: () => navigate('/masters/inventory'),
          },
        ]}
      />
    </div>
  )
}
