import LoginForm from './LoginForm';

function AuthPage() {
  return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#f0f2f5' }}>
      <div className="card" style={{ width: '100%', maxWidth: '400px' }}>
        <div style={{ textAlign: 'center', marginBottom: '1.5rem' }}>
          <h1 style={{ fontSize: '1.4rem', color: '#1a1a2e' }}>Personal Vault</h1>
          <p style={{ color: '#888', fontSize: '0.85rem' }}>Your private secure storage</p>
        </div>
        <LoginForm />
      </div>
    </div>
  );
}

export default AuthPage;
