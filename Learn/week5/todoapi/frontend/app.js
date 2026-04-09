// Backend API base URL - overridden by window.API_BASE from config.js if present
const API_BASE = (window.API_BASE || '/api/v1') + '/todos';

let currentFilter = 'all';
let editingId = null;

// ── DOM refs ──────────────────────────────────────────────────────────────────
const todoForm    = document.getElementById('todo-form');
const titleInput  = document.getElementById('title-input');
const descInput   = document.getElementById('desc-input');
const todoList    = document.getElementById('todo-list');
const errorBanner = document.getElementById('error-banner');
const statTotal   = document.getElementById('stat-total');
const statDone    = document.getElementById('stat-done');
const statPending = document.getElementById('stat-pending');
const editModal   = document.getElementById('edit-modal');
const editTitle   = document.getElementById('edit-title');
const editDesc    = document.getElementById('edit-desc');
const editCompleted = document.getElementById('edit-completed');

// ── Helpers ───────────────────────────────────────────────────────────────────
function showError(msg) {
  errorBanner.textContent = msg;
  errorBanner.classList.remove('hidden');
  setTimeout(() => errorBanner.classList.add('hidden'), 4000);
}

function formatDate(iso) {
  if (!iso) return '';
  return new Date(iso).toLocaleString(undefined, {
    month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'
  });
}

// ── API calls ─────────────────────────────────────────────────────────────────
async function apiFetch(path, options = {}) {
  const res = await fetch(API_BASE + path, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });
  if (res.status === 204) return null;
  const data = await res.json();
  if (!res.ok) throw new Error(data.detail || 'Request failed');
  return data;
}

async function fetchTodos() {
  const params = currentFilter === 'all'
    ? '/'
    : `/?completed=${currentFilter === 'completed'}`;
  return apiFetch(params);
}

async function fetchStats() {
  return apiFetch('/stats/summary');
}

async function createTodo(title, description) {
  return apiFetch('/', {
    method: 'POST',
    body: JSON.stringify({ title, description, completed: false }),
  });
}

async function updateTodo(id, payload) {
  return apiFetch(`/${id}`, {
    method: 'PUT',
    body: JSON.stringify(payload),
  });
}

async function deleteTodo(id) {
  return apiFetch(`/${id}`, { method: 'DELETE' });
}

// ── Render ────────────────────────────────────────────────────────────────────
function renderTodos(todos) {
  if (!todos.length) {
    todoList.innerHTML = `
      <div class="empty-state">
        <span>📋</span>
        No todos here yet!
      </div>`;
    return;
  }

  todoList.innerHTML = todos.map(todo => `
    <div class="todo-card ${todo.completed ? 'completed' : ''}" data-id="${todo.id}">
      <input type="checkbox" ${todo.completed ? 'checked' : ''}
             onchange="toggleComplete(${todo.id}, this.checked)" />
      <div class="todo-body">
        <div class="todo-title">${escHtml(todo.title)}</div>
        ${todo.description ? `<div class="todo-desc">${escHtml(todo.description)}</div>` : ''}
        <div class="todo-meta">Created ${formatDate(todo.created_at)}</div>
      </div>
      <div class="todo-actions">
        <button class="btn-icon btn-edit" onclick="openEdit(${todo.id}, ${JSON.stringify(todo).replace(/"/g, '&quot;')})">Edit</button>
        <button class="btn-icon btn-delete" onclick="confirmDelete(${todo.id})">Delete</button>
      </div>
    </div>
  `).join('');
}

function escHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function renderStats(stats) {
  statTotal.textContent   = `Total: ${stats.total}`;
  statDone.textContent    = `Done: ${stats.completed}`;
  statPending.textContent = `Pending: ${stats.pending}`;
}

// ── Load data ─────────────────────────────────────────────────────────────────
async function load() {
  todoList.innerHTML = '<div class="loading">Loading...</div>';
  try {
    const [todos, stats] = await Promise.all([fetchTodos(), fetchStats()]);
    renderTodos(todos);
    renderStats(stats);
  } catch (err) {
    showError('Could not reach the API: ' + err.message);
    todoList.innerHTML = '<div class="empty-state"><span>⚠️</span>Failed to load todos.</div>';
  }
}

// ── Event handlers ────────────────────────────────────────────────────────────
todoForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  const title = titleInput.value.trim();
  const desc  = descInput.value.trim();
  if (!title) return;
  try {
    await createTodo(title, desc);
    titleInput.value = '';
    descInput.value  = '';
    await load();
  } catch (err) {
    showError('Failed to add todo: ' + err.message);
  }
});

window.toggleComplete = async (id, checked) => {
  try {
    await updateTodo(id, { completed: checked });
    await load();
  } catch (err) {
    showError('Failed to update: ' + err.message);
  }
};

window.confirmDelete = async (id) => {
  if (!confirm('Delete this todo?')) return;
  try {
    await deleteTodo(id);
    await load();
  } catch (err) {
    showError('Failed to delete: ' + err.message);
  }
};

window.openEdit = (id, todo) => {
  editingId = id;
  editTitle.value     = todo.title;
  editDesc.value      = todo.description || '';
  editCompleted.checked = todo.completed;
  editModal.classList.remove('hidden');
};

document.getElementById('cancel-edit-btn').addEventListener('click', () => {
  editModal.classList.add('hidden');
  editingId = null;
});

document.getElementById('save-edit-btn').addEventListener('click', async () => {
  if (!editingId) return;
  try {
    await updateTodo(editingId, {
      title: editTitle.value.trim(),
      description: editDesc.value.trim(),
      completed: editCompleted.checked,
    });
    editModal.classList.add('hidden');
    editingId = null;
    await load();
  } catch (err) {
    showError('Failed to save: ' + err.message);
  }
});

// Click outside modal to close
editModal.addEventListener('click', (e) => {
  if (e.target === editModal) {
    editModal.classList.add('hidden');
    editingId = null;
  }
});

// Filter buttons
document.querySelectorAll('.filter-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    currentFilter = btn.dataset.filter;
    load();
  });
});

// ── Init ──────────────────────────────────────────────────────────────────────
load();
