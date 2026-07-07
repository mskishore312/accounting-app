import { useNavigate } from 'react-router-dom'
import { AppBar, MenuButtons, PageTitle } from '../components/ui'

export default function FinalReports() {
  const navigate = useNavigate()
  return (
    <div className="phone">
      <AppBar />
      <PageTitle>Final Reports</PageTitle>
      <MenuButtons
        items={[
          {
            label: 'Profit & Loss',
            onClick: () => navigate('/reports/pl'),
          },
          {
            label: 'Balance Sheet',
            onClick: () => navigate('/reports/balancesheet'),
          },
        ]}
      />
    </div>
  )
}
