/* Order history: filter, advance the status, cancel.
   Cancelling here calls DELETE /api/orders/{id}, which SOFT-deletes: the
   backend flips the status to 'cancelled' and returns stock. The row stays
   readable, which is why a cancelled order is still listed below. */
import { useCallback, useEffect, useState } from 'react'
import { api } from '../api'
import { useApp } from '../store'
import { Empty, StatusChip, money, shortDate } from '../components/ui'

const NEXT_STATUS = { pending: 'paid', paid: 'shipped', shipped: 'delivered' }

export default function OrdersPage() {
  const { users, userId, toast } = useApp()
  const [orders, setOrders] = useState([])
  const [loading, setLoading] = useState(true)
  const [scope, setScope] = useState('mine')      // 'mine' | 'all'
  const [statusFilter, setStatusFilter] = useState('')
  const [busyId, setBusyId] = useState(null)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      // Build the query string the API already understands. URLSearchParams
      // handles the ? and & and escapes values for you.
      const qs = new URLSearchParams()
      if (scope === 'mine' && userId) qs.set('user_id', userId)
      if (statusFilter) qs.set('status', statusFilter)
      const query = qs.toString() ? `?${qs}` : ''
      setOrders(await api.orders.list(query))
    } catch (err) {
      toast(err.message, 'err')
    } finally {
      setLoading(false)
    }
  }, [scope, userId, statusFilter, toast])

  useEffect(() => { load() }, [load])

  async function advance(order) {
    const next = NEXT_STATUS[order.status]
    if (!next) return
    setBusyId(order.id)
    try {
      await api.orders.update(order.id, { status: next })
      await load()
      toast(`Order #${order.id} → ${next}`)
    } catch (err) {
      toast(err.message, 'err')
    } finally {
      setBusyId(null)
    }
  }

  async function cancel(order) {
    if (!confirm(`Cancel order #${order.id}? Stock will be returned.`)) return
    setBusyId(order.id)
    try {
      await api.orders.remove(order.id)
      await load()
      toast(`Order #${order.id} cancelled`)
    } catch (err) {
      toast(err.message, 'err')
    } finally {
      setBusyId(null)
    }
  }

  const nameOf = (id) => users.find((u) => u.id === id)?.full_name ?? `User ${id}`

  return (
    <>
      <div className="section-head">
        <div>
          <h2>Orders</h2>
          <p>{orders.length} order{orders.length === 1 ? '' : 's'}</p>
        </div>
        <div className="spacer" />
        <div className="search-bar">
          <select value={scope} onChange={(e) => setScope(e.target.value)}>
            <option value="mine">My orders</option>
            <option value="all">All users</option>
          </select>
          <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
            <option value="">Any status</option>
            {['pending', 'paid', 'shipped', 'delivered', 'cancelled'].map((s) => (
              <option key={s} value={s}>{s}</option>
            ))}
          </select>
        </div>
      </div>

      {loading ? (
        <div className="skeleton" style={{ height: 220 }} />
      ) : orders.length === 0 ? (
        <div className="card">
          <Empty icon="🧾" title="No orders yet">
            Add something to the cart and place an order to see it here.
          </Empty>
        </div>
      ) : (
        <div className="card">
          {orders.map((o) => (
            <div key={o.id} className="order-card">
              <div className="order-head">
                <span className="id">#{o.id}</span>
                <StatusChip status={o.status} />
                <span style={{ color: 'var(--muted)', fontSize: '0.85rem' }}>
                  {nameOf(o.user_id)} · {shortDate(o.created_at)}
                </span>
                <div className="spacer" />
                <strong className="num">{money(o.total_amount)}</strong>
                {NEXT_STATUS[o.status] && (
                  <button className="btn btn-sm" disabled={busyId === o.id}
                          onClick={() => advance(o)}>
                    Mark {NEXT_STATUS[o.status]}
                  </button>
                )}
                {o.status !== 'cancelled' && o.status !== 'delivered' && (
                  <button className="btn btn-danger btn-sm" disabled={busyId === o.id}
                          onClick={() => cancel(o)}>
                    Cancel
                  </button>
                )}
              </div>

              <div className="order-items">
                {o.items.map((it) => (
                  <div key={it.id} className="order-item">
                    <span className="nm">{it.product_name}</span>
                    <span>× {it.quantity}</span>
                    <span className="sp">{money(it.unit_price * it.quantity)}</span>
                  </div>
                ))}
              </div>

              {o.shipping_address && (
                <p style={{ marginTop: 10, fontSize: '0.82rem', color: 'var(--muted)' }}>
                  🚚 {o.shipping_address}
                </p>
              )}
            </div>
          ))}
        </div>
      )}
    </>
  )
}
