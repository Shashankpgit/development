function Header({ onLogout }) {
  return (
    <header className="header" style={{ justifyContent: 'space-between' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
        <h1>Personal Vault</h1>
        <span className="header-badge">beta</span>
      </div>
      <button
        onClick={onLogout}
        style={{ background: 'transparent', border: '1px solid rgba(255,255,255,0.3)', color: 'white', padding: '0.35rem 0.85rem', borderRadius: '6px', cursor: 'pointer', fontSize: '0.85rem' }}
      >
        Logout
      </button>
    </header>
  );
}

export default Header;
