import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { AppBar, PageTitle } from '../components/ui'
import { useStore } from '../store'
import { INDIAN_STATES } from '../types'

export default function CompanyForm({ edit }: { edit?: boolean }) {
  const { id } = useParams()
  const navigate = useNavigate()
  const {
    data,
    createCompany,
    updateCompany,
    setActiveCompany,
    company: active,
  } = useStore()
  const editing = edit
    ? (data.companies.find((c) => c.id === (id ?? active?.id)) ?? null)
    : null

  const [name, setName] = useState(editing?.name ?? '')
  const [address, setAddress] = useState(editing?.address ?? '')
  const [contactNo, setContactNo] = useState(
    editing?.contactNo ?? '',
  )
  const [tinGst, setTinGst] = useState(editing?.tinGst ?? '')
  const [state, setState] = useState(
    editing?.state ?? INDIAN_STATES[0],
  )
  const [security, setSecurity] = useState(
    editing?.security ?? false,
  )
  const [finYearFrom, setFinYearFrom] = useState(
    editing?.finYearFrom ?? '',
  )
  const [booksFrom, setBooksFrom] = useState(
    editing?.booksFrom ?? '',
  )
  const [error, setError] = useState('')

  const save = () => {
    if (!name.trim()) {
      setError('Company Name is required')
      return
    }
    if (!finYearFrom) {
      setError('Fin. Year From is required')
      return
    }
    if (editing) {
      updateCompany(editing.id, {
        name: name.trim(),
        address,
        contactNo,
        tinGst,
        state,
        security,
        finYearFrom,
        booksFrom: booksFrom || finYearFrom,
      })
      navigate(-1)
    } else {
      const c = createCompany({
        name: name.trim(),
        address,
        contactNo,
        tinGst,
        state,
        security,
        finYearFrom,
        booksFrom: booksFrom || finYearFrom,
      })
      setActiveCompany(c.id)
      navigate('/gateway')
    }
  }

  return (
    <div className="phone">
      <AppBar />
      <PageTitle>{editing ? 'Company Edit' : 'New Company'}</PageTitle>
      <div className="form">
        <label className="f-label">Company Name :</label>
        <input
          className="f-input"
          placeholder="Your Company Name"
          value={name}
          onChange={(e) => setName(e.target.value)}
        />
        <label className="f-label">Company Address:</label>
        <textarea
          className="f-input"
          placeholder="Company Address"
          rows={3}
          value={address}
          onChange={(e) => setAddress(e.target.value)}
        />
        <label className="f-label">Contact No :</label>
        <input
          className="f-input"
          placeholder="8072197432"
          value={contactNo}
          onChange={(e) => setContactNo(e.target.value)}
        />
        <label className="f-label">TIN/GST :</label>
        <input
          className="f-input"
          placeholder="TIN/GST No."
          value={tinGst}
          onChange={(e) => setTinGst(e.target.value)}
        />
        <label className="f-label">State :</label>
        <select
          className="f-select"
          value={state}
          onChange={(e) => setState(e.target.value)}
        >
          {INDIAN_STATES.map((s) => (
            <option key={s}>{s}</option>
          ))}
        </select>
        <div className="checkbox-row">
          <span>Security:</span>
          <input
            type="checkbox"
            checked={security}
            onChange={(e) => setSecurity(e.target.checked)}
          />
          <span>Yes</span>
        </div>
        <label className="f-label">Fin. Year From:</label>
        <input
          type="date"
          className="f-input"
          value={finYearFrom}
          onChange={(e) => setFinYearFrom(e.target.value)}
        />
        <label className="f-label">Books beginning From:</label>
        <input
          type="date"
          className="f-input"
          value={booksFrom}
          onChange={(e) => setBooksFrom(e.target.value)}
        />
        {error && (
          <div style={{ color: '#b00020', marginTop: 12 }}>
            {error}
          </div>
        )}
        <button className="save-btn" onClick={save}>
          Save
        </button>
      </div>
    </div>
  )
}
