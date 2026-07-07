import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import {
  AppBar,
  ChangePeriodDialog,
  PeriodLine,
  PopupMenu,
} from '../components/ui'
import { useStore } from '../store'
import { fmt, fmtDate } from '../accounting'
import { itemMovements, stockSummary } from '../inventory'
import { exportCsv, printReport } from '../export'

export default function StockSummary() {
  const navigate = useNavigate()
  const { company, companyStockItems, companyVouchers, period } =
    useStore()
  const [menuOpen, setMenuOpen] = useState(false)
  const [periodOpen, setPeriodOpen] = useState(false)

  const rows = stockSummary(
    companyStockItems,
    companyVouchers,
    period,
  )
  const totalClose = rows.reduce((s, r) => s + r.closeValue, 0)

  const csv = () =>
    exportCsv(
      'stock-summary',
      [
        'Particulars',
        'Opening Qty',
        'Opening Value',
        'Inwards Qty',
        'Inwards Value',
        'Outwards Qty',
        'Outwards Value',
        'Closing Qty',
        'Closing Rate',
        'Closing Value',
      ],
      rows.map((r) => [
        r.item.name,
        String(r.openQty),
        fmt(r.openValue),
        String(r.inQty),
        fmt(r.inValue),
        String(r.outQty),
        fmt(r.outValue),
        String(r.closeQty),
        fmt(r.closeRate),
        fmt(r.closeValue),
      ]),
    )

  return (
    <div className="phone">
      <AppBar
        title={company?.name}
        onMenu={() => setMenuOpen((o) => !o)}
      />
      <PopupMenu
        open={menuOpen}
        onClose={() => setMenuOpen(false)}
        items={[
          { label: 'Export as Excel Sheet', onClick: csv },
          { label: 'Export As PDF', onClick: () => printReport() },
          {
            label: 'Change Period',
            onClick: () => setPeriodOpen(true),
          },
        ]}
      />
      <div className="subtitle">Stock Summary</div>
      <PeriodLine />
      <div className="table-wrap">
        <table className="rpt">
          <thead>
            <tr>
              <th>Particulars</th>
              <th className="num">
                Opening
                <br />
                Qty
              </th>
              <th className="num">
                Inwards
                <br />
                Qty
              </th>
              <th className="num">
                Outwards
                <br />
                Qty
              </th>
              <th className="num">
                Closing
                <br />
                Qty
              </th>
              <th className="num">Rate</th>
              <th className="num">Value</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr
                key={r.item.id}
                style={{ cursor: 'pointer' }}
                onClick={() =>
                  navigate(`/reports/stock/${r.item.id}`)
                }
              >
                <td>{r.item.name}</td>
                <td className="num">
                  {r.openQty} {r.item.unit}
                </td>
                <td className="num">
                  {r.inQty} {r.item.unit}
                </td>
                <td className="num">
                  {r.outQty} {r.item.unit}
                </td>
                <td className="num">
                  {r.closeQty} {r.item.unit}
                </td>
                <td className="num">{fmt(r.closeRate)}</td>
                <td className="num">{fmt(r.closeValue)}</td>
              </tr>
            ))}
          </tbody>
          <tfoot>
            <tr>
              <td colSpan={6}>Total</td>
              <td className="num">{fmt(totalClose)}</td>
            </tr>
          </tfoot>
        </table>
        {!rows.length && (
          <div className="empty-note">
            No stock items yet. Create them under Master →
            Inventory Masters.
          </div>
        )}
      </div>
      {periodOpen && (
        <ChangePeriodDialog onClose={() => setPeriodOpen(false)} />
      )}
    </div>
  )
}

/** Movement register for a single stock item */
export function StockItemReport() {
  const { itemId } = useParams()
  const { company, companyStockItems, companyVouchers, period } =
    useStore()
  const item = companyStockItems.find((s) => s.id === itemId)
  if (!item) {
    return (
      <div className="phone">
        <AppBar />
        <div className="empty-note">Stock item not found.</div>
      </div>
    )
  }
  const mv = itemMovements(item, companyVouchers, period)
  return (
    <div className="phone">
      <AppBar title={company?.name} />
      <div className="subtitle">Stock Item: {item.name}</div>
      <PeriodLine />
      <div className="table-wrap">
        <table className="rpt">
          <thead>
            <tr>
              <th>Date</th>
              <th>Vch Type</th>
              <th className="num">Vch No.</th>
              <th className="num">Inwards</th>
              <th className="num">Outwards</th>
              <th className="num">Balance</th>
            </tr>
          </thead>
          <tbody>
            {mv.rows.map((r, i) => (
              <tr key={i}>
                <td>{fmtDate(r.event.date)}</td>
                <td>{r.event.vchType}</td>
                <td className="num">{r.event.vchNo}</td>
                <td className="num">
                  {r.inQty ? `${r.inQty} ${item.unit}` : ''}
                </td>
                <td className="num">
                  {r.outQty ? `${r.outQty} ${item.unit}` : ''}
                </td>
                <td className="num">
                  {r.balance} {item.unit}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {!mv.rows.length && (
          <div className="empty-note">
            No movements in this period.
          </div>
        )}
      </div>
      <div className="totals-block">
        <div className="totals-row">
          <span className="lbl">Opening Qty :</span>
          <span className="val">
            {mv.opening} {item.unit}
          </span>
        </div>
        <div className="totals-row">
          <span className="lbl">Closing Qty :</span>
          <span className="val">
            {mv.closing} {item.unit}
          </span>
        </div>
      </div>
    </div>
  )
}
