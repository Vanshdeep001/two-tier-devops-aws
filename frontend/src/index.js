// src/index.js
// The JavaScript entry point. It finds <div id="root"> in index.html and tells
// React to render our <App /> component inside it.

import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './index.css';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  // StrictMode adds extra dev-time checks/warnings. It has no effect in prod.
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
