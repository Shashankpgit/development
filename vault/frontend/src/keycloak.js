const KEYCLOAK_URL = 'http://localhost:8080';
const REALM = 'vault';
const CLIENT_ID = 'vault-frontend';
const REDIRECT_URI = window.location.origin;

export function buildLoginUrl() {
  const params = new URLSearchParams({
    client_id: CLIENT_ID,
    redirect_uri: REDIRECT_URI,
    response_type: 'code',
    scope: 'openid',
  });
  return `${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/auth?${params}`;
}

export function buildLogoutUrl() {
  const params = new URLSearchParams({
    client_id: CLIENT_ID,
    post_logout_redirect_uri: REDIRECT_URI,
  });
  return `${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/logout?${params}`;
}

export async function exchangeCode(code) {
  const params = new URLSearchParams({
    grant_type: 'authorization_code',
    code,
    client_id: CLIENT_ID,
    redirect_uri: REDIRECT_URI,
  });
  const res = await fetch(
    `${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: params,
    }
  );
  if (!res.ok) throw new Error('Token exchange failed');
  return res.json();
}
