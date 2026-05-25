import { useState } from 'react';
import { useAuth } from './context/AuthContext';
import Header from './components/Header';
import HealthCheck from './components/HealthCheck';
import NoteForm from './components/NoteForm';
import NoteList from './components/NoteList';
import AuthPage from './components/AuthPage';

function App() {
  const { token, logout } = useAuth();
  const [refreshTrigger, setRefreshTrigger] = useState(0);

  function refreshNotes() {
    setRefreshTrigger(prev => prev + 1);
  }

  if (!token) return <AuthPage />;

  return (
    <div>
      <Header onLogout={logout} />
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
