import { useNavigate, useParams } from 'react-router-dom'
import { AppBar, PeriodLine } from '../components/ui'
import { useStore } from '../store'
import { fmt, fmtDate, inPeriod } from '../accounting'
import { VoucherType } from '../types'

function titleCase(s: string): VoucherType {
  return (s.charAt(0).toUpperCase() +
    s.slice(1).toLowerCase()) as VoucherType
}

/** Per-type voucher register: e.g. "Receipt Vouchers" */
export default function VoucherList() {
  const navigate = useNavigate()
  const { type } = useParams()
  const vchType = titleCase(type ?? 'receipt')
  const {
    company,
    companyVouchers,
    companyLedgers,
    period,
  } = useStore()

  const nameOf = (id: string) =>
    companyLedgers.find((l) => l.id === id)?.name ?? '?'

  const vouchers = companyVouchers.filter(
    (v) => v.vchType === vchType && inPeriod(v.date, period),
  )

  // Receipt shows the credited (source) ledger; Payment shows the
  // debited (destination) ledger — matching the reference app.
  const amountCol =
    vchType === 'Receipt'
      ? 'Credit'
      : vchType === 'Payment'
        ? 'Debit'
        : 'Amount'

  const rowInfo = (v: (typeof vouchers)[number]) => {
    const dr = v.lines.filter((l) => l.type === 'Dr')
    const cr = v.lines.filter((l) => l.type === 'Cr')
    const total = dr.reduce((s, l) => s + l.amount, 0)
    const particulars =
      vchType === 'Receipt'
        ? cr.map((l) => nameOf(l.ledgerId)).join(', ')
        : dr.map((l) => nameOf(l.ledgerId)).join(', ')
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
                      `/vouchers/${vchType.toLowerCase()}/${v.id}`,
                    )
                  }
                >
                  <td>{fmtDate(v.date)}</td>
                  <td>{particulars}</td>
                  <td className="num">{fmt(total)}</td>
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
            navigate(`/vouchers/${vchType.toLowerCase()}/new`)
          }
        >
          Add
        </button>
      </div>
    </div>
  )
}
