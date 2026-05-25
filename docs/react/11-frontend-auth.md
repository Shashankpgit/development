# Frontend Auth — Login, Register, Token Management

## Stage 1 — What we are building

- `AuthContext` — holds the token, provides login/logout to all components
- `AuthPage.jsx` — shows login + register forms when not logged in
- `LoginForm.jsx` — POST /auth/login, stores token on success
- `RegisterForm.jsx` — POST /auth/register, switches to login on success
- Update all fetch calls to send Authorization header

## New files
```
vault/frontend/src/
├── context/
│   └── AuthContext.jsx     ← token state + login/logout functions
└── components/
    ├── AuthPage.jsx         ← login/register toggle page
    ├── LoginForm.jsx        ← login form
    └── RegisterForm.jsx     ← register form
```

## Changed files
```
vault/frontend/src/App.jsx              ← show AuthPage or main app based on token
vault/frontend/src/components/NoteList.jsx    ← add Authorization header
vault/frontend/src/components/NoteForm.jsx    ← add Authorization header
vault/frontend/src/components/NoteCard.jsx    ← add Authorization header
vault/frontend/src/components/HealthCheck.jsx ← add Authorization header
```

---

## Stage 2 — KT: New concepts

### 1. React Context

Context shares data across the component tree without passing props at every level.

```jsx
// Create context
const AuthContext = createContext();

// Wrap the whole app — any child can read from it
<AuthContext.Provider value={{ token, login, logout }}>
  <App />
</AuthContext.Provider>

// Any component reads it with useContext
const { token, logout } = useContext(AuthContext);
```

### 2. Conditional rendering based on auth state

```jsx
// If no token → show login page
// If token exists → show the real app
{token ? <MainApp /> : <AuthPage />}
```

### 3. Authorization header in every fetch

```javascript
headers: {
  "Content-Type": "application/json",
  "Authorization": `Bearer ${token}`
}
```

### 4. localStorage for token persistence

```javascript
localStorage.setItem("token", token)   // save on login
localStorage.getItem("token")          // read on page load
localStorage.removeItem("token")       // clear on logout
```

Token survives page refresh. Without this, logging in is lost on refresh.
