import React from 'react';

const UserList = ({ users, onEdit, onDelete }) => {
    if (!users.length) {
        return (
            <div className="glass-panel" style={{ padding: '3rem', textAlign: 'center', color: 'var(--text-secondary)' }}>
                <p>No users found. Create one to get started!</p>
            </div>
        );
    }

    return (
        <div className="grid grid-cols-2">
            {users.map(user => (
                <div key={user.id} className="glass-panel" style={{ padding: '1.5rem', display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                    <div>
                        <h3 style={{ margin: 0, fontSize: '1.25rem' }}>{user.name}</h3>
                        <p style={{ margin: '0.25rem 0 0', color: 'var(--text-secondary)' }}>{user.email}</p>
                    </div>

                    <div style={{ marginTop: 'auto', display: 'flex', gap: '0.75rem', borderTop: '1px solid var(--glass-border)', paddingTop: '1rem' }}>
                        <button
                            onClick={() => onEdit(user)}
                            style={{
                                flex: 1,
                                padding: '0.5rem',
                                borderRadius: '0.25rem',
                                border: '1px solid var(--accent-primary)',
                                color: 'var(--accent-primary)',
                                background: 'transparent'
                            }}
                        >
                            Edit
                        </button>
                        <button
                            onClick={() => onDelete(user.id)}
                            className="btn-danger"
                            style={{ flex: 1 }}
                        >
                            Delete
                        </button>
                    </div>
                </div>
            ))}
        </div>
    );
};

export default UserList;
