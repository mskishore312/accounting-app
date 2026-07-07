import { useNavigate } from 'react-router-dom'
import { AppBar, MenuButtons, PageTitle } from '../components/ui'
import { useStore } from '../store'
import { ALL_VOUCHER_TYPES, vchSlug } from '../types'

/** Registers: pick a voucher type, view its register */
export default function Registers() {
  const navigate = useNavigate()
  const { companyVouchers } = useStore()
  const count = (t: string) =>
    companyVouchers.filter((v) => v.vchType === t).length
  return (
    <div className="phone">
      <AppBar />
      <PageTitle>Registers</PageTitle>
      <MenuButtons
        items={ALL_VOUCHER_TYPES.map((t) => ({
          label: `${t} Register (${count(t)})`,
          onClick: () => navigate(`/vouchers/${vchSlug(t)}`),
        }))}
      />
    </div>
  )
}
