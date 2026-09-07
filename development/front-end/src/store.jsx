/*
 * Shared app state: the "acting as" user, their cart count, and toasts.
 *
 * WHY React Context: without it, the cart badge in the top bar could only
 * learn the cart count if every component between App and the badge passed it
 * down as a prop ("prop drilling"). Context lets any component read shared
 * state directly, no matter how deeply nested.
 *
 * There is no login in this app, so "who am I" is an explicit dropdown choice.
 * That keeps auth out of a CRUD exercise while still letting the cart and
 * orders be per-user, exactly as the API requires.
 */
import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react'
import { api } from './api'

const AppContext = createContext(null)

// localStorage persists across reloads, so a refresh does not reset your
// selected user. It stores strings only -- hence the Number() on read.
const STORAGE_KEY = 'nimbus.userId'

export function AppProvider({ children }) {
  const [users, setUsers] = useState([])
  const [userId, setUserId] = useState(() => {
    const saved = localStorage.getItem(STORAGE_KEY)
    return saved ? Number(saved) : null
  })
  const [cartCount, setCartCount] = useState(0)
  const [toasts, setToasts] = useState([])

  const toast = useCallback((message, kind = 'ok') => {
    const id = crypto.randomUUID()
    setToasts((t) => [...t, { id, message, kind }])
    // Auto-dismiss. The cleanup is not critical here because the timer only
    // touches state that still exists, but see the effects below for the
    // general rule.
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), 3600)
  }, [])

  const loadUsers = useCallback(async () => {
    try {
      const list = await api.users.list()
      setUsers(list)
      // Auto-pick the first user so the app is usable immediately, and
      // recover if the saved user was deleted.
      setUserId((current) => {
        if (current && list.some((u) => u.id === current)) return current
        return list[0]?.id ?? null
      })
    } catch (err) {
      toast(err.message, 'err')
    }
  }, [toast])

  const refreshCart = useCallback(async () => {
    if (!userId) return setCartCount(0)
    try {
      const cart = await api.cart.get(userId)
      setCartCount(cart.total_items)
    } catch {
      setCartCount(0)
    }
  }, [userId])

  // useEffect = "run this AFTER the component has rendered".
  // The array at the end is the dependency list: re-run only when one of
  // those values changed. An empty array would mean "once, on mount".
  useEffect(() => { loadUsers() }, [loadUsers])
  useEffect(() => { refreshCart() }, [refreshCart])

  useEffect(() => {
    if (userId) localStorage.setItem(STORAGE_KEY, String(userId))
  }, [userId])

  // useMemo stops this object being rebuilt on every render. A new object
  // identity would make every consumer of the context re-render needlessly.
  const value = useMemo(
    () => ({
      users, userId, setUserId, loadUsers,
      cartCount, refreshCart,
      currentUser: users.find((u) => u.id === userId) ?? null,
      toasts, toast,
    }),
    [users, userId, loadUsers, cartCount, refreshCart, toasts, toast],
  )

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>
}

/** Custom hook so components write useApp() instead of useContext(AppContext). */
export function useApp() {
  const ctx = useContext(AppContext)
  if (!ctx) throw new Error('useApp must be used inside <AppProvider>')
  return ctx
}
