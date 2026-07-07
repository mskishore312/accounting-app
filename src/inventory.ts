import {
  InventoryLine,
  Period,
  StockItem,
  Voucher,
  VoucherType,
} from './types'

/** Inventory movement direction per voucher type */
export function inventoryDirection(
  t: VoucherType,
): 'in' | 'out' | null {
  switch (t) {
    case 'Purchase':
    case 'Credit Note': // sales return comes back in
      return 'in'
    case 'Sales':
    case 'Debit Note': // purchase return goes out
      return 'out'
    default:
      return null // Journal etc.; Stock Journal uses per-line dir
  }
}

export interface StockEvent {
  date: string
  kind: 'in' | 'out' | 'set'
  qty: number
  rate: number
  vchType: VoucherType
  voucherId: string
  vchNo: number
  particulars: string
}

/** All stock events for one item, chronological. */
export function itemEvents(
  item: StockItem,
  vouchers: Voucher[],
): StockEvent[] {
  const events: StockEvent[] = []
  for (const v of vouchers) {
    if (!v.invLines) continue
    for (const ln of v.invLines) {
      if (ln.itemId !== item.id) continue
      if (v.vchType === 'Physical Stock') {
        events.push({
          date: v.date,
          kind: 'set',
          qty: ln.qty,
          rate: ln.rate,
          vchType: v.vchType,
          voucherId: v.id,
          vchNo: v.vchNo,
          particulars: 'Physical Stock',
        })
        continue
      }
      const dir =
        v.vchType === 'Stock Journal'
          ? (ln.dir ?? 'in')
          : inventoryDirection(v.vchType)
      if (!dir) continue
      events.push({
        date: v.date,
        kind: dir,
        qty: ln.qty,
        rate: ln.rate,
        vchType: v.vchType,
        voucherId: v.id,
        vchNo: v.vchNo,
        particulars: v.vchType,
      })
    }
  }
  events.sort((a, b) => a.date.localeCompare(b.date))
  return events
}

interface Lot {
  qty: number
  rate: number
}

export interface StockState {
  qty: number
  /** open lots in chronological order (opening lot first) */
  lots: Lot[]
  totalInQty: number
  totalInValue: number
  lastInRate: number
}

/**
 * Replays events up to a date and returns quantity plus the data the
 * valuation methods need. FIFO consumption is used for lot depletion
 * (remaining lots are therefore the most recent — correct for FIFO;
 * LIFO-annual walks lots from the oldest side instead).
 */
export function itemStateAsOn(
  item: StockItem,
  vouchers: Voucher[],
  asOn: string,
  exclusive = false,
): StockState {
  const st: StockState = {
    qty: item.openingQty,
    lots:
      item.openingQty > 0
        ? [{ qty: item.openingQty, rate: item.openingRate }]
        : [],
    totalInQty: item.openingQty,
    totalInValue: item.openingQty * item.openingRate,
    lastInRate: item.openingRate,
  }
  const consume = (qty: number) => {
    let left = qty
    while (left > 0 && st.lots.length) {
      const lot = st.lots[0]
      const take = Math.min(lot.qty, left)
      lot.qty -= take
      left -= take
      if (lot.qty <= 0) st.lots.shift()
    }
    st.qty -= qty
  }
  for (const e of itemEvents(item, vouchers)) {
    if (exclusive ? e.date >= asOn : e.date > asOn) break
    if (e.kind === 'in') {
      st.lots.push({ qty: e.qty, rate: e.rate })
      st.qty += e.qty
      st.totalInQty += e.qty
      st.totalInValue += e.qty * e.rate
      st.lastInRate = e.rate
    } else if (e.kind === 'out') {
      consume(e.qty)
    } else {
      // physical stock: reset on-hand to the counted quantity
      const diff = e.qty - st.qty
      if (diff > 0) {
        const rate =
          e.rate ||
          (st.totalInQty > 0
            ? st.totalInValue / st.totalInQty
            : item.openingRate)
        st.lots.push({ qty: diff, rate })
        st.qty += diff
        st.totalInQty += diff
        st.totalInValue += diff * rate
      } else if (diff < 0) {
        consume(-diff)
      }
    }
  }
  return st
}

