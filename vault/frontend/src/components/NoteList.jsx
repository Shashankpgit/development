import { useState, useEffect } from 'react';
import NoteCard from './NoteCard';
import { useAuth } from '../context/AuthContext';

const API_URL = import.meta.env.VITE_API_URL;

function NoteList({ refreshTrigger, onNoteDeleted }) {
  const { token } = useAuth();
  const [notes, setNotes] = useState([]);

  useEffect(() => {
    fetch(`${API_URL}/notes`, {
      headers: { Authorization: `Bearer ${token}` },
    })
      .then(res => res.json())
      .then(data => setNotes(data));
  }, [refreshTrigger]);

  return (
    <div className="card">
      <h2>Notes {notes.length > 0 && <span style={{ color: '#aaa', fontWeight: 400 }}>({notes.length})</span>}</h2>
      {notes.length === 0
        ? <p className="empty-state">No notes yet. Add one on the left.</p>
        : <div className="note-list">
            {notes.map(note => (
              <NoteCard key={note.id} note={note} onDelete={onNoteDeleted} />
            ))}
          </div>
      }
    </div>
  );
}

export default NoteList;
