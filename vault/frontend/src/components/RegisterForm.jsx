import { useState } from 'react';

const API_URL = import.meta.env.VITE_API_URL;

function RegisterForm({ onSwitchToLogin }) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);

  async function handleRegister() {
    setError('');
    const response = await fetch(`${API_URL}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password }),
    });

    const data = await response.json();

    if (!response.ok) {
      setError(data.detail || 'Registration failed');
      return;
    }

    setSuccess(true);
    setTimeout(onSwitchToLogin, 1500);
  }

  return (
    <div className="form-group">
      <h2>Register</h2>
      <input className="input" placeholder="Username" value={username} onChange={e => setUsername(e.target.value)} />
      <input className="input" placeholder="Password" type="password" value={password} onChange={e => setPassword(e.target.value)} />
      {error && <p style={{ color: '#e94560', fontSize: '0.85rem' }}>{error}</p>}
      {success && <p style={{ color: '#065f46', fontSize: '0.85rem' }}>Registered! Redirecting to login...</p>}
      <button className="btn btn-primary" onClick={handleRegister}>Register</button>
      <p style={{ fontSize: '0.85rem', color: '#888', textAlign: 'center' }}>
        Have an account? <span style={{ color: '#1a1a2e', cursor: 'pointer', fontWeight: 600 }} onClick={onSwitchToLogin}>Login</span>
      </p>
    </div>
  );
}

export default RegisterForm;
