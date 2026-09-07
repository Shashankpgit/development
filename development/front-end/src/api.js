/*
 * The one and only place this app talks to the backend.
 *
 * WHY centralise it: every call needs the same base path, the same JSON
 * headers and the same error handling. Spread across 20 components that is 20
 * copies of the same bug. Here it is one function, `request`.
 */

// Empty string = relative URLs. fetch('/api/products') resolves against
// whatever host the page came from, so the dev proxy (vite.config.js) and
// nginx in production both just work. No hostname is ever hardcoded.
const BASE = import.meta.env.VITE_API_BASE_URL ?? ''

/** Thrown for any non-2xx response so callers can `catch` one thing. */
export class ApiError extends Error {
  constructor(message, status, body) {
    super(message)
    this.status = status
    this.body = body
  }
}

async function request(path, { method = 'GET', body } = {}) {
  const res = await fetch(BASE + path, {
    method,
    // Without this header FastAPI does not know the body is JSON and replies
    // 422. Open DevTools -> Network -> click the request -> Headers to see it.
    headers: body ? { 'Content-Type': 'application/json' } : undefined,
    body: body ? JSON.stringify(body) : undefined,
  })

  // 204 No Content has an empty body. Calling res.json() on it throws
  // "Unexpected end of JSON input" -- a classic first-week frontend bug.
  if (res.status === 204) return null

  const text = await res.text()
  const data = text ? JSON.parse(text) : null

  if (!res.ok) {
    // FastAPI puts the message in `detail`. For validation errors (422) that
    // detail is an ARRAY of field errors, so flatten it into one readable line.
    const detail = data?.detail
    const message = Array.isArray(detail)
      ? detail.map((d) => `${d.loc?.slice(1).join('.') || 'field'}: ${d.msg}`).join(', ')
      : detail || `Request failed with ${res.status}`
    throw new ApiError(message, res.status, data)
  }
  return data
}

const crud = (resource) => ({
  list: (query = '') => request(`/api/${resource}${query}`),
  get: (id) => request(`/api/${resource}/${id}`),
  create: (body) => request(`/api/${resource}`, { method: 'POST', body }),
  update: (id, body) => request(`/api/${resource}/${id}`, { method: 'PUT', body }),
  remove: (id) => request(`/api/${resource}/${id}`, { method: 'DELETE' }),
})

export const api = {
  products: crud('products'),
  categories: crud('categories'),
  users: crud('users'),

  cart: {
    get: (userId) => request(`/api/cart/${userId}`),
    add: (body) => request('/api/cart/items', { method: 'POST', body }),
    updateItem: (itemId, quantity) =>
      request(`/api/cart/items/${itemId}`, { method: 'PUT', body: { quantity } }),
    removeItem: (itemId) => request(`/api/cart/items/${itemId}`, { method: 'DELETE' }),
  },

  orders: {
    ...crud('orders'),
    checkout: (userId, shippingAddress) =>
      request('/api/orders', {
        method: 'POST',
        body: { user_id: userId, shipping_address: shippingAddress || null },
      }),
  },

  health: () => request('/health'),
}
