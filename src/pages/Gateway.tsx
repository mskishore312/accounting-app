import { useNavigate } from 'react-router-dom'
import {
  AppBar,
  ChangePeriodDialog,
  MenuButtons,
  PageTitle,
  PeriodLine,
} from '../components/ui'
import { useStore } from '../store'
import { useState } from 'react'

export default function Gateway() {
  const navigate = useNavigate()
  const { company } = useStore()
  const [periodOpen, setPeriodOpen] = useState(false)

  if (!company) {
    navigate('/')
    return null
  }

  return (
    <div className="phone">
      <AppBar />
      <div className="subtitle">{company.name}</div>
      <PageTitle>Gateway</PageTitle>
      <MenuButtons
        items={[
          { label: 'Master', onClick: () => navigate('/masters') },
          {
            label: 'Vouchers',
            onClick: () => navigate('/vouchers'),
          },
          { label: 'Reports', onClick: () => navigate('/reports') },
          { label: 'Utility', onClick: () => navigate('/utility') },
          {
            label: 'Select Company',
            onClick: () => navigate('/'),
          },
        ]}
      />
      <div
        style={{
          marginTop: 'auto',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 10,
          padding: 16,
        }}
      >
        <PeriodLine />
        <button
          className="iconbtn"
          aria-label="change period"
          style={{
            background: 'none',
            border: 'none',
            fontSize: 22,
            cursor: 'pointer',
            color: '#14453c',
          }}
          onClick={() => setPeriodOpen(true)}
        >
          &#9998;
        </button>
      </div>
      {periodOpen && (
        <ChangePeriodDialog onClose={() => setPeriodOpen(false)} />
      )}
    </div>
  )
}
