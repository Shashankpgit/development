/* Small reusable pieces. Every one of these appears on 3+ pages, which is the
   bar for pulling something into its own component. */
import { useEffect } from 'react'

/** A dialog rendered on top of everything, closable with Escape. */
export function Modal({ title, onClose, children, footer }) {
  // Attach a keydown listener while the modal is open, and REMOVE it when the
  // modal unmounts. The returned function is the cleanup: skip it and every
  // opened modal leaves a dead listener behind (a real memory leak).
  useEffect(() => {
    const onKey = (e) => e.key === 'Escape' && onClose()
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])

  return (
    // Clicking the dark backdrop closes; clicking inside must not, so the
    // inner div stops the click from bubbling up to the parent.
    <div className="overlay" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <h3>{title}</h3>
          <button onClick={onClose} aria-label="Close">×</button>
        </div>
        <div className="modal-body">{children}</div>
        {footer && <div className="modal-foot">{footer}</div>}
      </div>
    </div>
  )
}

export function Field({ label, hint, span, children }) {
  return (
    <div className={`field${span ? ' span-2' : ''}`}>
      <label>{label}</label>
      {children}
      {hint && <span className="hint">{hint}</span>}
    </div>
  )
}

export function Empty({ icon = '📦', title, children, action }) {
  return (
    <div className="empty">
      <div className="icon">{icon}</div>
      <h3>{title}</h3>
      {children && <p>{children}</p>}
      {action && <div style={{ marginTop: 18 }}>{action}</div>}
    </div>
  )
}

export function CardSkeletons({ count = 6 }) {
  // Array.from({length}) is the idiomatic way to render N placeholders.
  return (
    <div className="grid">
      {Array.from({ length: count }, (_, i) => (
        <div key={i} className="skeleton card-sk" />
      ))}
    </div>
  )
}

export const money = (n) =>
  // Intl handles the currency symbol, grouping and decimals for you --
  // do not hand-roll `'$' + n.toFixed(2)`.
  new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(n ?? 0)

export const shortDate = (iso) =>
  new Date(iso).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' })

export function StockChip({ stock }) {
  if (stock <= 0) return <span className="chip chip-danger">Out of stock</span>
  if (stock < 10) return <span className="chip chip-warn">Only {stock} left</span>
  return <span className="chip chip-ok">{stock} in stock</span>
}

const STATUS_CLASS = {
  pending: 'chip-warn', paid: 'chip', shipped: 'chip',
  delivered: 'chip-ok', cancelled: 'chip-danger',
}
export function StatusChip({ status }) {
  return <span className={`chip ${STATUS_CLASS[status] ?? 'chip-muted'}`}>{status}</span>
}
