import React, { useEffect, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useStore } from '../store'
import { fmtDate } from '../accounting'

/** Dark green top bar with the app logo + name (pre-company screens) */
export function AppBar({
  title,
  left,
  onMenu,
  onSearch,
}: {
  title?: string
  left?: boolean
  onMenu?: () => void
  onSearch?: () => void
}) {
  const navigate = useNavigate()
  return (
    <header className="appbar">
      {onMenu && (
        <button className="iconbtn" aria-label="menu" onClick={onMenu}>
          &#9776;
        </button>
      )}
      {onSearch && (
        <button
          className="iconbtn"
          aria-label="search"
          onClick={onSearch}
        >
          &#128269;
        </button>
      )}
      <div
        className={'brand' + (left ? ' left' : '')}
        onClick={() => navigate('/')}
        style={{ cursor: 'pointer' }}
      >
        {!onMenu && !onSearch && (
          <span className="logo">
            A/c
            <br />
            App
          </span>
        )}
        <span>{title ?? 'Accounting App (V 1.0)'}</span>
      </div>
    </header>
  )
}

export function PageTitle({ children }: { children: React.ReactNode }) {
  return <div className="pagetitle">{children}</div>
}

export function MenuButtons({
  items,
}: {
  items: Array<{ label: string; onClick: () => void }>
}) {
  return (
    <div className="menu-list">
      {items.map((it) => (
        <button
          key={it.label}
          className="menu-btn"
          onClick={it.onClick}
        >
          {it.label}
        </button>
      ))}
    </div>
  )
}

export function PeriodLine() {
  const { period } = useStore()
  return (
    <div className="subtitle2">
      Curr. Period {fmtDate(period.from)} to {fmtDate(period.to)}
    </div>
  )
}

/** Modal overlay */
export function Dialog({
  children,
  onClose,
}: {
  children: React.ReactNode
  onClose: () => void
}) {
  return (
    <div
      className="overlay"
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose()
      }}
    >
      <div className="dialog">{children}</div>
    </div>
  )
}

/** Searchable picker dialog: "Please select from below" */
export function PickerDialog({
  items,
  onPick,
  onClose,
}: {
  items: string[]
  onPick: (v: string) => void
  onClose: () => void
}) {
  const [q, setQ] = useState('')
  const filtered = items.filter((i) =>
    i.toLowerCase().includes(q.toLowerCase()),
  )
  return (
    <Dialog onClose={onClose}>
      <h3 className="blue">Please select from below</h3>
      <div className="searchbar" style={{ margin: '0 0 4px' }}>
        <span>&#128269;</span>
        <input
          placeholder="Search"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          autoFocus
        />
      </div>
      <ul className="pick-list">
        {filtered.map((i) => (
          <li key={i} onClick={() => onPick(i)}>
            {i}
          </li>
        ))}
        {!filtered.length && (
          <li style={{ color: '#777' }}>No matches</li>
        )}
      </ul>
    </Dialog>
  )
}

/** Field + popup picker that looks like an underlined input */
export function PickerField({
  value,
  placeholder,
  items,
  onPick,
}: {
  value: string
  placeholder?: string
  items: string[]
  onPick: (v: string) => void
}) {
  const [open, setOpen] = useState(false)
  return (
    <>
      <input
        className="f-input"
        readOnly
        value={value}
        placeholder={placeholder}
        onClick={() => setOpen(true)}
      />
      {open && (
        <PickerDialog
          items={items}
          onPick={(v) => {
            onPick(v)
            setOpen(false)
          }}
          onClose={() => setOpen(false)}
        />
      )}
    </>
  )
}

/** Simple hamburger popup menu */
export function PopupMenu({
  open,
  items,
  onClose,
}: {
  open: boolean
  items: Array<{ label: string; onClick: () => void }>
  onClose: () => void
}) {
  const ref = useRef<HTMLDivElement>(null)
  useEffect(() => {
    if (!open) return
    const h = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node))
        onClose()
    }
    document.addEventListener('mousedown', h)
    return () => document.removeEventListener('mousedown', h)
  }, [open, onClose])
  if (!open) return null
  return (
    <div className="popup-menu" ref={ref}>
      {items.map((it) => (
        <button
          key={it.label}
          onClick={() => {
            onClose()
            it.onClick()
          }}
        >
          {it.label}
        </button>
      ))}
    </div>
  )
}

/** Change Period dialog (From / To / Ok) */
export function ChangePeriodDialog({ onClose }: { onClose: () => void }) {
  const { period, setPeriod } = useStore()
  const [from, setFrom] = useState(period.from)
  const [to, setTo] = useState(period.to)
  return (
    <Dialog onClose={onClose}>
      <h3>Select Date Range</h3>
      <label className="f-label" style={{ color: '#14453c' }}>
        From :
      </label>
      <input
        type="date"
        className="f-input"
        value={from}
        onChange={(e) => setFrom(e.target.value)}
      />
      <label className="f-label" style={{ color: '#14453c' }}>
        To :
      </label>
      <input
        type="date"
        className="f-input"
        value={to}
        onChange={(e) => setTo(e.target.value)}
      />
      <div className="ok-row right">
        <button
          className="ok-btn blue"
          onClick={() => {
            if (from && to && from <= to) {
              setPeriod({ from, to })
              onClose()
            }
          }}
        >
          Ok
        </button>
      </div>
    </Dialog>
  )
}
