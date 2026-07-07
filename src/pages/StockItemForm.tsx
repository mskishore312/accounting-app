import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import {
  AppBar,
  Dialog,
  PageTitle,
  PickerField,
} from '../components/ui'
import { useStore } from '../store'
import { ValuationMethod, VALUATION_METHODS } from '../types'

export default function StockItemForm() {
  const navigate = useNavigate()
  const { id } = useParams()
  const {
    companyStockItems,
    companyStockGroups,
    companyUnits,
    addStockItem,
    updateStockItem,
    deleteStockItem,
    addStockGroup,
    addUnit,
  } = useStore()

  const editing = id
    ? (companyStockItems.find((s) => s.id === id) ?? null)
    : null

  const [name, setName] = useState(editing?.name ?? '')
  const [group, setGroup] = useState(editing?.group ?? 'Primary')
  const [unit, setUnit] = useState(editing?.unit ?? '')
  const [openingQty, setOpeningQty] = useState(
    editing?.openingQty ? String(editing.openingQty) : '',
  )
  const [openingRate, setOpeningRate] = useState(
    editing?.openingRate ? String(editing.openingRate) : '',
  )
  const [valuation, setValuation] = useState<ValuationMethod>(
    editing?.valuation ?? 'Avg. Cost',
  )
  const [stdCost, setStdCost] = useState(
    editing?.stdCost ? String(editing.stdCost) : '',
  )
  const [error, setError] = useState('')
  const [groupDialog, setGroupDialog] = useState(false)
  const [unitDialog, setUnitDialog] = useState(false)

  const save = () => {
    setError('')
    if (!name.trim()) return setError('Item name is required')
    if (!unit) return setError('Unit is required')
    const qty = openingQty ? parseFloat(openingQty) : 0
    const rate = openingRate ? parseFloat(openingRate) : 0
    if (isNaN(qty) || qty < 0)
      return setError('Opening Qty must be a positive number')
    if (isNaN(rate) || rate < 0)
      return setError('Opening Rate must be a positive number')
    const std = stdCost ? parseFloat(stdCost) : undefined
    const payload = {
      name,
      group,
      unit,
      openingQty: qty,
      openingRate: rate,
      valuation,
      stdCost: std,
    }
    if (editing) {
      updateStockItem(editing.id, payload)
      navigate(-1)
    } else {
      const res = addStockItem(payload)
      if (typeof res === 'string') setError(res)
      else navigate(-1)
    }
  }

  const del = () => {
    if (!editing) return
    if (confirm(`Delete stock item "${editing.name}"?`)) {
      const err = deleteStockItem(editing.id)
      if (err) setError(err)
      else navigate(-1)
    }
  }

  return (
    <div className="phone">
      <AppBar />
      <PageTitle>Stock Item</PageTitle>
      <div className="form">
        <div className="f-row">
          <label
            className="f-label"
            style={{ minWidth: 130, marginBottom: 6 }}
          >
            Name
          </label>
          <div className="grow">
            <input
              className="f-input"
              value={name}
              onChange={(e) => setName(e.target.value)}
            />
          </div>
        </div>
        <div className="f-row" style={{ marginTop: 14 }}>
          <label
            className="f-label"
            style={{ minWidth: 130, marginBottom: 6 }}
          >
            Under
          </label>
          <div className="grow">
            <PickerField
              value={group}
              items={[
                'Primary',
                ...companyStockGroups.map((g) => g.name),
              ]}
              onPick={setGroup}
            />
          </div>
          <button
            className="plus-btn"
            title="Add stock group"
            onClick={() => setGroupDialog(true)}
          >
            +
          </button>
        </div>
        <div className="f-row" style={{ marginTop: 14 }}>
          <label
            className="f-label"
            style={{ minWidth: 130, marginBottom: 6 }}
          >
            Unit
          </label>
          <div className="grow">
            <PickerField
              value={unit}
              items={companyUnits.map((u) => u.symbol)}
              onPick={setUnit}
            />
          </div>
          <button
            className="plus-btn"
            title="Add unit"
            onClick={() => setUnitDialog(true)}
          >
            +
          </button>
        </div>
        <div className="f-row" style={{ marginTop: 14 }}>
          <label
            className="f-label"
            style={{ minWidth: 130, marginBottom: 6 }}
          >
            Opening Qty :
          </label>
          <div className="grow">
            <input
              className="f-input"
              type="number"
              min="0"
              value={openingQty}
              onChange={(e) => setOpeningQty(e.target.value)}
            />
          </div>
        </div>
        <div className="f-row" style={{ marginTop: 14 }}>
          <label
            className="f-label"
            style={{ minWidth: 130, marginBottom: 6 }}
          >
            Opening Rate :
          </label>
          <div className="grow">
            <input
              className="f-input"
              type="number"
              min="0"
              value={openingRate}
              onChange={(e) => setOpeningRate(e.target.value)}
            />
          </div>
        </div>
        <div className="f-row" style={{ marginTop: 14 }}>
          <label
            className="f-label"
            style={{ minWidth: 130, marginBottom: 6 }}
          >
            Costing Method :
          </label>
          <div className="grow">
            <select
              className="f-select"
              value={valuation}
              onChange={(e) =>
                setValuation(e.target.value as ValuationMethod)
              }
            >
              {VALUATION_METHODS.map((m) => (
                <option key={m}>{m}</option>
              ))}
            </select>
          </div>
        </div>
        {valuation === 'Std. Cost' && (
          <div className="f-row" style={{ marginTop: 14 }}>
            <label
              className="f-label"
              style={{ minWidth: 130, marginBottom: 6 }}
            >
              Standard Cost :
            </label>
            <div className="grow">
              <input
                className="f-input"
                type="number"
                min="0"
                value={stdCost}
                onChange={(e) => setStdCost(e.target.value)}
              />
            </div>
          </div>
        )}
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
      {groupDialog && (
        <NameUnderDialog
          title="New Stock Group"
          unders={[
            'Primary',
            ...companyStockGroups.map((g) => g.name),
          ]}
          onAdd={(n, u) => {
            const res = addStockGroup({ name: n, under: u })
            if (typeof res === 'string') {
              alert(res)
              return
            }
            setGroup(res.name)
            setGroupDialog(false)
          }}
          onClose={() => setGroupDialog(false)}
        />
      )}
      {unitDialog && (
        <UnitDialog
          onAdd={(symbol, formalName) => {
            const res = addUnit({ symbol, formalName })
            if (typeof res === 'string') {
              alert(res)
              return
            }
            setUnit(res.symbol)
            setUnitDialog(false)
          }}
          onClose={() => setUnitDialog(false)}
        />
      )}
    </div>
  )
}

