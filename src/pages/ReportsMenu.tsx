import { useNavigate } from 'react-router-dom'
import { AppBar, MenuButtons, PageTitle } from '../components/ui'

export default function ReportsMenu() {
  const navigate = useNavigate()
  return (
    <div className="phone">
      <AppBar />
      <PageTitle>Reports</PageTitle>
      <MenuButtons
        items={[
          {
            label: 'Day Book',
            onClick: () => navigate('/reports/daybook'),
          },
          {
            label: 'Ledger',
            onClick: () => navigate('/reports/ledger'),
          },
          {
            label: 'Cash/Bank Book',
            onClick: () => navigate('/reports/cashbank'),
          },
          {
            label: 'Group Summary',
            onClick: () => navigate('/reports/groupsummary'),
          },
          {
            label: 'Registers',
            onClick: () => navigate('/reports/registers'),
          },
          {
            label: 'Stock Summary',
            onClick: () => navigate('/reports/stock'),
          },
          {
            label: 'List Of Accounts',
            onClick: () => navigate('/reports/accounts'),
          },
          {
            label: 'Address Book',
            onClick: () => navigate('/reports/addressbook'),
          },
          {
            label: 'Trial Balance',
            onClick: () => navigate('/reports/trialbalance'),
          },
          {
            label: 'Final Reports',
            onClick: () => navigate('/reports/final'),
          },
        ]}
      />
    </div>
  )
}
