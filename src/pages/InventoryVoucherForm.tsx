import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import {
  AppBar,
  PageTitle,
  PickerDialog,
} from '../components/ui'
import { useStore } from '../store'
import { InventoryLine } from '../types'
import { fmt } from '../accounting'
import { itemStateAsOn } from '../inventory'

interface Row {
  itemId: string
  qty: string
  rate: string
}

function toLines(
  rows: Row[],
  dir?: 'in' | 'out',
): InventoryLine[] {
  return rows
    .filter((r) => r.itemId && parseFloat(r.qty) >= 0 && r.qty !== '')
    .map((r) => {
      const qty = parseFloat(r.qty) || 0
      const rate = parseFloat(r.rate) || 0
      return { itemId: r.itemId, qty, rate, amount: qty * rate, dir }
    })
}

/**
 * Stock Journal: transfer/manufacture — consumption (source) lines
 * go out of stock, production (destination) lines come in.
 * Physical Stock: records the counted quantity per item as on the
 * voucher date; stock balance is reset to the counted figure.
 */
export default function InventoryVoucherForm({
  physical,
}: {
  physical?: boolean
}) {
  const navigate = useNavigate()
  const { id } = useParams()
  const vchType = physical ? 'Physical Stock' : 'Stock Journal'
  const {
    company,
    companyStockItems,
    companyVouchers,
    addVoucher,
    updateVoucher,
    deleteVoucher,
  } = useStore()

  const editing = id
    ? (companyVouchers.find((v) => v.id === id) ?? null)
    : null

  const editRows = (dir?: 'in' | 'out') =>
    (editing?.invLines ?? [])
      .filter((l) => (physical ? true : l.dir === dir))
      .map((l) => ({
        itemId: l.itemId,
        qty: String(l.qty),
        rate: String(l.rate),
      }))

  const [date, setDate] = useState(
    editing?.date ?? new Date().toISOString().slice(0, 10),
  )
  const [outRows, setOutRows] = useState<Row[]>(
    physical ? [] : editRows('out'),
  )
  const [inRows, setInRows] = useState<Row[]>(
    physical ? editRows() : editRows('in'),
  )
  const [narration, setNarration] = useState(
    editing?.narration ?? '',
  )
  const [error, setError] = useState('')
  const [picker, setPicker] = useState<{
    list: 'in' | 'out'
    index: number
  } | null>(null)

  const itemName = (iid: string) =>
    companyStockItems.find((s) => s.id === iid)?.name ?? ''

  const save = () => {
    setError('')
    if (!date) return setError('Date is required')
    const cons = physical ? [] : toLines(outRows, 'out')
    const prod = toLines(inRows, physical ? undefined : 'in')
    if (physical && !prod.length)
      return setError('Add at least one counted item')
    if (!physical && !cons.length && !prod.length)
      return setError('Add source or destination items')
    const invLines = [...cons, ...prod]
    const payload = { date, lines: [], narration, invLines }
    if (editing) updateVoucher(editing.id, payload)
    else addVoucher({ vchType, ...payload })
    navigate(-1)
  }

  const del = () => {
    if (!editing) return
    if (confirm('Delete this voucher?')) {
      deleteVoucher(editing.id)
      navigate(-1)
    }
  }

  const renderRows = (
    rows: Row[],
    setRows: React.Dispatch<React.SetStateAction<Row[]>>,
    list: 'in' | 'out',
    withRate: boolean,
  ) => (
    <>
      {rows.map((r, i) => (
        <div
          className="f-row"
          key={i}
          style={{ marginTop: 6, gap: 6 }}
        >
          <div style={{ flex: 3 }}>
            <input
              className="f-input"
              readOnly
              placeholder="Item"
              value={itemName(r.itemId)}
              onClick={() => setPicker({ list, index: i })}
            />
          </div>
          <div style={{ flex: 1.3 }}>
            <input
              className="f-input"
              type="number"
              min="0"
              placeholder="Qty"
              value={r.qty}
              onChange={(e) =>
                setRows((rs) =>
                  rs.map((x, j) =>
                    j === i ? { ...x, qty: e.target.value } : x,
                  ),
                )
              }
            />
          </div>
          {withRate && (
            <div style={{ flex: 1.5 }}>
              <input
                className="f-input"
                type="number"
                min="0"
                placeholder="Rate"
                value={r.rate}
                onChange={(e) =>
                  setRows((rs) =>
                    rs.map((x, j) =>
                      j === i ? { ...x, rate: e.target.value } : x,
                    ),
                  )
                }
              />
            </div>
          )}
          <button
            className="iconbtn"
            style={{ color: '#8c4a3f', fontSize: 16 }}
            title="Remove"
            onClick={() =>
              setRows((rs) => rs.filter((_, j) => j !== i))
            }
          >
            &#10005;
          </button>
        </div>
      ))}
      <button
        className="plus-btn"
        style={{ marginTop: 10 }}
        onClick={() =>
          setRows((rs) => [...rs, { itemId: '', qty: '', rate: '' }])
        }
      >
        +
      </button>
    </>
  )

  return (
    <div className="phone">
      <AppBar title={company?.name} />
      <PageTitle>{vchType}</PageTitle>
      <div className="form">
        <div className="f-row">
          <label
            className="f-label"
            style={{ minWidth: 110, marginBottom: 6 }}
          >
            Date :
          </label>
          <div className="grow">
            <input
              type="date"
              className="f-input"
              value={date}
              onChange={(e) => setDate(e.target.value)}
            />
          </div>
        </div>

        {physical ? (
          <>
            <label className="f-label" style={{ marginTop: 18 }}>
              Counted Items (actual quantity on hand) :
            </label>
            {renderRows(inRows, setInRows, 'in', false)}
            {inRows.some((r) => r.itemId) && (
              <div
                style={{ fontSize: 14, color: '#456', marginTop: 8 }}
              >
                {inRows
                  .filter((r) => r.itemId)
                  .map((r) => {
                    const item = companyStockItems.find(
                      (s) => s.id === r.itemId,
                    )
                    if (!item) return null
                    const book = itemStateAsOn(
                      item,
                      companyVouchers.filter(
                        (v) => v.id !== editing?.id,
                      ),
                      date,
                    ).qty
                    return (
                      <div key={r.itemId}>
                        {item.name}: book qty {book} → counted{' '}
                        {r.qty || 0}
                      </div>
                    )
                  })}
              </div>
            )}
          </>
        ) : (
          <>
            <label className="f-label" style={{ marginTop: 18 }}>
              Source (Consumption) :
            </label>
            {renderRows(outRows, setOutRows, 'out', true)}
            <label className="f-label" style={{ marginTop: 18 }}>
              Destination (Production) :
            </label>
            {renderRows(inRows, setInRows, 'in', true)}
            <div
              style={{
                textAlign: 'right',
                fontSize: 16,
                marginTop: 8,
              }}
            >
              Consumption: {fmt(
                toLines(outRows).reduce((s, l) => s + l.amount, 0),
              )}{' '}
              | Production:{' '}
              {fmt(
                toLines(inRows).reduce((s, l) => s + l.amount, 0),
              )}
            </div>
          </>
        )}

        <label className="f-label" style={{ marginTop: 24 }}>
          Narration :
        </label>
        <input
          className="f-input"
          value={narration}
          onChange={(e) => setNarration(e.target.value)}
        />
        {error && (
          <div style={{ color: '#b00020', marginTop: 12 }}>
            {error}
          </div>
        )}
        <button className="save-btn" onClick={save}>
          Save
        </button>
        {editing && (
          <button
            className="save-btn"
            style={{ background: '#8c4a3f', marginTop: 0 }}
            onClick={del}
          >
            Delete
          </button>
        )}
      </div>
      {picker && (
        <PickerDialog
          items={companyStockItems.map((s) => s.name)}
          onPick={(name) => {
            const item = companyStockItems.find(
              (s) => s.name === name,
            )
            const setRows =
              picker.list === 'in' ? setInRows : setOutRows
            if (item)
              setRows((rs) =>
                rs.map((x, j) =>
                  j === picker.index
                    ? { ...x, itemId: item.id }
                    : x,
                ),
              )
            setPicker(null)
          }}
          onClose={() => setPicker(null)}
        />
      )}
    </div>
  )
}
