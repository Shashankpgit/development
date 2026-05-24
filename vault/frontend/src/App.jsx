import { useState } from 'react';
import Header from './components/Header';
import HealthCheck from './components/HealthCheck';
import NoteForm from './components/NoteForm';
import NoteList from './components/NoteList';

function App() {
  const [refreshTrigger, setRefreshTrigger] = useState(0);

  function refreshNotes() {
    setRefreshTrigger(prev => prev + 1);
  }

  return (
    <div>
      <Header />
      <div className="container">
        <div className="full-width">
          <HealthCheck />
        </div>
        <NoteForm onNoteAdded={refreshNotes} />
        <NoteList refreshTrigger={refreshTrigger} onNoteDeleted={refreshNotes} />
      </div>
    </div>
  );
}

export default App;
