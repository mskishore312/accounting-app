import { useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
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
  buildLedgerReport,
  drcr,
  fmt,
  fmtDate,
} from '../accounting'
import { exportCsv, printReport } from '../export'

export default function LedgerReport() {
  const navigate = useNavigate()
  const { ledgerId } = useParams()
  const {
    data,
    company,
    companyLedgers,
    companyVouchers,
    period,
  } = useStore()
  const [menuOpen, setMenuOpen] = useState(false)
  const [searchOpen, setSearchOpen] = useState(false)
  const [periodOpen, setPeriodOpen] = useState(false)
  const [withNarration, setWithNarration] = useState(false)
  const [filter, setFilter] = useState<ReportFilter | null>(null)

  const ledger = companyLedgers.find((l) => l.id === ledgerId)

  const report = useMemo(() => {
    if (!ledger) return null
    return buildLedgerReport(
      { vouchers: data.vouchers, ledgers: companyLedgers },
      companyVouchers,
      ledger,
      period,
    )
  }, [ledger, data.vouchers, companyLedgers, companyVouchers, period])

  if (!ledger || !report) {
    return (
      <div className="phone">
        <AppBar />
        <div className="empty-note">Ledger not found.</div>
      </div>
    )
  }

  const rows = report.rows.filter((r) =>
    matchesFilter(filter, {
      date: r.voucher.date,
      particulars: r.particulars,
      vchType: r.voucher.vchType,
      debit: r.debit,
      credit: r.credit,
      narration: r.voucher.narration,
    }),
  )

  const csv = () =>
    exportCsv(
      `ledger-${ledger.name}`,
      [
        'Date',
        'Particulars',
        'Vch Type',
        'Vch No.',
        'Debit',
        'Credit',
        'Running Balance',
        ...(withNarration ? ['Narration'] : []),
      ],
      rows.map((r) => [
        fmtDate(r.voucher.date),
        r.particulars,
        r.voucher.vchType,
        String(r.voucher.vchNo),
        r.debit ? fmt(r.debit) : '',
        r.credit ? fmt(r.credit) : '',
        `${fmt(Math.abs(r.running))} ${drcr(r.running)}.`,
        ...(withNarration ? [r.voucher.narration] : []),
      ]),
    )

  return (
    <div className="phone">
      <AppBar
        title={company?.name}
        left={false}
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
          {
            label: 'Export As PDF',
            onClick: () => printReport(),
          },
          {
            label: 'Clear Search',
            onClick: () => setFilter(null),
          },
          {
            label: 'Change Period',
            onClick: () => setPeriodOpen(true),
          },
        ]}
      />
      <div className="subtitle">Ledger: {ledger.name}</div>
      <PeriodLine />
      {filter && (
        <div
          style={{
            textAlign: 'center',
            fontSize: 14,
            color: '#14453c',
            paddingBottom: 4,
          }}
        >
          Filter: {filter.kind}{' '}
          {filter.having ?? filter.numHaving ?? ''}{' '}
          {filter.kind === 'Date' ? fmtDate(filter.value) : filter.value}
        </div>
      )}
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
              <th className="num">
                Running
                <br />
                Balance
              </th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr
                key={r.voucher.id}
                style={{ cursor: 'pointer' }}
                onClick={() =>
                  navigate(
                    `/vouchers/${r.voucher.vchType.toLowerCase()}/${r.voucher.id}`,
                  )
                }
              >
                <td>{fmtDate(r.voucher.date)}</td>
                <td>
                  {r.particulars}
                  {withNarration && r.voucher.narration && (
                    <div
                      style={{
                        fontSize: 13,
                        color: '#456',
                        fontStyle: 'italic',
                      }}
                    >
                      {r.voucher.narration}
                    </div>
                  )}
                </td>
                <td>{r.voucher.vchType}</td>
                <td className="num">{r.voucher.vchNo}</td>
                <td className="num">
                  {r.debit ? fmt(r.debit) : ''}
                </td>
                <td className="num">
                  {r.credit ? fmt(r.credit) : ''}
                </td>
                <td className="num">
                  {fmt(Math.abs(r.running))} {drcr(r.running)}.
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {!rows.length && (
          <div className="empty-note">
            No transactions in this period.
          </div>
        )}
      </div>
      <div className="totals-block">
        <div className="totals-row">
          <span className="lbl">Opening Balance :</span>
          <span className="val">
            {fmt(Math.abs(report.opening))}
            {report.opening !== 0 ? ` ${drcr(report.opening)}.` : ''}
          </span>
          <span className="val" />
        </div>
        <div className="totals-row">
          <span className="lbl">Current Total :</span>
          <span className="val">{fmt(report.totalDebit)}</span>
          <span className="val">{fmt(report.totalCredit)}</span>
        </div>
        <div className="totals-row">
          <span className="lbl">Closing Balance :</span>
          <span className="val">
            {fmt(Math.abs(report.closing))}
            {report.closing !== 0 ? ` ${drcr(report.closing)}.` : ''}
          </span>
          <span className="val" />
        </div>
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
