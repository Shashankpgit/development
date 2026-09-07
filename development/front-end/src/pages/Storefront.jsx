/*
 * The customer-facing page: hero, filters, product grid, add-to-cart.
 *
 * This is the file to read to understand the core React loop:
 *   1. useState holds data that can change
 *   2. useEffect fetches from the API after the first render
 *   3. setState triggers a re-render, and the new data appears
 */
import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { api } from '../api'
import { useApp } from '../store'
import { CardSkeletons, Empty, StockChip, money } from '../components/ui'

export default function Storefront() {
  const { userId, refreshCart, toast } = useApp()

  const [products, setProducts] = useState([])
  const [categories, setCategories] = useState([])
  // Loading starts as TRUE. If it started false, the page would flash "no
  // products found" for a moment before the first response arrives.
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [categoryId, setCategoryId] = useState('')
  const [sort, setSort] = useState('featured')
  const [adding, setAdding] = useState(null)   // which product's button is busy

  const load = useCallback(async () => {
    setLoading(true)
    try {
      // Promise.all runs both requests AT THE SAME TIME. Awaiting them one
      // after the other would take as long as both added together --
      // check the waterfall in DevTools -> Network to see the difference.
      const [p, c] = await Promise.all([api.products.list(), api.categories.list()])
      setProducts(p)
      setCategories(c)
    } catch (err) {
      toast(err.message, 'err')
    } finally {
      // finally, so a failed request still stops the loading state.
      setLoading(false)
    }
  }, [toast])

  useEffect(() => { load() }, [load])

  // Filtering happens in the browser because the whole catalogue is small.
  // With 10,000 products you would send `search` to the API instead
  // (/api/products?search=...) -- the endpoint already supports it.
  const visible = useMemo(() => {
    let list = products
    if (categoryId) list = list.filter((p) => p.category_id === Number(categoryId))
    if (search.trim()) {
      const q = search.trim().toLowerCase()
      list = list.filter(
        (p) =>
          p.name.toLowerCase().includes(q) ||
          (p.description ?? '').toLowerCase().includes(q),
      )
    }
    // Copy with [...list] before sorting: .sort() mutates in place, and
    // mutating state directly is how you get renders that do not update.
    if (sort === 'price-asc') list = [...list].sort((a, b) => a.price - b.price)
    if (sort === 'price-desc') list = [...list].sort((a, b) => b.price - a.price)
    if (sort === 'name') list = [...list].sort((a, b) => a.name.localeCompare(b.name))
    return list
  }, [products, categoryId, search, sort])

  async function addToCart(product) {
    if (!userId) return toast('Pick a user in the top bar first', 'err')
    setAdding(product.id)
    try {
      await api.cart.add({ user_id: userId, product_id: product.id, quantity: 1 })
      await refreshCart()     // updates the badge in the top bar
      toast(`${product.name} added to cart`)
    } catch (err) {
      toast(err.message, 'err')
    } finally {
      setAdding(null)
    }
  }

  const totalStock = products.reduce((sum, p) => sum + p.stock, 0)

  return (
    <>
      <section className="hero">
        <h1>Everything you need, <span>beautifully simple</span></h1>
        <p>
          A full CRUD storefront running on FastAPI and PostgreSQL. Browse the
          catalogue, fill a cart, place an order — then manage the data from the
          admin tabs above.
        </p>
        <div className="hero-actions">
          <a className="btn btn-primary" href="#catalogue">Browse catalogue</a>
          <Link className="btn" to="/orders">View orders</Link>
        </div>
        <div className="hero-stats">
          <div><span>{products.length}</span><small>Products</small></div>
          <div><span>{categories.length}</span><small>Categories</small></div>
          <div><span>{totalStock}</span><small>Units in stock</small></div>
        </div>
      </section>

      <div className="section-head" id="catalogue">
        <div>
          <h2>Catalogue</h2>
          <p>{visible.length} of {products.length} products shown</p>
        </div>
        <div className="spacer" />
        <div className="search-bar">
          <input
            placeholder="Search products…"
            value={search}
            // A "controlled input": React owns the value. Without onChange the
            // field would be permanently read-only -- typing would do nothing.
            onChange={(e) => setSearch(e.target.value)}
          />
          <select value={categoryId} onChange={(e) => setCategoryId(e.target.value)}>
            <option value="">All categories</option>
            {categories.map((c) => (
              <option key={c.id} value={c.id}>{c.name}</option>
            ))}
          </select>
          <select value={sort} onChange={(e) => setSort(e.target.value)}>
            <option value="featured">Featured</option>
            <option value="price-asc">Price: low to high</option>
            <option value="price-desc">Price: high to low</option>
            <option value="name">Name A–Z</option>
          </select>
        </div>
      </div>

      {loading ? (
        <CardSkeletons />
      ) : visible.length === 0 ? (
        <div className="card">
          <Empty icon="🔍" title="Nothing matches those filters">
            Try a different search term, or add products from the Products tab.
          </Empty>
        </div>
      ) : (
        <div className="grid">
          {visible.map((p) => (
            <article key={p.id} className="product-card">
              <div className="product-media">
                {p.image_url ? (
                  // alt text is read aloud by screen readers and shown if the
                  // image fails to load. It is not optional.
                  <img src={p.image_url} alt={p.name} loading="lazy" />
                ) : (
                  <div className="placeholder">🖼️</div>
                )}
              </div>
              <div className="product-body">
                {p.category && <span className="chip">{p.category.name}</span>}
                <h3>{p.name}</h3>
                <p className="desc">{p.description || 'No description yet.'}</p>
                <StockChip stock={p.stock} />
                <div className="product-foot">
                  <span className="price">{money(p.price)}</span>
                  <button
                    className="btn btn-primary btn-sm"
                    style={{ marginLeft: 'auto' }}
                    disabled={p.stock <= 0 || adding === p.id}
                    onClick={() => addToCart(p)}
                  >
                    {adding === p.id ? 'Adding…' : 'Add to cart'}
                  </button>
                </div>
              </div>
            </article>
          ))}
        </div>
      )}
    </>
  )
}
