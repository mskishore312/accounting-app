import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  AppBar,
  ChangePeriodDialog,
  PeriodLine,
  PopupMenu,
} from '../components/ui'
import {
  matchesFilter,
  ReportFilter,
  SearchDialog,
} from '../components/SearchDialog'
import { useStore } from '../store'
import {
  daybookParticulars,
  fmt,
  fmtDate,
  inPeriod,
} from '../accounting'
import { exportCsv, printReport } from '../export'

export default function DayBook() {
  const navigate = useNavigate()
  const { company, companyVouchers, companyLedgers, period } =
    useStore()
  const [menuOpen, setMenuOpen] = useState(false)
  const [searchOpen, setSearchOpen] = useState(false)
  const [periodOpen, setPeriodOpen] = useState(false)
  const [withNarration, setWithNarration] = useState(false)
  const [filter, setFilter] = useState<ReportFilter | null>(null)

  const nameOf = (id: string) =>
    companyLedgers.find((l) => l.id === id)?.name ?? '?'

  const rows = companyVouchers
    .filter((v) => inPeriod(v.date, period))
    .map((v) => ({ v, ...daybookParticulars(v, nameOf) }))
    .filter((r) =>
      matchesFilter(filter, {
        date: r.v.date,
        particulars: r.particulars,
        vchType: r.v.vchType,
        debit: r.debit,
        credit: r.credit,
        narration: r.v.narration,
      }),
    )

  const csv = () =>
    exportCsv(
      'day-book',
      ['Date', 'Particulars', 'Vch Type', 'Vch No.', 'Debit', 'Credit'],
      rows.map((r) => [
        fmtDate(r.v.date),
        r.particulars,
        r.v.vchType,
        String(r.v.vchNo),
        r.debit ? fmt(r.debit) : '',
        r.credit ? fmt(r.credit) : '',
      ]),
    )

  return (
    <div className="phone">
      <AppBar
        title={company?.name}
        onMenu={() => setMenuOpen((o) => !o)}
        onSearch={() => setSearchOpen(true)}
      />
      <PopupMenu
        open={menuOpen}
        onClose={() => setMenuOpen(false)}
        items={[
          {
            label: 'Add New Voucher',
            onClick: () => navigate('/vouchers'),
          },
          {
            label: withNarration
              ? 'Report Without Narration'
              : 'Report With Narration',
            onClick: () => setWithNarration((w) => !w),
          },
          { label: 'Export as Excel Sheet', onClick: csv },
          { label: 'Export As PDF', onClick: () => printReport() },
          { label: 'Clear Search', onClick: () => setFilter(null) },
          {
            label: 'Change Period',
            onClick: () => setPeriodOpen(true),
          },
        ]}
      />
      <div className="subtitle">Day Book</div>
      <PeriodLine />
      <div className="table-wrap">
        <table className="rpt">
          <thead>
            <tr>
              <th>Date</th>
              <th>Particulars</th>
              <th>Vch Type</th>
              <th className="num">Vch No.</th>
              <th className="num">Debit</th>
              <th className="num">Credit</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr
                key={r.v.id}
                style={{ cursor: 'pointer' }}
                onClick={() =>
                  navigate(
                    `/vouchers/${r.v.vchType.toLowerCase()}/${r.v.id}`,
                  )
                }
              >
                <td>{fmtDate(r.v.date)}</td>
                <td>
                  {r.particulars}
                  {withNarration && r.v.narration && (
                    <div
                      style={{
                        fontSize: 13,
                        color: '#456',
                        fontStyle: 'italic',
                      }}
                    >
                      {r.v.narration}
                    </div>
                  )}
                </td>
                <td>{r.v.vchType}</td>
                <td className="num">{r.v.vchNo}</td>
                <td className="num">
                  {r.debit ? fmt(r.debit) : ''}
                </td>
                <td className="num">
                  {r.credit ? fmt(r.credit) : ''}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {!rows.length && (
          <div className="empty-note">
            No vouchers in this period.
          </div>
        )}
      </div>
      {searchOpen && (
        <SearchDialog
          onApply={setFilter}
          onClose={() => setSearchOpen(false)}
        />
      )}
      {periodOpen && (
        <ChangePeriodDialog onClose={() => setPeriodOpen(false)} />
      )}
    </div>
  )
}
