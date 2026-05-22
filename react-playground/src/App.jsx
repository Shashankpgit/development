import { useState, useEffect } from 'react';

function App() {
  const [notes, setNotes] = useState([]);

  useEffect(() => {
    fetch('http://localhost:8000/notes?user_id=1')
      .then(res => res.json())
      .then(data => setNotes(data));
  }, []);

  return (
    <div style={{ padding: "1rem" }}>
      <h1>My Notes</h1>
      {notes.map(note => (
        <p key={note.id}>{note.title}</p>
      ))}
    </div>
  );
}

export default App;
