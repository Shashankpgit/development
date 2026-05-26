import { useState, useEffect } from 'react';
import { useAuth } from './context/AuthContext';
import Header from './components/Header';
import HealthCheck from './components/HealthCheck';
import NoteForm from './components/NoteForm';
import NoteList from './components/NoteList';
import { exchangeCode, buildLoginUrl, buildLogoutUrl } from './keycloak';

function App() {
  const { token, login, logout } = useAuth();

  function handleLogout() {
    logout();
    window.location.href = buildLogoutUrl();
  }
  const [refreshTrigger, setRefreshTrigger] = useState(0);

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const code = params.get('code');

    if (code) {
      window.history.replaceState({}, '', '/');
      exchangeCode(code)
        .then(data => login(data.access_token))
        .catch(() => console.error('Token exchange failed'));
      return;
    }

    if (!token) {
      window.location.href = buildLoginUrl();
    }
  }, []);

  function refreshNotes() {
    setRefreshTrigger(prev => prev + 1);
  }

  if (!token) return null;

  return (
    <div>
      <Header onLogout={handleLogout} />
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
