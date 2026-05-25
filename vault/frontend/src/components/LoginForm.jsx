import { useState } from 'react';
import { useAuth } from '../context/AuthContext';

const API_URL = import.meta.env.VITE_API_URL;

function LoginForm({ onSwitchToRegister }) {
  const { login } = useAuth();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  async function handleLogin() {
    setError('');
    const response = await fetch(`${API_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password }),
    });

    const data = await response.json();

    if (!response.ok) {
      setError(data.detail || 'Login failed');
      return;
    }

    login(data.access_token);
  }

  return (
    <div className="form-group">
      <h2>Login</h2>
      <input className="input" placeholder="Username" value={username} onChange={e => setUsername(e.target.value)} />
      <input className="input" placeholder="Password" type="password" value={password} onChange={e => setPassword(e.target.value)} />
      {error && <p style={{ color: '#e94560', fontSize: '0.85rem' }}>{error}</p>}
      <button className="btn btn-primary" onClick={handleLogin}>Login</button>
      <p style={{ fontSize: '0.85rem', color: '#888', textAlign: 'center' }}>
        No account? <span style={{ color: '#1a1a2e', cursor: 'pointer', fontWeight: 600 }} onClick={onSwitchToRegister}>Register</span>
      </p>
    </div>
  );
}

export default LoginForm;
