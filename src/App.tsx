import {
  HashRouter,
  Navigate,
  Route,
  Routes,
  useParams,
} from 'react-router-dom'
import { StoreProvider, useStore } from './store'
import { vchFromSlug, INVENTORY_VOUCHER_TYPES } from './types'
import SelectCompany from './pages/SelectCompany'
import CompanyForm from './pages/CompanyForm'
import Gateway from './pages/Gateway'
import Utility from './pages/Utility'
import MastersMenu from './pages/MastersMenu'
import GroupsList from './pages/GroupsList'
import LedgerList from './pages/LedgerList'
import LedgerForm from './pages/LedgerForm'
import VouchersMenu from './pages/VouchersMenu'
import VoucherList from './pages/VoucherList'
import VoucherForm from './pages/VoucherForm'
import ReportsMenu from './pages/ReportsMenu'
import DayBook from './pages/DayBook'
import SelectLedger from './pages/SelectLedger'
import LedgerReport from './pages/LedgerReport'
import GroupSummary from './pages/GroupSummary'
import Registers from './pages/Registers'
import AddressBook from './pages/AddressBook'
import TrialBalancePage from './pages/TrialBalance'
import FinalReports from './pages/FinalReports'
import ProfitLoss from './pages/ProfitLoss'
import BalanceSheetPage from './pages/BalanceSheet'
import InventoryMenu from './pages/InventoryMenu'
import StockItemList from './pages/StockItemList'
import StockItemForm from './pages/StockItemForm'
import {
  StockGroupsList,
  UnitsList,
} from './pages/StockGroupsUnits'
import InventoryVoucherForm from './pages/InventoryVoucherForm'
import StockSummary, {
  StockItemReport,
} from './pages/StockSummary'
import Settings from './pages/Settings'

/** Routes inventory voucher types to their dedicated form */
function VoucherFormSwitch() {
  const { type } = useParams()
  const vchType = vchFromSlug(type ?? 'receipt')
  if (INVENTORY_VOUCHER_TYPES.includes(vchType))
    return (
      <InventoryVoucherForm
        physical={vchType === 'Physical Stock'}
      />
    )
  return <VoucherForm />
}

function RequireCompany({
  children,
}: {
  children: React.ReactElement
}) {
  const { company } = useStore()
  if (!company) return <Navigate to="/" replace />
  return children
}

export default function App() {
  return (
    <StoreProvider>
      <HashRouter>
        <Routes>
          <Route path="/" element={<SelectCompany />} />
          <Route path="/company/new" element={<CompanyForm />} />
          <Route
            path="/company/edit"
            element={
              <RequireCompany>
                <CompanyForm edit />
              </RequireCompany>
            }
          />
          <Route
            path="/gateway"
            element={
              <RequireCompany>
                <Gateway />
              </RequireCompany>
            }
          />
          <Route
            path="/utility"
            element={
              <RequireCompany>
                <Utility />
              </RequireCompany>
            }
          />
          <Route
            path="/masters"
            element={
              <RequireCompany>
                <MastersMenu />
              </RequireCompany>
            }
          />
          <Route
            path="/masters/groups"
            element={
              <RequireCompany>
                <GroupsList />
              </RequireCompany>
            }
          />
          <Route
            path="/masters/ledgers"
            element={
              <RequireCompany>
                <LedgerList balances="opening" />
              </RequireCompany>
            }
          />
          <Route
            path="/masters/ledgers/new"
            element={
              <RequireCompany>
                <LedgerForm />
              </RequireCompany>
            }
          />
          <Route
            path="/masters/ledgers/:id"
            element={
              <RequireCompany>
                <LedgerForm />
              </RequireCompany>
            }
          />
          <Route
            path="/masters/inventory"
            element={
              <RequireCompany>
                <InventoryMenu />
              </RequireCompany>
            }
          />
          <Route
            path="/masters/stockitems"
            element={
              <RequireCompany>
                <StockItemList />
              </RequireCompany>
            }
          />
          <Route
            path="/masters/stockitems/new"
            element={
              <RequireCompany>
                <StockItemForm />
              </RequireCompany>
            }
          />
          <Route
            path="/masters/stockitems/:id"
            element={
              <RequireCompany>
                <StockItemForm />
              </RequireCompany>
            }
          />
          <Route
            path="/masters/stockgroups"
            element={
              <RequireCompany>
                <StockGroupsList />
              </RequireCompany>
            }
          />
          <Route
            path="/masters/units"
            element={
              <RequireCompany>
                <UnitsList />
              </RequireCompany>
            }
          />
          <Route
            path="/settings"
            element={
              <RequireCompany>
                <Settings />
              </RequireCompany>
            }
          />
          <Route
            path="/reports/stock"
            element={
              <RequireCompany>
                <StockSummary />
              </RequireCompany>
            }
          />
          <Route
            path="/reports/stock/:itemId"
            element={
              <RequireCompany>
                <StockItemReport />
              </RequireCompany>
            }
          />
          <Route
            path="/vouchers"
            element={
              <RequireCompany>
                <VouchersMenu />
              </RequireCompany>
            }
          />
          <Route
            path="/vouchers/:type"
            element={
              <RequireCompany>
                <VoucherList />
              </RequireCompany>
            }
          />
          <Route
            path="/vouchers/:type/new"
            element={
              <RequireCompany>
                <VoucherFormSwitch />
              </RequireCompany>
            }
          />
          <Route
            path="/vouchers/:type/:id"
            element={
              <RequireCompany>
                <VoucherFormSwitch />
              </RequireCompany>
            }
          />
          <Route
            path="/reports"
            element={
              <RequireCompany>
                <ReportsMenu />
              </RequireCompany>
            }
          />
          <Route
            path="/reports/daybook"
            element={
              <RequireCompany>
                <DayBook />
              </RequireCompany>
            }
          />
          <Route
            path="/reports/ledger"
            element={
              <RequireCompany>
                <SelectLedger />
              </RequireCompany>
            }
          />
          <Route
            path="/reports/cashbank"
            element={
              <RequireCompany>
                <SelectLedger cashBankOnly />
              </RequireCompany>
            }
          />
          <Route
            path="/reports/ledger/:ledgerId"
            element={
              <RequireCompany>
                <LedgerReport />
              </RequireCompany>
            }
          />
          <Route
            path="/reports/groupsummary"
            element={
              <RequireCompany>
                <GroupSummary />
              </RequireCompany>
            }
          />
          <Route
            path="/reports/registers"
            element={
              <RequireCompany>
                <Registers />
              </RequireCompany>
            }
          />
          <Route
            path="/reports/accounts"
            element={
              <RequireCompany>
                <LedgerList balances="closing" />
              </RequireCompany>
            }
          />
          <Route
            path="/reports/addressbook"
            element={
              <RequireCompany>
                <AddressBook />
              </RequireCompany>
            }
          />
          <Route
            path="/reports/trialbalance"
            element={
              <RequireCompany>
                <TrialBalancePage />
              </RequireCompany>
            }
          />
          <Route
            path="/reports/final"
            element={
              <RequireCompany>
                <FinalReports />
              </RequireCompany>
            }
          />
          <Route
            path="/reports/pl"
            element={
              <RequireCompany>
                <ProfitLoss />
              </RequireCompany>
            }
          />
          <Route
            path="/reports/balancesheet"
            element={
              <RequireCompany>
                <BalanceSheetPage />
              </RequireCompany>
            }
          />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </HashRouter>
    </StoreProvider>
  )
}
