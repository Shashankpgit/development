import { useAuth } from '../context/AuthContext';

const API_URL = import.meta.env.VITE_API_URL;

function NoteCard({ note, onDelete }) {
  const { token } = useAuth();

  async function handleDelete() {
    await fetch(`${API_URL}/notes/${note.id}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    });
    onDelete();
  }

  return (
    <div className="note-card">
      <div className="note-card-content">
        <div className="note-title">{note.title}</div>
        <div className="note-body">{note.body || '(no body)'}</div>
      </div>
      <button className="btn btn-danger" onClick={handleDelete}>Delete</button>
    </div>
  );
}

export default NoteCard;
