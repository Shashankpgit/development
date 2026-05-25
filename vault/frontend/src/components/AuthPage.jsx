import { useState } from 'react';
import LoginForm from './LoginForm';
import RegisterForm from './RegisterForm';

function AuthPage() {
  const [view, setView] = useState('login');

  return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#f0f2f5' }}>
      <div className="card" style={{ width: '100%', maxWidth: '400px' }}>
        <div style={{ textAlign: 'center', marginBottom: '1.5rem' }}>
          <h1 style={{ fontSize: '1.4rem', color: '#1a1a2e' }}>Personal Vault</h1>
          <p style={{ color: '#888', fontSize: '0.85rem' }}>Your private secure storage</p>
        </div>
        {view === 'login'
          ? <LoginForm onSwitchToRegister={() => setView('register')} />
          : <RegisterForm onSwitchToLogin={() => setView('login')} />
        }
      </div>
    </div>
  );
}

export default AuthPage;
