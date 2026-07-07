import { useNavigate } from 'react-router-dom'
import { AppBar, MenuButtons, PageTitle } from '../components/ui'
import { useStore } from '../store'

export default function InventoryMenu() {
  const navigate = useNavigate()
  const {
    company,
    companyStockItems,
    companyStockGroups,
    companyUnits,
  } = useStore()
  return (
    <div className="phone">
      <AppBar />
      <div className="subtitle">{company?.name}</div>
      <PageTitle>Inventory Masters</PageTitle>
      <MenuButtons
        items={[
          {
            label: `Stock Items (${companyStockItems.length})`,
            onClick: () => navigate('/masters/stockitems'),
          },
          {
            label: `Stock Groups (${companyStockGroups.length})`,
            onClick: () => navigate('/masters/stockgroups'),
          },
          {
            label: `Units (${companyUnits.length})`,
            onClick: () => navigate('/masters/units'),
          },
        ]}
      />
    </div>
  )
}
