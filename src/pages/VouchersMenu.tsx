import { useNavigate } from 'react-router-dom'
import { AppBar, MenuButtons, PageTitle } from '../components/ui'
import { useStore } from '../store'
import { ALL_VOUCHER_TYPES, vchSlug } from '../types'

export default function VouchersMenu() {
  const navigate = useNavigate()
  const { company, companyVouchers } = useStore()
  const count = (t: string) =>
    companyVouchers.filter((v) => v.vchType === t).length
  return (
    <div className="phone">
      <AppBar />
      <div className="subtitle">{company?.name}</div>
      <PageTitle>Vouchers</PageTitle>
      <MenuButtons
        items={ALL_VOUCHER_TYPES.map((t) => ({
          label: `${t} (${count(t)})`,
          onClick: () => navigate(`/vouchers/${vchSlug(t)}`),
        }))}
      />
      <div className="menu-note">
        Total Vouchers : {companyVouchers.length}
      </div>
    </div>
  )
}