export function NameUnderDialog({
  title,
  unders,
  onAdd,
  onClose,
}: {
  title: string
  unders: string[]
  onAdd: (name: string, under: string) => void
  onClose: () => void
}) {
  const [name, setName] = useState('')
  const [under, setUnder] = useState('Primary')
  return (
    <Dialog onClose={onClose}>
      <h3>{title}</h3>
      <label className="f-label">Name :</label>
      <input
        className="f-input"
        value={name}
        onChange={(e) => setName(e.target.value)}
        autoFocus
      />
      <label className="f-label">Under :</label>
      <select
        className="f-select"
        value={under}
        onChange={(e) => setUnder(e.target.value)}
      >
        {unders.map((u) => (
          <option key={u}>{u}</option>
        ))}
      </select>
      <div className="ok-row">
        <button
          className="ok-btn blue"
          onClick={() => name.trim() && onAdd(name.trim(), under)}
        >
          Save
        </button>
        <button className="ok-btn" onClick={onClose}>
          Cancel
        </button>
      </div>
    </Dialog>
  )
}

export function UnitDialog({
  onAdd,
  onClose,
}: {
  onAdd: (symbol: string, formalName: string) => void
  onClose: () => void
}) {
  const [symbol, setSymbol] = useState('')
  const [formal, setFormal] = useState('')
  return (
    <Dialog onClose={onClose}>
      <h3>New Unit</h3>
      <label className="f-label">Symbol :</label>
      <input
        className="f-input"
        placeholder="Nos"
        value={symbol}
        onChange={(e) => setSymbol(e.target.value)}
        autoFocus
      />
      <label className="f-label">Formal Name :</label>
      <input
        className="f-input"
        placeholder="Numbers"
        value={formal}
        onChange={(e) => setFormal(e.target.value)}
      />
      <div className="ok-row">
        <button
          className="ok-btn blue"
          onClick={() =>
            symbol.trim() && onAdd(symbol.trim(), formal.trim())
          }
        >
          Save
        </button>
        <button className="ok-btn" onClick={onClose}>
          Cancel
        </button>
      </div>
    </Dialog>
  )
}
