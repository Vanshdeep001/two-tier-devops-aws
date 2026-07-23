// src/App.js
// The main React component. It calls the backend on load and shows the result.

import React, { useEffect, useState } from 'react';
import { fetchMessage, fetchInfo } from './api';
import './App.css';

function App() {
  // React state: when these change, the component re-renders.
  const [message, setMessage] = useState('Loading...');
  const [info, setInfo] = useState(null);
  const [error, setError] = useState(null);

  // Load data once when the component first mounts (empty dependency array []).
  useEffect(() => {
    async function load() {
      try {
        const msg = await fetchMessage();
        setMessage(msg.message);
        const meta = await fetchInfo();
        setInfo(meta);
        setError(null);
      } catch (err) {
        // Common cause: backend down, wrong API URL, or CORS blocked.
        setError('Could not reach the backend API.');
      }
    }
    load();
  }, []);

  return (
    <div className="container">
      <h1>Two-Tier DevOps Demo</h1>

      {error ? (
        <p className="error">{error}</p>
      ) : (
        <>
          <p className="message">{message}</p>
          {info && (
            <div className="info">
              {/* hostname is the backend pod name — refresh to see it change */}
              <p><strong>Served by pod:</strong> {info.hostname}</p>
              <p><strong>Backend version:</strong> {info.version}</p>
              <p><strong>Uptime:</strong> {info.uptimeSeconds}s</p>
            </div>
          )}
        </>
      )}

      <footer>React frontend → Node/Express backend → Kubernetes</footer>
    </div>
  );
}

export default App;
