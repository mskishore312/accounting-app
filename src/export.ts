export function exportCsv(
  name: string,
  headers: string[],
  rows: string[][],
): void {
  const esc = (s: string) =>
    /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s
  const csv = [headers, ...rows]
    .map((r) => r.map(esc).join(','))
    .join('\n')
  const blob = new Blob([csv], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `${name.replace(/[^\w.-]+/g, '_')}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

/** PDF export via the browser's print-to-PDF */
export function printReport(): void {
  window.print()
}
