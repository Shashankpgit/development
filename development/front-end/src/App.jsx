/*
 * The layout + the route table.
 *
 * A "route" maps a URL path to a component. react-router swaps components
 * when the URL changes without asking the server for a new page -- that is
 * what makes it a Single Page Application.
 */
import { NavLink, Navigate, Route, Routes } from 'react-router-dom'
import { AppProvider, useApp } from './store'
import Storefront from './pages/Storefront'
import CartPage from './pages/CartPage'
import OrdersPage from './pages/OrdersPage'
import ProductsAdmin from './pages/ProductsAdmin'
import CategoriesAdmin from './pages/CategoriesAdmin'
import UsersAdmin from './pages/UsersAdmin'

function Topbar() {
  const { users, userId, setUserId, cartCount } = useApp()

  return (
    <header className="topbar">
      <div className="topbar-inner">
        <NavLink to="/" className="logo">
          <span className="logo-mark">◈</span> Nimbus Store
        </NavLink>

        <nav className="nav">
          {/* NavLink (not Link) adds an "active" class when the URL matches,
              which is what highlights the current tab. `end` limits the "/"
              link to an exact match, otherwise it would be active always. */}
          <NavLink to="/" end>Shop</NavLink>
          <NavLink to="/orders">Orders</NavLink>
          <NavLink to="/admin/products">Products</NavLink>
          <NavLink to="/admin/categories">Categories</NavLink>
          <NavLink to="/admin/users">Users</NavLink>
        </nav>

        <div className="user-pick" title="There is no login in this demo -- pick who you are">
          <span>👤</span>
          <select value={userId ?? ''} onChange={(e) => setUserId(Number(e.target.value))}>
            {users.length === 0 && <option value="">No users yet</option>}
            {users.map((u) => (
              <option key={u.id} value={u.id}>{u.full_name}</option>
            ))}
          </select>
        </div>

        <NavLink to="/cart" className="cart-chip" aria-label="Cart">
          🛒
          {/* Render the badge only when there is something to show:
              `cond && <jsx/>` renders nothing when cond is false. */}
          {cartCount > 0 && <span className="badge">{cartCount}</span>}
        </NavLink>
      </div>
    </header>
  )
}

function Toasts() {
  const { toasts } = useApp()
  return (
    <div className="toasts">
      {toasts.map((t) => (
        // key lets React tell list items apart between renders. Using the
        // array index instead would animate the wrong toast on removal.
        <div key={t.id} className={`toast ${t.kind}`}>
          <span>{t.kind === 'ok' ? '✅' : '⚠️'}</span>
          <span>{t.message}</span>
        </div>
      ))}
    </div>
  )
}

export default function App() {
  return (
    <AppProvider>
      <Topbar />
      <main className="shell">
        <Routes>
          <Route path="/" element={<Storefront />} />
          <Route path="/cart" element={<CartPage />} />
          <Route path="/orders" element={<OrdersPage />} />
          <Route path="/admin/products" element={<ProductsAdmin />} />
          <Route path="/admin/categories" element={<CategoriesAdmin />} />
          <Route path="/admin/users" element={<UsersAdmin />} />
          {/* Catch-all: any unknown URL goes home instead of a blank screen. */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </main>
      <Toasts />
    </AppProvider>
  )
}
