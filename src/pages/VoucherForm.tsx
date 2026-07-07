import { useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import {
  AppBar,
  PageTitle,
  PickerDialog,
  PickerField,
} from '../components/ui'
import { useStore } from '../store'
import {
  InventoryLine,
  VoucherType,
  vchFromSlug,
} from '../types'
import { fmt, groupsUnder } from '../accounting'
import { inventoryDirection, invTotal } from '../inventory'

/**
 * Field labels per voucher type. First field is the "main" account,
 * second is the counter account (defaults to Cash).
 */
const CONFIG: Record<
  string,
  { first: string; second: string; firstIs: 'Dr' | 'Cr' }
> = {
  Receipt: { first: 'Cr / To :', second: 'Dr / By :', firstIs: 'Cr' },
  Payment: { first: 'Dr / To :', second: 'Cr / By :', firstIs: 'Dr' },
  Contra: { first: 'Dr / To :', second: 'Cr / By :', firstIs: 'Dr' },
  Journal: { first: 'Dr / By :', second: 'Cr / To :', firstIs: 'Dr' },
  Sales: { first: 'Cr / To :', second: 'Dr / By :', firstIs: 'Cr' },
  Purchase: {
    first: 'Dr / To :',
    second: 'Cr / By :',
    firstIs: 'Dr',
  },
  // Purchase return: debit the supplier, credit Purchase a/c
  'Debit Note': {
    first: 'Dr / To :',
    second: 'Cr / By :',
    firstIs: 'Dr',
  },
  // Sales return: credit the customer, debit Sales a/c
  'Credit Note': {
    first: 'Cr / To :',
    second: 'Dr / By :',
    firstIs: 'Cr',
  },
}

interface ItemRow {
  itemId: string
  qty: string
  rate: string
}

export default function VoucherForm() {
  const navigate = useNavigate()
  const { type, id } = useParams()
  const vchType: VoucherType = vchFromSlug(type ?? 'receipt')
  const cfg = CONFIG[vchType] ?? CONFIG.Journal
  const withItems = inventoryDirection(vchType) !== null
  const {
    company,
    companyLedgers,
    companyGroups,
    companyVouchers,
    companyStockItems,
    addVoucher,
    updateVoucher,
    deleteVoucher,
  } = useStore()

  const editing = id
    ? (companyVouchers.find((v) => v.id === id) ?? null)
    : null

  const nameOf = (lid: string) =>
    companyLedgers.find((l) => l.id === lid)?.name ?? ''
  const idOf = (name: string) =>
    companyLedgers.find((l) => l.name === name)?.id ?? null

  // Stock-in-hand ledgers are valuation-only and never posted.
  const stockLedgerNames = useMemo(
    () => groupsUnder(companyGroups, ['Stock-in-hand']),
    [companyGroups],
  )
  const postable = useMemo(
    () =>
      companyLedgers.filter(
        (l) =>
          !stockLedgerNames.has(l.under) &&
          l.name !== 'Profit & Loss A/c',
      ),
    [companyLedgers, stockLedgerNames],
  )

  const cashBankNames = useMemo(() => {
    const names = groupsUnder(companyGroups, [
      'Cash-in-hand',
      'Bank Accounts',
      'Bank OD A/c',
    ])
    return postable
      .filter((l) => names.has(l.under))
      .map((l) => l.name)
  }, [companyGroups, postable])

  const allNames = postable.map((l) => l.name)

  const editFirst = editing
    ? editing.lines.find((l) => l.type === cfg.firstIs)
    : null
  const editSecond = editing
    ? editing.lines.find((l) => l.type !== cfg.firstIs)
    : null

  const [date, setDate] = useState(
    editing?.date ?? new Date().toISOString().slice(0, 10),
  )
  const [first, setFirst] = useState(
    editFirst ? nameOf(editFirst.ledgerId) : '',
  )
  const [second, setSecond] = useState(
    editSecond
      ? nameOf(editSecond.ledgerId)
      : vchType === 'Contra' || vchType === 'Journal'
        ? ''
        : 'Cash',
  )
  const [amount, setAmount] = useState(
    editing ? String(editFirst?.amount ?? '') : '',
  )
  const [narration, setNarration] = useState(
    editing?.narration ?? '',
  )
  const [items, setItems] = useState<ItemRow[]>(
    (editing?.invLines ?? []).map((l) => ({
      itemId: l.itemId,
      qty: String(l.qty),
      rate: String(l.rate),
    })),
  )
  const [error, setError] = useState('')
  const [pickItemFor, setPickItemFor] = useState<number | null>(
    null,
  )

  const itemName = (iid: string) =>
    companyStockItems.find((s) => s.id === iid)?.name ?? ''

  // Contra moves money between cash/bank ledgers only.
  const firstItems = vchType === 'Contra' ? cashBankNames : allNames
  const secondItems =
    vchType === 'Contra' ||
    vchType === 'Receipt' ||
    vchType === 'Payment'
      ? cashBankNames
      : allNames

  const parsedItems: InventoryLine[] = items
    .filter((r) => r.itemId && parseFloat(r.qty) > 0)
    .map((r) => {
      const qty = parseFloat(r.qty) || 0
      const rate = parseFloat(r.rate) || 0
      return { itemId: r.itemId, qty, rate, amount: qty * rate }
    })
  const itemsTotal = invTotal(parsedItems)
  const effectiveAmount = parsedItems.length
    ? itemsTotal
    : parseFloat(amount)

  const save = () => {
    setError('')
    if (!date) return setError('Date is required')
    if (!first)
      return setError(
        `${cfg.first.replace(' :', '')} ledger is required`,
      )
    if (!second)
      return setError(
        `${cfg.second.replace(' :', '')} ledger is required`,
      )
    if (first === second)
      return setError('Both sides cannot be the same ledger')
    if (isNaN(effectiveAmount) || effectiveAmount <= 0)
      return setError('Amount must be greater than zero')
    const firstId = idOf(first)
    const secondId = idOf(second)
    if (!firstId || !secondId) return setError('Unknown ledger')

    const lines = [
      {
        ledgerId: firstId,
        type: cfg.firstIs,
        amount: effectiveAmount,
      },
      {
        ledgerId: secondId,
        type:
          cfg.firstIs === 'Dr' ? ('Cr' as const) : ('Dr' as const),
        amount: effectiveAmount,
      },
    ]
    const payload = {
      date,
      lines,
      narration,
      invLines: parsedItems.length ? parsedItems : undefined,
    }
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
        <div className="f-row" style={{ marginTop: 14 }}>
          <label
            className="f-label"
            style={{ minWidth: 110, marginBottom: 6 }}
          >
            {cfg.first}
          </label>
          <div className="grow">
            <PickerField
              value={first}
              items={firstItems}
              onPick={setFirst}
            />
          </div>
          <button
            className="plus-btn"
            title="Add new ledger"
            onClick={() => navigate('/masters/ledgers/new')}
          >
            +
          </button>
        </div>
        <div className="f-row" style={{ marginTop: 14 }}>
          <label
            className="f-label"
            style={{ minWidth: 110, marginBottom: 6 }}
          >
            {cfg.second}
          </label>
          <div className="grow">
            <PickerField
              value={second}
              items={secondItems}
              onPick={setSecond}
            />
          </div>
        </div>

        {withItems && (
          <>
            <label className="f-label" style={{ marginTop: 20 }}>
              Stock Items :
            </label>
            {items.map((r, i) => (
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
                    onClick={() => setPickItemFor(i)}
                  />
                </div>
                <div style={{ flex: 1.2 }}>
                  <input
                    className="f-input"
                    type="number"
                    min="0"
                    placeholder="Qty"
                    value={r.qty}
                    onChange={(e) =>
                      setItems((rows) =>
                        rows.map((x, j) =>
                          j === i
                            ? { ...x, qty: e.target.value }
                            : x,
                        ),
                      )
                    }
                  />
                </div>
                <div style={{ flex: 1.5 }}>
                  <input
                    className="f-input"
                    type="number"
                    min="0"
                    placeholder="Rate"
                    value={r.rate}
                    onChange={(e) =>
                      setItems((rows) =>
                        rows.map((x, j) =>
                          j === i
                            ? { ...x, rate: e.target.value }
                            : x,
                        ),
                      )
                    }
                  />
                </div>
                <div
                  style={{
                    flex: 1.6,
                    textAlign: 'right',
                    fontSize: 17,
                    paddingBottom: 8,
                  }}
                >
                  {fmt(
                    (parseFloat(r.qty) || 0) *
                      (parseFloat(r.rate) || 0),
                  )}
                </div>
                <button
                  className="iconbtn"
                  style={{ color: '#8c4a3f', fontSize: 16 }}
                  title="Remove"
                  onClick={() =>
                    setItems((rows) =>
                      rows.filter((_, j) => j !== i),
                    )
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
                setItems((rows) => [
                  ...rows,
                  { itemId: '', qty: '', rate: '' },
                ])
              }
            >
              +
            </button>
            {parsedItems.length > 0 && (
              <div
                style={{
                  textAlign: 'right',
                  fontSize: 18,
                  marginTop: 8,
                  fontWeight: 700,
                }}
              >
                Items Total : {fmt(itemsTotal)}
              </div>
            )}
          </>
        )}

        <div className="f-row" style={{ marginTop: 14 }}>
          <label
            className="f-label"
            style={{ minWidth: 110, marginBottom: 6 }}
          >
            Amount :
          </label>
          <div className="grow">
            <input
              className="f-input"
              type="number"
              min="0"
              value={
                parsedItems.length ? String(itemsTotal) : amount
              }
              disabled={parsedItems.length > 0}
              onChange={(e) => setAmount(e.target.value)}
            />
          </div>
        </div>
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
      {pickItemFor !== null && (
        <PickerDialog
          items={companyStockItems.map((s) => s.name)}
          onPick={(name) => {
            const item = companyStockItems.find(
              (s) => s.name === name,
            )
            if (item)
              setItems((rows) =>
                rows.map((x, j) =>
                  j === pickItemFor
                    ? {
                        ...x,
                        itemId: item.id,
                        rate:
                          x.rate ||
                          (item.openingRate
                            ? String(item.openingRate)
                            : ''),
                      }
                    : x,
                ),
              )
            setPickItemFor(null)
          }}
          onClose={() => setPickItemFor(null)}
        />
      )}
    </div>
  )
}
