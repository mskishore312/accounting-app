import { useState } from 'react'
import { Dialog } from './ui'
import { VOUCHER_TYPES } from '../types'

export type InfoType =
  | 'Date'
  | 'Particulars'
  | 'Voucher Type'
  | 'Debit Amount'
  | 'Credit Amount'
  | 'Narration'

export type Having = 'Contains' | 'Equals' | 'Starts With' | 'Ends With'
export type NumHaving = 'Equals' | 'Greater Than' | 'Less Than'

export interface ReportFilter {
  kind: InfoType
  having?: Having
  numHaving?: NumHaving
  value: string
}

const INFO_TYPES: InfoType[] = [
  'Date',
  'Particulars',
  'Voucher Type',
  'Debit Amount',
  'Credit Amount',
  'Narration',
]

export function matchesFilter(
  f: ReportFilter | null,
  row: {
    date: string // ISO
    particulars: string
    vchType: string
    debit: number
    credit: number
    narration: string
  },
): boolean {
  if (!f) return true
  switch (f.kind) {
    case 'Date':
      return row.date === f.value
    case 'Voucher Type':
      return row.vchType === f.value
    case 'Particulars':
    case 'Narration': {
      const hay = (
        f.kind === 'Particulars' ? row.particulars : row.narration
      ).toLowerCase()
      const needle = f.value.toLowerCase()
      switch (f.having ?? 'Contains') {
        case 'Contains':
          return hay.includes(needle)
        case 'Equals':
          return hay === needle
        case 'Starts With':
          return hay.startsWith(needle)
        case 'Ends With':
          return hay.endsWith(needle)
      }
      return true
    }
    case 'Debit Amount':
    case 'Credit Amount': {
      const amt = f.kind === 'Debit Amount' ? row.debit : row.credit
      const v = parseFloat(f.value)
      if (isNaN(v)) return true
      switch (f.numHaving ?? 'Equals') {
        case 'Equals':
          return amt === v
        case 'Greater Than':
          return amt > v
        case 'Less Than':
          return amt < v
      }
      return true
    }
  }
}

export function SearchDialog({
  onApply,
  onClose,
}: {
  onApply: (f: ReportFilter) => void
  onClose: () => void
}) {
  const [kind, setKind] = useState<InfoType>('Voucher Type')
  const [having, setHaving] = useState<Having>('Contains')
  const [numHaving, setNumHaving] = useState<NumHaving>('Equals')
  const [value, setValue] = useState('')
  const [vchType, setVchType] = useState('Receipt')
  const [date, setDate] = useState('')

  const textual = kind === 'Particulars' || kind === 'Narration'
  const numeric = kind === 'Debit Amount' || kind === 'Credit Amount'

  const apply = () => {
    const f: ReportFilter = {
      kind,
      having,
      numHaving,
      value:
        kind === 'Voucher Type'
          ? vchType
          : kind === 'Date'
            ? date
            : value,
    }
    if (kind === 'Date' && !date) return
    if ((textual || numeric) && !value) return
    onApply(f)
    onClose()
  }

  return (
    <Dialog onClose={onClose}>
      <h3>Type of info</h3>
      <select
        className="f-select"
        value={kind}
        onChange={(e) => setKind(e.target.value as InfoType)}
      >
        {INFO_TYPES.map((t) => (
          <option key={t}>{t}</option>
        ))}
      </select>

      {kind === 'Date' && (
        <>
          <h3 style={{ marginTop: 18 }}>Select Date</h3>
          <input
            type="date"
            className="f-input"
            value={date}
            onChange={(e) => setDate(e.target.value)}
          />
        </>
      )}

      {kind === 'Voucher Type' && (
        <>
          <h3 style={{ marginTop: 18 }}>Select Voucher Type</h3>
          <select
            className="f-select"
            value={vchType}
            onChange={(e) => setVchType(e.target.value)}
          >
            {VOUCHER_TYPES.map((t) => (
              <option key={t}>{t}</option>
            ))}
          </select>
        </>
      )}

      {textual && (
        <>
          <h3 style={{ marginTop: 18 }}>Having</h3>
          <select
            className="f-select"
            value={having}
            onChange={(e) => setHaving(e.target.value as Having)}
          >
            <option>Contains</option>
            <option>Equals</option>
            <option>Starts With</option>
            <option>Ends With</option>
          </select>
          <h3 style={{ marginTop: 18 }}>Value</h3>
          <input
            className="f-input"
            placeholder="Value"
            value={value}
            onChange={(e) => setValue(e.target.value)}
          />
        </>
      )}

      {numeric && (
        <>
          <h3 style={{ marginTop: 18 }}>Having</h3>
          <select
            className="f-select"
            value={numHaving}
            onChange={(e) =>
              setNumHaving(e.target.value as NumHaving)
            }
          >
            <option>Equals</option>
            <option>Greater Than</option>
            <option>Less Than</option>
          </select>
          <h3 style={{ marginTop: 18 }}>Value</h3>
          <input
            className="f-input"
            type="number"
            placeholder="Value"
            value={value}
            onChange={(e) => setValue(e.target.value)}
          />
        </>
      )}

      <div className="ok-row">
        <button className="ok-btn" onClick={apply}>
          Ok
        </button>
      </div>
    </Dialog>
  )
}
