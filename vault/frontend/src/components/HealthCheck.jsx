import { useState } from 'react';

const API_URL = import.meta.env.VITE_API_URL;

function HealthCheck() {
  const [status, setStatus] = useState(null);

  async function checkHealth() {
    const response = await fetch(`${API_URL}/health`);
    const data = await response.json();
    setStatus(data);
  }

  return (
    <div className="card full-width">
      <h2>Server Status</h2>
      <button className="btn btn-primary" onClick={checkHealth}>Check Health</button>
      {status && (
        <div className="health-result">
          <span className={`health-pill ${status.status === 'ok' ? 'ok' : 'error'}`}>
            ● {status.status}
          </span>
          <span className={`health-pill ${status.database === 'connected' ? 'ok' : 'error'}`}>
            DB: {status.database}
          </span>
          <span className="health-pill ok">v{status.version}</span>
        </div>
      )}
    </div>
  );
}

export default HealthCheck;
