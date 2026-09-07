/* User CRUD. Creating a user here immediately refreshes the top-bar dropdown,
   because both read from the same context (see loadUsers in store.jsx). */
import { useEffect, useState } from 'react'
import { api } from '../api'
import { useApp } from '../store'
import { Empty, Field, Modal, shortDate } from '../components/ui'

const BLANK = { full_name: '', email: '', phone: '', address: '' }

export default function UsersAdmin() {
  const { users, loadUsers, toast } = useApp()
  const [loading, setLoading] = useState(true)
  const [open, setOpen] = useState(false)
  const [editing, setEditing] = useState(null)
  const [form, setForm] = useState(BLANK)
  const [saving, setSaving] = useState(false)

  // The list already lives in context, so this page only has to trigger a
  // refresh -- it does not keep its own copy. Two copies of the same data is
  // how UIs end up disagreeing with themselves.
  useEffect(() => {
    loadUsers().finally(() => setLoading(false))
  }, [loadUsers])

  const set = (e) => setForm((f) => ({ ...f, [e.target.name]: e.target.value }))

  function openCreate() { setEditing(null); setForm(BLANK); setOpen(true) }
  function openEdit(u) {
    setEditing(u)
    setForm({
      full_name: u.full_name, email: u.email,
      phone: u.phone ?? '', address: u.address ?? '',
    })
    setOpen(true)
  }

  async function save(e) {
    e.preventDefault()
    setSaving(true)
    try {
      const payload = {
        full_name: form.full_name.trim(),
        email: form.email.trim(),
        phone: form.phone.trim() || null,
        address: form.address.trim() || null,
      }
      if (editing) { await api.users.update(editing.id, payload); toast(`${payload.full_name} updated`) }
      else { await api.users.create(payload); toast(`${payload.full_name} created`) }
      setOpen(false)
      await loadUsers()
    } catch (err) { toast(err.message, 'err') } finally { setSaving(false) }
  }

  async function remove(u) {
    if (!confirm(`Delete ${u.full_name}?`)) return
    try {
      await api.users.remove(u.id)
      await loadUsers()
      toast(`${u.full_name} deleted`)
    } catch (err) {
      // 409 if they have orders -- the API refuses to destroy order history.
      toast(err.message, 'err')
    }
  }

  return (
    <>
      <div className="section-head">
        <div><h2>Users</h2><p>{users.length} registered</p></div>
        <div className="spacer" />
        <button className="btn btn-primary" onClick={openCreate}>+ New user</button>
      </div>

      {loading ? (
        <div className="skeleton" style={{ height: 220 }} />
      ) : users.length === 0 ? (
        <div className="card">
          <Empty icon="👥" title="No users yet"
                 action={<button className="btn btn-primary" onClick={openCreate}>Create one</button>}>
            A user is needed before anything can be added to a cart.
          </Empty>
        </div>
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr><th>#</th><th>Name</th><th>Email</th><th>Phone</th><th>Joined</th><th /></tr>
            </thead>
            <tbody>
              {users.map((u) => (
                <tr key={u.id}>
                  <td className="num" style={{ color: 'var(--muted)' }}>{u.id}</td>
                  <td>
                    <div style={{ fontWeight: 600 }}>{u.full_name}</div>
                    <small style={{ color: 'var(--muted)' }}>{u.address || '—'}</small>
                  </td>
                  <td>{u.email}</td>
                  <td style={{ color: 'var(--muted)' }}>{u.phone || '—'}</td>
                  <td style={{ color: 'var(--muted)' }}>{shortDate(u.created_at)}</td>
                  <td className="actions">
                    <button className="btn btn-sm" onClick={() => openEdit(u)}>Edit</button>
                    <button className="btn btn-danger btn-sm" onClick={() => remove(u)}>Delete</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {open && (
        <Modal
          title={editing ? `Edit ${editing.full_name}` : 'New user'}
          onClose={() => setOpen(false)}
          footer={
            <>
              <button className="btn" onClick={() => setOpen(false)}>Cancel</button>
              <button className="btn btn-primary" form="user-form" disabled={saving}>
                {saving ? 'Saving…' : editing ? 'Save changes' : 'Create user'}
              </button>
            </>
          }
        >
          <form id="user-form" className="form-grid" onSubmit={save}>
            <Field label="Full name" span>
              <input name="full_name" value={form.full_name} onChange={set} required placeholder="Asha Rao" />
            </Field>
            <Field label="Email" hint="Must be unique">
              {/* type="email" makes the BROWSER validate the format before the
                  request is even sent -- a free first layer of validation. */}
              <input name="email" type="email" value={form.email} onChange={set}
                     required placeholder="asha@example.com" />
            </Field>
            <Field label="Phone">
              <input name="phone" value={form.phone} onChange={set} placeholder="+91-98000-00001" />
            </Field>
            <Field label="Address" span>
              <textarea name="address" value={form.address} onChange={set}
                        placeholder="Used as the default shipping address" />
            </Field>
          </form>
        </Modal>
      )}
    </>
  )
}
