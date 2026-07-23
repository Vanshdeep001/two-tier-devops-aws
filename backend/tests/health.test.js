// tests/health.test.js
// Jest + Supertest tests. Supertest sends fake HTTP requests straight to the
// Express app (no real port needed), and Jest checks the responses. The CI
// pipeline runs these before building the Docker image.

const request = require('supertest');
const app = require('../src/app');

describe('Backend API', () => {
  test('GET /health returns 200 and status ok', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
  });

  test('GET /ready returns 200 and status ready', async () => {
    const res = await request(app).get('/ready');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ready');
  });

  test('GET /api/message returns a message string', async () => {
    const res = await request(app).get('/api/message');
    expect(res.statusCode).toBe(200);
    expect(typeof res.body.message).toBe('string');
  });

  test('unknown route returns 404', async () => {
    const res = await request(app).get('/does-not-exist');
    expect(res.statusCode).toBe(404);
  });
});
