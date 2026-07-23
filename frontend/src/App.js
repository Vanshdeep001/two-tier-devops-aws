// src/App.js
// The main React component. Fetches data from the backend and shows it in a
// polished dashboard-style UI.

import React, { useEffect, useState, useCallback } from 'react';
import { fetchMessage, fetchInfo } from './api';
import './App.css';

// The tech stack shown as badges at the bottom.
const STACK = ['React', 'Node.js', 'Express', 'Docker', 'Kubernetes', 'Terraform', 'GitHub Actions', 'AWS'];

function App() {
  const [message, setMessage] = useState('');
  const [info, setInfo] = useState(null);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(true);

  // useCallback so we can reuse this both on mount and on the Refresh button.
  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [msg, meta] = await Promise.all([fetchMessage(), fetchInfo()]);
      setMessage(msg.message);
      setInfo(meta);
      setError(null);
    } catch (err) {
      // Common cause: backend down, wrong API URL, or CORS blocked.
      setError('Could not reach the backend API.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  // Turn seconds into a friendly "2m 5s" style string.
  const prettyUptime = (s) => (s >= 60 ? `${Math.floor(s / 60)}m ${s % 60}s` : `${s}s`);

  return (
    <div className="page">
      <div className="card">
        <header className="card__head">
          <span className={`pill ${error ? 'pill--down' : 'pill--live'}`}>
            <span className="dot" />
            {error ? 'Offline' : 'Live'}
          </span>
          <h1>Two-Tier DevOps Demo</h1>
          <p className="subtitle">React → Node/Express → Kubernetes on AWS</p>
        </header>

        {error ? (
          <p className="error">{error}</p>
        ) : (
          <>
            <p className="message">{loading ? 'Loading…' : message}</p>

            {info && (
              <div className="stats">
                <div className="stat">
                  <span className="stat__label">Served by pod</span>
                  {/* Refresh and watch this flip between replicas = load balancing */}
                  <span className="stat__value mono">{info.hostname}</span>
                </div>
                <div className="stat">
                  <span className="stat__label">Version (git sha)</span>
                  <span className="stat__value mono">{info.version.slice(0, 12)}</span>
                </div>
                <div className="stat">
                  <span className="stat__label">Backend uptime</span>
                  <span className="stat__value">{prettyUptime(info.uptimeSeconds)}</span>
                </div>
              </div>
            )}

            <button className="btn" onClick={load} disabled={loading}>
              {loading ? 'Refreshing…' : '↻ Refresh (watch the pod change)'}
            </button>
          </>
        )}

        <footer className="stack">
          {STACK.map((t) => (
            <span key={t} className="badge">{t}</span>
          ))}
        </footer>
      </div>
    </div>
  );
}

export default App;
