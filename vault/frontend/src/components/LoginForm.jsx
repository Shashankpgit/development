import { buildLoginUrl } from '../keycloak';

function LoginForm() {
  function handleLogin() {
    window.location.href = buildLoginUrl();
  }

  return (
    <div className="form-group">
      <h2>Login</h2>
      <p style={{ color: '#888', fontSize: '0.85rem', textAlign: 'center', marginBottom: '1rem' }}>
        You will be redirected to Keycloak to sign in securely.
      </p>
      <button className="btn btn-primary" onClick={handleLogin}>Login with Keycloak</button>
    </div>
  );
}

export default LoginForm;
