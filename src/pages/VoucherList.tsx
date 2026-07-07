import { useNavigate, useParams } from 'react-router-dom'
import { AppBar, PeriodLine } from '../components/ui'
import { useStore } from '../store'
import { fmt, fmtDate, inPeriod } from '../accounting'
import { vchFromSlug, vchSlug } from '../types'
import { invTotal } from '../inventory'

/** Per-type voucher register: e.g. "Receipt Vouchers" */
export default function VoucherList() {
  const navigate = useNavigate()
  const { type } = useParams()
  const vchType = vchFromSlug(type ?? 'receipt')
  const {
    company,
    companyVouchers,
    companyLedgers,
    companyStockItems,
    period,
  } = useStore()

  const nameOf = (id: string) =>
    companyLedgers.find((l) => l.id === id)?.name ?? '?'
  const itemName = (id: string) =>
    companyStockItems.find((s) => s.id === id)?.name ?? '?'

  const vouchers = companyVouchers.filter(
    (v) => v.vchType === vchType && inPeriod(v.date, period),
  )

  const inventoryOnly =
    vchType === 'Stock Journal' || vchType === 'Physical Stock'

  // Receipt shows the credited (source) ledger; Payment shows the
  // debited (destination) ledger — matching the reference app.
  const amountCol =
    vchType === 'Receipt' || vchType === 'Credit Note'
      ? 'Credit'
      : vchType === 'Payment' || vchType === 'Debit Note'
        ? 'Debit'
        : vchType === 'Physical Stock'
          ? 'Qty'
          : 'Amount'

  const rowInfo = (v: (typeof vouchers)[number]) => {
    if (inventoryOnly) {
      const inv = v.invLines ?? []
      const particulars = inv
        .map((l) => itemName(l.itemId))
        .join(', ')
      const total =
        vchType === 'Physical Stock'
          ? inv.reduce((s, l) => s + l.qty, 0)
          : invTotal(inv.filter((l) => l.dir !== 'out'))
      return { particulars, total }
    }
    const dr = v.lines.filter((l) => l.type === 'Dr')
    const cr = v.lines.filter((l) => l.type === 'Cr')
    const total = dr.reduce((s, l) => s + l.amount, 0)
    const showCr =
      vchType === 'Receipt' || vchType === 'Credit Note'
    const particulars = (showCr ? cr : dr)
      .map((l) => nameOf(l.ledgerId))
      .join(', ')
    return { particulars, total }
  }

  return (
    <div className="phone">
      <AppBar title={company?.name} />
      <div className="subtitle">{vchType} Vouchers</div>
      <PeriodLine />
      <div className="table-wrap">
        <table className="rpt">
          <thead>
            <tr>
              <th>Date</th>
              <th>Particulars</th>
              <th className="num">{amountCol}</th>
            </tr>
          </thead>
          <tbody>
            {vouchers.map((v) => {
              const { particulars, total } = rowInfo(v)
              return (
                <tr
                  key={v.id}
                  style={{ cursor: 'pointer' }}
                  onClick={() =>
                    navigate(
                      `/vouchers/${vchSlug(vchType)}/${v.id}`,
                    )
                  }
                >
                  <td>{fmtDate(v.date)}</td>
                  <td>{particulars}</td>
                  <td className="num">
                    {vchType === 'Physical Stock'
                      ? total
                      : fmt(total)}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
        {!vouchers.length && (
          <div className="empty-note">
            No {vchType.toLowerCase()} vouchers in this period.
          </div>
        )}
      </div>
      <div className="bottom-action">
        <button
          onClick={() =>
            navigate(`/vouchers/${vchSlug(vchType)}/new`)
          }
        >
          Add
        </button>
      </div>
    </div>
  )
}
