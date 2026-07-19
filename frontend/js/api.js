/**
 * PedalShare API client
 * All API calls go through this module.
 */

const BASE = '';   // same origin

let _token = localStorage.getItem('ps_token') || null;

export const Auth = {
  get token() { return _token; },
  set token(v) { _token = v; if (v) localStorage.setItem('ps_token', v); else localStorage.removeItem('ps_token'); },
  get isLoggedIn() { return !!_token; },
  logout() { this.token = null; },
};

async function request(method, path, body, isFormData = false) {
  const headers = {};
  if (_token) headers['Authorization'] = 'Bearer ' + _token;
  if (!isFormData && body) headers['Content-Type'] = 'application/json';

  const res = await fetch(`${BASE}${path}`, {
    method,
    headers,
    body: isFormData ? body : (body ? JSON.stringify(body) : undefined),
  });

  if (res.status === 204) return null;

  const data = await res.json().catch(() => ({ detail: res.statusText }));
  if (!res.ok) {
    const msg = data.detail || JSON.stringify(data);
    throw new Error(typeof msg === 'string' ? msg : JSON.stringify(msg));
  }
  return data;
}

const get  = (path)         => request('GET',    path);
const post = (path, body, fd) => request('POST',  path, body, fd);
const patch = (path, body)  => request('PATCH',   path, body);
const del  = (path)         => request('DELETE',  path);

// ── Auth ──────────────────────────────────────────────────────────────
export async function register(formData) {
  const res = await fetch(`${BASE}/api/auth/register`, {
    method: 'POST',
    headers: _token ? { Authorization: 'Bearer ' + _token } : {},
    body: formData,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.detail || 'Registration failed');
  return data;
}

export async function login(email, password) {
  const form = new URLSearchParams({ username: email, password });
  const res = await fetch(`${BASE}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: form,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.detail || 'Login failed');
  Auth.token = data.access_token;
  return data;
}

// ── User ──────────────────────────────────────────────────────────────
export const getProfile       = ()    => get('/api/users/me');
export const getPointLedger   = ()    => get('/api/users/me/points');
export const getMyRentals     = ()    => get('/api/users/me/rentals');
export const getMyDeliveries  = ()    => get('/api/users/me/deliveries');
export const getGamification  = ()    => get('/api/users/me/gamification');
export const getRedemptions   = ()    => get('/api/users/me/redemptions');

// ── Bikes ─────────────────────────────────────────────────────────────
export const listBikes        = ()    => get('/api/bikes/');
export const searchBikes      = (body) => post('/api/bikes/search', body);
export const getBike          = (id)  => get(`/api/bikes/${id}`);
export const getBikeReviews   = (id)  => get(`/api/bikes/${id}/reviews`);
export const createBike       = (body) => post('/api/bikes/', body);
export const getMyBikes       = ()    => get('/api/bikes/mine');

// ── Rentals ───────────────────────────────────────────────────────────
export const bookBike         = (body) => post('/api/rentals/', body);
export const startRental      = (id)   => post(`/api/rentals/${id}/start`);
export const endRental        = (id, body) => post(`/api/rentals/${id}/end`, body);
export const cancelRental     = (id)   => post(`/api/rentals/${id}/cancel`);
export const leaveReview      = (id, body) => post(`/api/rentals/${id}/review`, body);

// ── Delivery ──────────────────────────────────────────────────────────
export const listOpenJobs     = ()     => get('/api/delivery/jobs');
export const searchJobs       = (body) => post('/api/delivery/jobs/search', body);
export const getJob           = (id)   => get(`/api/delivery/jobs/${id}`);
export const acceptSegment    = (jobId, body) => post(`/api/delivery/jobs/${jobId}/accept`, body);
export const completeSegment  = (segId, body) => post(`/api/delivery/segments/${segId}/complete`, body);

// ── Shop ──────────────────────────────────────────────────────────────
export const listOffers       = ()    => get('/api/shop/offers');
export const redeemOffer      = (id)  => post(`/api/shop/offers/${id}/redeem`);

// ── Gamification ──────────────────────────────────────────────────────
export const getLeaderboard   = ()    => get('/api/gamification/leaderboard');
