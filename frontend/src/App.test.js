// src/App.test.js
// A minimal test so the CI "run frontend tests" step has something to run.
// We mock the api module so the test does not need a real backend.

import { render, screen } from '@testing-library/react';
import App from './App';

// Replace the real API calls with fake ones that resolve instantly.
jest.mock('./api', () => ({
  fetchMessage: () => Promise.resolve({ message: 'hi' }),
  fetchInfo: () => Promise.resolve({ hostname: 'pod-1', version: 'test', uptimeSeconds: 1 }),
}));

test('renders the app heading', () => {
  render(<App />);
  // The heading should appear immediately (it does not depend on the API call).
  expect(screen.getByText(/Two-Tier DevOps Demo/i)).toBeInTheDocument();
});
