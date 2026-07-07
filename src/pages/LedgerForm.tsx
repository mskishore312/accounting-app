import { useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import {
  AppBar,
  Dialog,
  PageTitle,
  PickerDialog,
  PickerField,
} from '../components/ui'
import { useStore } from '../store'
import { DrCr } from '../types'
import { fmt, fmtDate, groupsUnder } from '../accounting'

export default function LedgerForm() {
  const navigate = useNavigate()
  const { id } = useParams()
  const {
    companyGroups,
    companyLedgers,
    addLedger,
    updateLedger,
    deleteLedger,
    addGroup,
  } = useStore()
  const editing = id
    ? (companyLedgers.find((l) => l.id === id) ?? null)
    : null

  const [name, setName] = useState(editing?.name ?? '')
  const [under, setUnder] = useState(editing?.under ?? '')
  const [amount, setAmount] = useState(
    editing && editing.openingBalance
      ? String(editing.openingBalance)
      : '',
  )
  const [type, setType] = useState<DrCr>(
    editing?.openingType ?? 'Cr',
  )
  const [tinGst, setTinGst] = useState(editing?.tinGst ?? '')
  const [address, setAddress] = useState(editing?.address ?? '')
  const [contactNo, setContactNo] = useState(
    editing?.contactNo ?? '',
  )
  const [closingBalances, setClosingBalances] = useState(
    editing?.closingBalances ?? [],
  )
  const [cbDate, setCbDate] = useState('')
  const [cbValue, setCbValue] = useState('')
  const [error, setError] = useState('')
  const [groupDialog, setGroupDialog] = useState(false)

  const groupNames = companyGroups.map((g) => g.name)

  // Tally: ledgers under Stock-in-hand carry manually entered
  // opening/closing stock values (used when accounts are not
  // integrated with inventory) and never appear in vouchers.
  const isStockLedger = useMemo(
    () => groupsUnder(companyGroups, ['Stock-in-hand']).has(under),
    [companyGroups, under],
  )

  const save = () => {
    setError('')
    if (!name.trim()) return setError('Ledger name is required')
    if (!under) return setError('Under Group is required')
    const openingBalance = amount ? parseFloat(amount) : 0
    if (isNaN(openingBalance) || openingBalance < 0)
      return setError('Amount must be a positive number')
    const cb = isStockLedger ? closingBalances : undefined
    if (editing) {
      updateLedger(editing.id, {
        name: name.trim(),
        under,
        openingBalance,
        openingType: type,
        tinGst,
        address,
        contactNo,
        closingBalances: cb,
      })
      navigate(-1)
    } else {
      const res = addLedger({
        name,
        under,
        openingBalance,
        openingType: type,
        tinGst,
        address,
        contactNo,
        closingBalances: cb,
      })
      if (typeof res === 'string') setError(res)
      else navigate(-1)
    }
  }

  const del = () => {
    if (!editing) return
    if (editing.reserved) {
      setError('Default ledgers cannot be deleted')
      return
    }
    if (confirm(`Delete ledger "${editing.name}"?`)) {
      const err = deleteLedger(editing.id)
      if (err) setError(err)
      else navigate(-1)
    }
  }

  return (
    <div className="phone">
      <AppBar />
      <PageTitle>Ledger</PageTitle>
      <div className="form">
        <div className="f-row">
          <label
            className="f-label"
            style={{ minWidth: 130, marginBottom: 6 }}
          >
            Ledger
          </label>
          <div className="grow">
            <input
              className="f-input"
              value={name}
              onChange={(e) => setName(e.target.value)}
              disabled={!!editing?.reserved}
            />
          </div>
        </div>
        <div className="f-row" style={{ marginTop: 14 }}>
          <label
            className="f-label"
            style={{ minWidth: 130, marginBottom: 6 }}
          >
            Under Group
          </label>
          <div className="grow">
            <PickerField
              value={under}
              items={groupNames}
              onPick={setUnder}
            />
          </div>
          <button
            className="plus-btn"
            onClick={() => setGroupDialog(true)}
            title="Add new group"
          >
            +
          </button>
        </div>
        <div className="f-row" style={{ marginTop: 14 }}>
          <label
            className="f-label"
            style={{ minWidth: 130, marginBottom: 6 }}
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
        <div className="f-row" style={{ marginTop: 14 }}>
          <label
            className="f-label"
            style={{ minWidth: 130, marginBottom: 6 }}
          >
            Type :
          </label>
          <div className="grow">
            <select
              className="f-select"
              value={type}
              onChange={(e) => setType(e.target.value as DrCr)}
            >
              <option>Cr</option>
              <option>Dr</option>
            </select>
          </div>
        </div>
        {isStockLedger && (
          <div
            style={{
              border: '1px solid #9db29e',
              borderRadius: 4,
              padding: '10px 12px',
              marginTop: 18,
              background: '#e2f4e3',
            }}
          >
            <div style={{ fontSize: 18, color: '#14453c' }}>
              Closing Stock Values (as on date)
            </div>
            <div
              style={{ fontSize: 13, color: '#456', marginTop: 4 }}
            >
              Used in P&amp;L and Balance Sheet when “Integrate
              Accounts with Inventory” is off. The value with the
              nearest date on or before the report date applies.
            </div>
            {closingBalances
              .slice()
              .sort((a, b) => a.date.localeCompare(b.date))
              .map((e) => (
                <div
                  key={e.date}
                  className="f-row"
                  style={{ marginTop: 8, alignItems: 'center' }}
                >
                  <span style={{ flex: 1, fontSize: 17 }}>
                    {fmtDate(e.date)}
                  </span>
                  <span
                    style={{
                      flex: 1,
                      textAlign: 'right',
                      fontSize: 17,
                    }}
                  >
                    {fmt(e.value)}
                  </span>
                  <button
                    className="iconbtn"
                    style={{ color: '#8c4a3f', fontSize: 16 }}
                    title="Remove"
                    onClick={() =>
                      setClosingBalances((cbs) =>
                        cbs.filter((x) => x.date !== e.date),
                      )
                    }
                  >
                    &#10005;
                  </button>
                </div>
              ))}
            <div
              className="f-row"
              style={{ marginTop: 10, gap: 8 }}
            >
              <div style={{ flex: 1.4 }}>
                <input
                  type="date"
                  className="f-input"
                  value={cbDate}
                  onChange={(e) => setCbDate(e.target.value)}
                />
              </div>
              <div style={{ flex: 1 }}>
                <input
                  type="number"
                  min="0"
                  placeholder="Value"
                  className="f-input"
                  value={cbValue}
                  onChange={(e) => setCbValue(e.target.value)}
                />
              </div>
              <button
                className="plus-btn"
                title="Add closing value"
                onClick={() => {
                  const v = parseFloat(cbValue)
                  if (!cbDate || isNaN(v) || v < 0) return
                  setClosingBalances((cbs) => [
                    ...cbs.filter((x) => x.date !== cbDate),
                    { date: cbDate, value: v },
                  ])
                  setCbDate('')
                  setCbValue('')
                }}
              >
                +
              </button>
            </div>
          </div>
        )}
        <label className="f-label">TIN/GST No :</label>
        <input
          className="f-input"
          value={tinGst}
          onChange={(e) => setTinGst(e.target.value)}
        />
        <label className="f-label">Address :</label>
        <input
          className="f-input"
          value={address}
          onChange={(e) => setAddress(e.target.value)}
        />
        <label className="f-label">Contact No :</label>
        <input
          className="f-input"
          value={contactNo}
          onChange={(e) => setContactNo(e.target.value)}
        />
        {error && (
          <div style={{ color: '#b00020', marginTop: 12 }}>
            {error}
          </div>
        )}
        <button className="save-btn" onClick={save}>
          Save
        </button>
        {editing && !editing.reserved && (
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
        <NewGroupDialog
          groups={groupNames}
          onAdd={(n, u) => {
            const res = addGroup(n, u)
            if (typeof res === 'string') {
              alert(res)
              return
            }
            setUnder(res.name)
            setGroupDialog(false)
          }}
          onClose={() => setGroupDialog(false)}
        />
      )}
    </div>
  )
}

function NewGroupDialog({
  groups,
  onAdd,
  onClose,
}: {
  groups: string[]
  onAdd: (name: string, under: string) => void
  onClose: () => void
}) {
  const [name, setName] = useState('')
  const [under, setUnder] = useState('Primary')
  const [pick, setPick] = useState(false)
  return (
    <Dialog onClose={onClose}>
      <h3>New Group</h3>
      <label className="f-label">Group Name :</label>
      <input
        className="f-input"
        value={name}
        onChange={(e) => setName(e.target.value)}
        autoFocus
      />
      <label className="f-label">Under :</label>
      <input
        className="f-input"
        readOnly
        value={under}
        onClick={() => setPick(true)}
      />
      <div className="ok-row">
        <button
          className="ok-btn blue"
          onClick={() => name.trim() && onAdd(name, under)}
        >
          Save
        </button>
        <button className="ok-btn" onClick={onClose}>
          Cancel
        </button>
      </div>
      {pick && (
        <PickerDialog
          items={['Primary', ...groups]}
          onPick={(v) => {
            setUnder(v)
            setPick(false)
          }}
          onClose={() => setPick(false)}
        />
      )}
    </Dialog>
  )
}