/** Closing value of an item per its valuation method. */
export function valueOf(item: StockItem, st: StockState): number {
  const qty = Math.max(0, st.qty)
  if (qty === 0) return 0
  const method = item.valuation ?? 'Avg. Cost'
  switch (method) {
    case 'Avg. Cost': {
      const avg =
        st.totalInQty > 0 ? st.totalInValue / st.totalInQty : 0
      return qty * avg
    }
    case 'FIFO': {
      // remaining stock = most recent lots
      let left = qty
      let value = 0
      for (let i = st.lots.length - 1; i >= 0 && left > 0; i--) {
        const take = Math.min(st.lots[i].qty, left)
        value += take * st.lots[i].rate
        left -= take
      }
      if (left > 0) value += left * st.lastInRate
      return value
    }
    case 'LIFO': {
      // remaining stock = earliest lots (LIFO annual)
      let left = qty
      let value = 0
      for (let i = 0; i < st.lots.length && left > 0; i++) {
        const take = Math.min(st.lots[i].qty, left)
        value += take * st.lots[i].rate
        left -= take
      }
      if (left > 0) value += left * st.lastInRate
      return value
    }
    case 'Last Purchase Cost':
      return qty * st.lastInRate
    case 'Std. Cost':
      return qty * (item.stdCost ?? item.openingRate)
    case 'At Zero Cost':
      return 0
  }
}

export function stockQtyValue(
  item: StockItem,
  vouchers: Voucher[],
  asOn: string,
  exclusive = false,
): { qty: number; value: number; rate: number } {
  const st = itemStateAsOn(item, vouchers, asOn, exclusive)
  const value = valueOf(item, st)
  const qty = Math.max(0, st.qty)
  return { qty, value, rate: qty > 0 ? value / qty : 0 }
}

/** Total inventory value across items, as on a date. */
export function closingStockValue(
  items: StockItem[],
  vouchers: Voucher[],
  asOn: string,
  exclusive = false,
): number {
  return items.reduce(
    (s, it) => s + stockQtyValue(it, vouchers, asOn, exclusive).value,
    0,
  )
}

export interface StockSummaryRow {
  item: StockItem
  openQty: number
  openValue: number
  inQty: number
  inValue: number
  outQty: number
  outValue: number
  closeQty: number
  closeRate: number
  closeValue: number
}

export function stockSummary(
  items: StockItem[],
  vouchers: Voucher[],
  p: Period,
): StockSummaryRow[] {
  return items.map((item) => {
    const open = stockQtyValue(item, vouchers, p.from, true)
    const close = stockQtyValue(item, vouchers, p.to)
    let inQty = 0
    let inValue = 0
    let outQty = 0
    for (const e of itemEvents(item, vouchers)) {
      if (e.date < p.from || e.date > p.to) continue
      if (e.kind === 'in') {
        inQty += e.qty
        inValue += e.qty * e.rate
      } else if (e.kind === 'out') {
        outQty += e.qty
      } else {
        // physical stock adjustment counts as in/out of the diff
        const before = itemStateAsOn(item, vouchers, e.date, true)
        const diff = e.qty - before.qty
        if (diff > 0) {
          inQty += diff
          inValue +=
            diff *
            (e.rate ||
              (before.totalInQty > 0
                ? before.totalInValue / before.totalInQty
                : item.openingRate))
        } else outQty += -diff
      }
    }
    // outward value = opening + inward - closing (consumption cost)
    const outValue = Math.max(
      0,
      open.value + inValue - close.value,
    )
    return {
      item,
      openQty: open.qty,
      openValue: open.value,
      inQty,
      inValue,
      outQty,
      outValue,
      closeQty: close.qty,
      closeRate: close.rate,
      closeValue: close.value,
    }
  })
}

/** Movement register rows for one stock item within a period. */
export interface ItemMovementRow {
  event: StockEvent
  inQty: number
  outQty: number
  balance: number
}

export function itemMovements(
  item: StockItem,
  vouchers: Voucher[],
  p: Period,
): { opening: number; rows: ItemMovementRow[]; closing: number } {
  const opening = itemStateAsOn(item, vouchers, p.from, true).qty
  let balance = opening
  const rows: ItemMovementRow[] = []
  for (const e of itemEvents(item, vouchers)) {
    if (e.date < p.from || e.date > p.to) continue
    let inQty = 0
    let outQty = 0
    if (e.kind === 'in') inQty = e.qty
    else if (e.kind === 'out') outQty = e.qty
    else {
      const diff = e.qty - balance
      if (diff >= 0) inQty = diff
      else outQty = -diff
    }
    balance += inQty - outQty
    rows.push({ event: e, inQty, outQty, balance })
  }
  return { opening, rows, closing: balance }
}

/** Sum of item-line amounts (for auto-filling voucher amounts). */
export function invTotal(lines: InventoryLine[]): number {
  return lines.reduce((s, l) => s + l.amount, 0)
}
