/* The cart: quantity changes, removal, and checkout.
   Every mutation follows the same rule -- call the API, then re-read from the
   API. Never guess the new state locally: the server is the source of truth
   about stock, subtotals and validity. */
import { useCallback, useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { api } from '../api'
import { useApp } from '../store'
import { Empty, money } from '../components/ui'

export default function CartPage() {
  const { userId, currentUser, refreshCart, toast } = useApp()
  const navigate = useNavigate()

  const [cart, setCart] = useState(null)
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [address, setAddress] = useState('')

  const load = useCallback(async () => {
    if (!userId) { setCart(null); setLoading(false); return }
    setLoading(true)
    try {
      setCart(await api.cart.get(userId))
    } catch (err) {
      toast(err.message, 'err')
    } finally {
      setLoading(false)
    }
  }, [userId, toast])

  useEffect(() => { load() }, [load])
  // Prefill the shipping address from the user record, and follow along if
  // the selected user changes.
  useEffect(() => { setAddress(currentUser?.address ?? '') }, [currentUser])

  async function changeQty(item, next) {
    setBusy(true)
    try {
      if (next <= 0) await api.cart.removeItem(item.id)
      else await api.cart.updateItem(item.id, next)
      await load()
      await refreshCart()
    } catch (err) {
      toast(err.message, 'err')
    } finally {
      setBusy(false)
    }
  }

  async function remove(item) {
    setBusy(true)
    try {
      await api.cart.removeItem(item.id)
      await load()
      await refreshCart()
      toast(`${item.product?.name ?? 'Item'} removed`)
    } catch (err) {
      toast(err.message, 'err')
    } finally {
      setBusy(false)
    }
  }

  async function checkout() {
    setBusy(true)
    try {
      // No items in the body -> the backend builds the order from the cart,
      // decrements stock and empties the cart, all in one transaction.
      const order = await api.orders.checkout(userId, address)
      await refreshCart()
      toast(`Order #${order.id} placed — ${money(order.total_amount)}`)
      navigate('/orders')
    } catch (err) {
      toast(err.message, 'err')
    } finally {
      setBusy(false)
    }
  }

  if (!userId) {
    return (
      <div className="card" style={{ marginTop: 40 }}>
        <Empty icon="👤" title="No user selected">
          Pick a user in the top bar, or create one in the Users tab.
        </Empty>
      </div>
    )
  }

  return (
    <>
      <div className="section-head">
        <div>
          <h2>Your cart</h2>
          <p>Shopping as {currentUser?.full_name ?? '…'}</p>
        </div>
      </div>

      {loading ? (
        <div className="skeleton" style={{ height: 240 }} />
      ) : !cart || cart.items.length === 0 ? (
        <div className="card">
          <Empty
            icon="🛒"
            title="Your cart is empty"
            action={<Link className="btn btn-primary" to="/">Start shopping</Link>}
          >
            Items you add from the shop will appear here.
          </Empty>
        </div>
      ) : (
        <div className="cols-2">
          <div className="card">
            {cart.items.map((item) => (
              <div key={item.id} className="cart-line">
                {item.product?.image_url ? (
                  <img src={item.product.image_url} alt={item.product.name} />
                ) : (
                  <div className="skeleton" style={{ width: 64, height: 64, animation: 'none' }} />
                )}
                <div className="info">
                  <h4>{item.product?.name ?? `Product ${item.product_id}`}</h4>
                  <small>{money(item.product?.price)} each</small>
                </div>
                <div className="qty">
                  <button disabled={busy} onClick={() => changeQty(item, item.quantity - 1)}>−</button>
                  <span>{item.quantity}</span>
                  <button
                    // Cap at available stock so the user gets blocked here
                    // instead of by a 409 from the API.
                    disabled={busy || item.quantity >= (item.product?.stock ?? 0)}
                    onClick={() => changeQty(item, item.quantity + 1)}
                  >+</button>
                </div>
                <strong className="num" style={{ minWidth: 84, textAlign: 'right' }}>
                  {money(item.subtotal)}
                </strong>
                <button className="btn btn-danger btn-sm btn-icon" disabled={busy}
                        onClick={() => remove(item)} aria-label="Remove">🗑</button>
              </div>
            ))}
          </div>

          <div className="card summary">
            <div className="summary-row">
              <span>Items</span><span className="num">{cart.total_items}</span>
            </div>
            <div className="summary-row">
              <span>Subtotal</span><span className="num">{money(cart.total_amount)}</span>
            </div>
            <div className="summary-row">
              <span>Shipping</span><span>Free</span>
            </div>
            <div className="summary-row total">
              <span>Total</span><span className="num">{money(cart.total_amount)}</span>
            </div>

            <div className="field" style={{ marginTop: 6 }}>
              <label>Shipping address</label>
              <textarea
                value={address}
                onChange={(e) => setAddress(e.target.value)}
                placeholder="Where should we deliver this?"
              />
            </div>

            <button className="btn btn-primary" disabled={busy} onClick={checkout}>
              {busy ? 'Placing order…' : `Place order · ${money(cart.total_amount)}`}
            </button>
          </div>
        </div>
      )}
    </>
  )
}
