import { useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import {
  AppBar,
  PageTitle,
  PickerField,
} from '../components/ui'
import { useStore } from '../store'
import { VoucherType } from '../types'
import { groupsUnder } from '../accounting'

function titleCase(s: string): VoucherType {
  return (s.charAt(0).toUpperCase() +
    s.slice(1).toLowerCase()) as VoucherType
}

/**
 * Field labels per voucher type. First field is the "main" account,
 * second is the counter account (defaults to Cash).
 *   Receipt : Cr / To  (source of money)   |  Dr / By (cash/bank)
 *   Payment : Dr / To  (expense/party)     |  Cr / By (cash/bank)
 *   Contra  : Dr / To  (cash/bank)         |  Cr / By (cash/bank)
 *   Journal : Dr / By                       |  Cr / To
 *   Sales   : Cr / To  (sales a/c)          |  Dr / By (party/cash)
 *   Purchase: Dr / To  (purchase a/c)       |  Cr / By (party/cash)
 */
const CONFIG: Record<
  VoucherType,
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
}

export default function VoucherForm() {
  const navigate = useNavigate()
  const { type, id } = useParams()
  const vchType = titleCase(type ?? 'receipt')
  const cfg = CONFIG[vchType]
  const {
    companyLedgers,
    companyGroups,
    companyVouchers,
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

  const cashBankNames = useMemo(() => {
    const names = groupsUnder(companyGroups, [
      'Cash-in-hand',
      'Bank Accounts',
      'Bank OD A/c',
    ])
    return companyLedgers
      .filter((l) => names.has(l.under))
      .map((l) => l.name)
  }, [companyGroups, companyLedgers])

  const allNames = companyLedgers.map((l) => l.name)

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
  const [error, setError] = useState('')

  // Contra moves money between cash/bank ledgers only.
  const firstItems = vchType === 'Contra' ? cashBankNames : allNames
  const secondItems =
    vchType === 'Contra' || vchType === 'Receipt' || vchType === 'Payment'
      ? cashBankNames
      : allNames

  const save = () => {
    setError('')
    const amt = parseFloat(amount)
    if (!date) return setError('Date is required')
    if (!first) return setError(`${cfg.first.replace(' :', '')} ledger is required`)
    if (!second) return setError(`${cfg.second.replace(' :', '')} ledger is required`)
    if (first === second)
      return setError('Both sides cannot be the same ledger')
    if (isNaN(amt) || amt <= 0)
      return setError('Amount must be greater than zero')
    const firstId = idOf(first)
    const secondId = idOf(second)
    if (!firstId || !secondId) return setError('Unknown ledger')

    const lines = [
      { ledgerId: firstId, type: cfg.firstIs, amount: amt },
      {
        ledgerId: secondId,
        type: cfg.firstIs === 'Dr' ? ('Cr' as const) : ('Dr' as const),
        amount: amt,
      },
    ]
    if (editing) {
      updateVoucher(editing.id, { date, lines, narration })
    } else {
      addVoucher({ vchType, date, lines, narration })
    }
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
      <AppBar />
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
              value={amount}
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
    </div>
  )
}
