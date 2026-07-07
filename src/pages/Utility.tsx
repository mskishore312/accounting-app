import { useNavigate } from 'react-router-dom'
import { AppBar, MenuButtons, PageTitle } from '../components/ui'
import { useStore } from '../store'
import { AppData } from '../types'

export default function Utility() {
  const navigate = useNavigate()
  const { data, company, deleteCompany, restoreData } = useStore()

  const backup = () => {
    const blob = new Blob([JSON.stringify(data, null, 2)], {
      type: 'application/json',
    })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `accounting-backup-${new Date()
      .toISOString()
      .slice(0, 10)}.json`
    a.click()
    URL.revokeObjectURL(url)
  }

  const backupAndMail = () => {
    backup()
    const subject = encodeURIComponent(
      `Accounting backup ${new Date().toLocaleDateString()}`,
    )
    const body = encodeURIComponent(
      'Backup file downloaded — attach the JSON file to this mail.',
    )
    window.location.href = `mailto:?subject=${subject}&body=${body}`
  }

  const restore = () => {
    const input = document.createElement('input')
    input.type = 'file'
    input.accept = 'application/json'
    input.onchange = () => {
      const file = input.files?.[0]
      if (!file) return
      const reader = new FileReader()
      reader.onload = () => {
        try {
          const parsed = JSON.parse(
            String(reader.result),
          ) as AppData
          if (
            !parsed ||
            !Array.isArray(parsed.companies) ||
            !Array.isArray(parsed.groups) ||
            !Array.isArray(parsed.ledgers) ||
            !Array.isArray(parsed.vouchers)
          ) {
            alert('Invalid backup file')
            return
          }
          restoreData(parsed)
          alert('Restore complete')
          navigate('/')
        } catch {
          alert('Could not read backup file')
        }
      }
      reader.readAsText(file)
    }
    input.click()
  }

  const delCompany = () => {
    if (!company) return
    if (
      confirm(
        `Delete company "${company.name}" and all its data? This cannot be undone.`,
      )
    ) {
      deleteCompany(company.id)
      navigate('/')
    }
  }

  return (
    <div className="phone">
      <AppBar />
      <PageTitle>Utility</PageTitle>
      <MenuButtons
        items={[
          {
            label: 'Company Edit',
            onClick: () => navigate('/company/edit'),
          },
          { label: 'Backup', onClick: backup },
          { label: 'Backup And Mail', onClick: backupAndMail },
          { label: 'Restore', onClick: restore },
          {
            label: 'Settings',
            onClick: () => navigate('/settings'),
          },
          { label: 'Delete Company', onClick: delCompany },
        ]}
      />
    </div>
  )
}
