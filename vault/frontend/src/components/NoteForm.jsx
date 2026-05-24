import { useState } from 'react';

const API_URL = import.meta.env.VITE_API_URL;

function NoteForm({ onNoteAdded }) {
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');

  async function handleSubmit() {
    if (!title) return;

    await fetch(`${API_URL}/notes`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ user_id: 1, title, body }),
    });

    setTitle('');
    setBody('');
    onNoteAdded();
  }

  return (
    <div className="card">
      <h2>New Note</h2>
      <div className="form-group">
        <input
          className="input"
          value={title}
          onChange={e => setTitle(e.target.value)}
          placeholder="Title"
        />
        <textarea
          className="input"
          value={body}
          onChange={e => setBody(e.target.value)}
          placeholder="Body (optional)"
          rows={4}
        />
        <button className="btn btn-primary" onClick={handleSubmit}>Save Note</button>
      </div>
    </div>
  );
}

export default NoteForm;
