/* Category CRUD. Deleting a category that still has products returns 409 from
   the API -- we surface that message rather than hiding it, so the user
   learns WHY it failed. */
import { useCallback, useEffect, useState } from 'react'
import { api } from '../api'
import { useApp } from '../store'
import { Empty, Field, Modal, shortDate } from '../components/ui'

export default function CategoriesAdmin() {
  const { toast } = useApp()
  const [categories, setCategories] = useState([])
  const [products, setProducts] = useState([])
  const [loading, setLoading] = useState(true)
  const [open, setOpen] = useState(false)
  const [editing, setEditing] = useState(null)
  const [form, setForm] = useState({ name: '', description: '' })
  const [saving, setSaving] = useState(false)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const [c, p] = await Promise.all([api.categories.list(), api.products.list()])
      setCategories(c); setProducts(p)
    } catch (err) { toast(err.message, 'err') } finally { setLoading(false) }
  }, [toast])

  useEffect(() => { load() }, [load])

  const set = (e) => setForm((f) => ({ ...f, [e.target.name]: e.target.value }))
  const countFor = (id) => products.filter((p) => p.category_id === id).length

  function openCreate() { setEditing(null); setForm({ name: '', description: '' }); setOpen(true) }
  function openEdit(c) {
    setEditing(c); setForm({ name: c.name, description: c.description ?? '' }); setOpen(true)
  }

  async function save(e) {
    e.preventDefault()
    setSaving(true)
    try {
      const payload = { name: form.name.trim(), description: form.description.trim() || null }
      if (editing) { await api.categories.update(editing.id, payload); toast(`${payload.name} updated`) }
      else { await api.categories.create(payload); toast(`${payload.name} created`) }
      setOpen(false)
      await load()
    } catch (err) { toast(err.message, 'err') } finally { setSaving(false) }
  }

  async function remove(c) {
    if (!confirm(`Delete category "${c.name}"?`)) return
    try {
      await api.categories.remove(c.id)
      await load()
      toast(`${c.name} deleted`)
    } catch (err) {
      // A 409 lands here with the API's explanation, e.g. "Cannot delete a
      // category that still has products assigned to it".
      toast(err.message, 'err')
    }
  }

  return (
    <>
      <div className="section-head">
        <div><h2>Categories</h2><p>{categories.length} defined</p></div>
        <div className="spacer" />
        <button className="btn btn-primary" onClick={openCreate}>+ New category</button>
      </div>

      {loading ? (
        <div className="skeleton" style={{ height: 220 }} />
      ) : categories.length === 0 ? (
        <div className="card">
          <Empty icon="🏷️" title="No categories yet"
                 action={<button className="btn btn-primary" onClick={openCreate}>Create one</button>}>
            Categories group your products together.
          </Empty>
        </div>
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr><th>#</th><th>Name</th><th>Description</th><th>Products</th><th>Created</th><th /></tr>
            </thead>
            <tbody>
              {categories.map((c) => (
                <tr key={c.id}>
                  <td className="num" style={{ color: 'var(--muted)' }}>{c.id}</td>
                  <td style={{ fontWeight: 600 }}>{c.name}</td>
                  <td style={{ color: 'var(--muted)' }}>{c.description || '—'}</td>
                  <td><span className="chip chip-muted">{countFor(c.id)}</span></td>
                  <td style={{ color: 'var(--muted)' }}>{shortDate(c.created_at)}</td>
                  <td className="actions">
                    <button className="btn btn-sm" onClick={() => openEdit(c)}>Edit</button>
                    <button className="btn btn-danger btn-sm" onClick={() => remove(c)}>Delete</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {open && (
        <Modal
          title={editing ? `Edit ${editing.name}` : 'New category'}
          onClose={() => setOpen(false)}
          footer={
            <>
              <button className="btn" onClick={() => setOpen(false)}>Cancel</button>
              <button className="btn btn-primary" form="category-form" disabled={saving}>
                {saving ? 'Saving…' : editing ? 'Save changes' : 'Create category'}
              </button>
            </>
          }
        >
          <form id="category-form" className="form-grid" onSubmit={save}>
            <Field label="Name" span hint="Must be unique">
              <input name="name" value={form.name} onChange={set} required placeholder="Electronics" />
            </Field>
            <Field label="Description" span>
              <textarea name="description" value={form.description} onChange={set}
                        placeholder="What belongs in this category?" />
            </Field>
          </form>
        </Modal>
      )}
    </>
  )
}
