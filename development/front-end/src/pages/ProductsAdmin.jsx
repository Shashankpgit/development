/* Product CRUD: a table plus one modal that handles both create and edit.
   WHY one modal for both: the form fields are identical. The only difference
   is whether we POST or PUT, which is decided by whether `editing` is set. */
import { useCallback, useEffect, useState } from 'react'
import { api } from '../api'
import { useApp } from '../store'
import { Empty, Field, Modal, StockChip, money } from '../components/ui'

const BLANK = { name: '', description: '', price: '', stock: '0', image_url: '', category_id: '' }

export default function ProductsAdmin() {
  const { toast } = useApp()
  const [products, setProducts] = useState([])
  const [categories, setCategories] = useState([])
  const [loading, setLoading] = useState(true)
  const [open, setOpen] = useState(false)
  const [editing, setEditing] = useState(null)
  const [form, setForm] = useState(BLANK)
  const [saving, setSaving] = useState(false)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const [p, c] = await Promise.all([api.products.list(), api.categories.list()])
      setProducts(p); setCategories(c)
    } catch (err) { toast(err.message, 'err') } finally { setLoading(false) }
  }, [toast])

  useEffect(() => { load() }, [load])

  function openCreate() { setEditing(null); setForm(BLANK); setOpen(true) }

  function openEdit(p) {
    setEditing(p)
    // Every value becomes a string: an <input> value must be a string, and
    // `null` would make React warn about switching to an uncontrolled input.
    setForm({
      name: p.name,
      description: p.description ?? '',
      price: String(p.price),
      stock: String(p.stock),
      image_url: p.image_url ?? '',
      category_id: p.category_id ? String(p.category_id) : '',
    })
    setOpen(true)
  }

  // One handler for every text field, keyed by the input's name attribute.
  // The spread copies the old state -- mutating form directly would not
  // trigger a re-render.
  const set = (e) => setForm((f) => ({ ...f, [e.target.name]: e.target.value }))

  async function save(e) {
    e.preventDefault()   // stop the browser doing a full-page form submit
    setSaving(true)
    try {
      const payload = {
        name: form.name.trim(),
        description: form.description.trim() || null,
        // Inputs always give strings. Sending "12.5" where the API expects a
        // number is the most common 422 you will meet.
        price: Number(form.price),
        stock: Number(form.stock),
        image_url: form.image_url.trim() || null,
        category_id: form.category_id ? Number(form.category_id) : null,
      }
      if (editing) {
        await api.products.update(editing.id, payload)
        toast(`${payload.name} updated`)
      } else {
        await api.products.create(payload)
        toast(`${payload.name} created`)
      }
      setOpen(false)
      await load()
    } catch (err) { toast(err.message, 'err') } finally { setSaving(false) }
  }

  async function remove(p) {
    if (!confirm(`Delete "${p.name}"? It will also be removed from any carts.`)) return
    try {
      await api.products.remove(p.id)
      await load()
      toast(`${p.name} deleted`)
    } catch (err) { toast(err.message, 'err') }
  }

  return (
    <>
      <div className="section-head">
        <div><h2>Products</h2><p>{products.length} in the catalogue</p></div>
        <div className="spacer" />
        <button className="btn btn-primary" onClick={openCreate}>+ New product</button>
      </div>

      {loading ? (
        <div className="skeleton" style={{ height: 260 }} />
      ) : products.length === 0 ? (
        <div className="card">
          <Empty icon="📦" title="No products yet"
                 action={<button className="btn btn-primary" onClick={openCreate}>Add the first one</button>}>
            Create a category first, then add products to it.
          </Empty>
        </div>
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>#</th><th>Product</th><th>Category</th>
                <th>Price</th><th>Stock</th><th />
              </tr>
            </thead>
            <tbody>
              {products.map((p) => (
                <tr key={p.id}>
                  <td className="num" style={{ color: 'var(--muted)' }}>{p.id}</td>
                  <td>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                      {p.image_url && (
                        <img src={p.image_url} alt="" width="36" height="36"
                             style={{ borderRadius: 8, objectFit: 'cover' }} />
                      )}
                      <div>
                        <div style={{ fontWeight: 600 }}>{p.name}</div>
                        <small style={{ color: 'var(--muted)' }}>
                          {(p.description ?? '').slice(0, 46) || '—'}
                        </small>
                      </div>
                    </div>
                  </td>
                  <td>{p.category ? <span className="chip">{p.category.name}</span>
                                   : <span className="chip chip-muted">Uncategorised</span>}</td>
                  <td className="num">{money(p.price)}</td>
                  <td><StockChip stock={p.stock} /></td>
                  <td className="actions">
                    <button className="btn btn-sm" onClick={() => openEdit(p)}>Edit</button>
                    <button className="btn btn-danger btn-sm" onClick={() => remove(p)}>Delete</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {open && (
        <Modal
          title={editing ? `Edit ${editing.name}` : 'New product'}
          onClose={() => setOpen(false)}
          footer={
            <>
              <button className="btn" onClick={() => setOpen(false)}>Cancel</button>
              {/* form="product-form" lets a button OUTSIDE the <form> submit it. */}
              <button className="btn btn-primary" form="product-form" disabled={saving}>
                {saving ? 'Saving…' : editing ? 'Save changes' : 'Create product'}
              </button>
            </>
          }
        >
          <form id="product-form" className="form-grid" onSubmit={save}>
            <Field label="Name" span>
              <input name="name" value={form.name} onChange={set} required placeholder="Aurora Laptop 14" />
            </Field>
            <Field label="Description" span>
              <textarea name="description" value={form.description} onChange={set}
                        placeholder="What makes it good?" />
            </Field>
            <Field label="Price (USD)" hint="Must be greater than 0">
              {/* step="0.01" allows cents; without it the browser rejects 12.50 */}
              <input name="price" type="number" step="0.01" min="0.01"
                     value={form.price} onChange={set} required placeholder="99.99" />
            </Field>
            <Field label="Stock">
              <input name="stock" type="number" min="0" value={form.stock} onChange={set} required />
            </Field>
            <Field label="Category">
              <select name="category_id" value={form.category_id} onChange={set}>
                <option value="">Uncategorised</option>
                {categories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
              </select>
            </Field>
            <Field label="Image URL" hint="Leave blank for a placeholder">
              <input name="image_url" value={form.image_url} onChange={set} placeholder="https://…" />
            </Field>
          </form>
        </Modal>
      )}
    </>
  )
}
