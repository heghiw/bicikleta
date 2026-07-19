import * as API from './api.js';
const { Auth } = API;

// ── Toast ──────────────────────────────────────────────────────────────────
function toast(msg, type = 'info') {
  const c = document.getElementById('toast-container');
  const el = document.createElement('div');
  el.className = `toast toast-${type}`;
  el.textContent = msg;
  c.appendChild(el);
  setTimeout(() => el.remove(), 3500);
}

// ── Stars ───────────────────────────────────────────────────────────────────
function stars(rating) {
  const full = Math.round(rating || 0);
  return '★'.repeat(full) + '☆'.repeat(5 - full);
}

// ── Badge helpers ────────────────────────────────────────────────────────────
function statusBadge(status) {
  const map = {
    available:   ['badge-green', '● Available'],
    reserved:    ['badge-amber', '● Reserved'],
    in_delivery: ['badge-blue',  '● In Delivery'],
    maintenance: ['badge-amber', '● Maintenance'],
    offline:     ['badge-gray',  '● Offline'],
    open:        ['badge-green', '● Open'],
    in_progress: ['badge-blue',  '● In Progress'],
    completed:   ['badge-gray',  '● Done'],
    active:      ['badge-green', '● Active'],
    pending:     ['badge-amber', '● Pending'],
    cancelled:   ['badge-red',   '● Cancelled'],
  };
  const [cls, text] = map[status] || ['badge-gray', status];
  return `<span class="badge ${cls}">${text}</span>`;
}

// ── Router ──────────────────────────────────────────────────────────────────
const routes = {};
function addRoute(hash, fn) { routes[hash] = fn; }

function navigate(hash) {
  window.location.hash = hash;
}

window.addEventListener('hashchange', () => render(window.location.hash.slice(1)));

async function render(route = '') {
  const app = document.getElementById('app');
  if (!app) return;

  // Update nav active state
  document.querySelectorAll('.nav-link[data-route]').forEach(el => {
    el.classList.toggle('active', el.dataset.route === route);
  });

  const handler = routes[route] || routes[''];
  if (handler) {
    try {
      app.innerHTML = `<div class="loading-center"><div class="spinner"></div></div>`;
      await handler(app);
    } catch (e) {
      app.innerHTML = `<div class="container section"><div class="empty-state">
        <div class="icon">⚠️</div><h3>Error</h3><p>${e.message}</p>
      </div></div>`;
    }
  }
  updateNavAuthState();
}

// ── Nav auth state ────────────────────────────────────────────────────────
async function updateNavAuthState() {
  const authZone = document.getElementById('nav-auth');
  const navLinks = document.getElementById('nav-links');
  if (!authZone) return;

  if (Auth.isLoggedIn) {
    try {
      const user = await API.getProfile();
      authZone.innerHTML = `
        <div class="nav-points">🌿 ${user.points_balance} pts</div>
        <button class="btn btn-ghost btn-sm" onclick="navigate('profile')">👤 ${user.name.split(' ')[0]}</button>
        <button class="btn btn-outline btn-sm" id="logout-btn">Log out</button>`;
      document.getElementById('logout-btn')?.addEventListener('click', () => {
        Auth.logout();
        navigate('');
        toast('Logged out', 'info');
      });
    } catch { /* token expired */ Auth.logout(); }
    navLinks.innerHTML = `
      <span class="nav-link" data-route="bikes" onclick="navigate('bikes')">Browse Bikes</span>
      <span class="nav-link" data-route="delivery" onclick="navigate('delivery')">Deliver & Earn</span>
      <span class="nav-link" data-route="shop" onclick="navigate('shop')">Rewards Shop</span>
      <span class="nav-link" data-route="leaderboard" onclick="navigate('leaderboard')">Leaderboard</span>`;
  } else {
    authZone.innerHTML = `
      <button class="btn btn-outline btn-sm" onclick="openModal('login')">Log in</button>
      <button class="btn btn-primary btn-sm" onclick="openModal('register')">Sign up free</button>`;
    navLinks.innerHTML = '';
  }
  document.querySelectorAll('.nav-link[data-route]').forEach(el => {
    el.classList.toggle('active', el.dataset.route === window.location.hash.slice(1));
  });
}

// ── Auth modal ─────────────────────────────────────────────────────────────
window.openModal = function(type) {
  const backdrop = document.getElementById('modal-backdrop');
  const body = document.getElementById('modal-body');
  backdrop.classList.remove('hidden');

  if (type === 'login') {
    body.innerHTML = `
      <h2 class="modal-title">Welcome back 👋</h2>
      <form id="login-form" class="flex flex-col gap-4">
        <div class="form-group">
          <label class="form-label">Email</label>
          <input class="form-input" type="email" name="email" placeholder="you@example.com" required>
        </div>
        <div class="form-group">
          <label class="form-label">Password</label>
          <input class="form-input" type="password" name="password" placeholder="••••••••" required>
        </div>
        <button type="submit" class="btn btn-primary btn-block btn-lg">Log in</button>
        <p style="text-align:center;font-size:13px;color:var(--text-3)">
          No account? <a href="#" onclick="openModal('register')" style="color:var(--primary)">Sign up free</a>
        </p>
      </form>`;
    document.getElementById('login-form').onsubmit = async (e) => {
      e.preventDefault();
      const fd = new FormData(e.target);
      try {
        await API.login(fd.get('email'), fd.get('password'));
        closeModal();
        toast('Welcome back!', 'success');
        updateNavAuthState();
        navigate('bikes');
      } catch(err) { toast(err.message, 'error'); }
    };
  } else {
    body.innerHTML = `
      <h2 class="modal-title">Create your account</h2>
      <form id="register-form" class="flex flex-col gap-4" enctype="multipart/form-data">
        <div class="form-group">
          <label class="form-label">Full name</label>
          <input class="form-input" name="name" placeholder="Jane Smith" required>
        </div>
        <div class="form-group">
          <label class="form-label">Email</label>
          <input class="form-input" type="email" name="email" placeholder="jane@example.com" required>
        </div>
        <div class="form-group">
          <label class="form-label">Password</label>
          <input class="form-input" type="password" name="password" placeholder="Min. 8 characters" minlength="8" required>
        </div>
        <div class="form-group">
          <label class="form-label">Government ID <span class="form-hint">(for verification)</span></label>
          <input class="form-input" type="file" name="id_document" accept="image/*" required>
        </div>
        <div class="form-group">
          <label class="form-label">Selfie photo</label>
          <input class="form-input" type="file" name="selfie" accept="image/*" required>
        </div>
        <button type="submit" class="btn btn-primary btn-block btn-lg">Create account</button>
        <p style="font-size:12px;color:var(--text-3);text-align:center">
          Your ID is reviewed by our team within 24 hours.
        </p>
      </form>`;
    document.getElementById('register-form').onsubmit = async (e) => {
      e.preventDefault();
      const fd = new FormData(e.target);
      const btn = e.target.querySelector('button[type=submit]');
      btn.disabled = true;
      btn.textContent = 'Creating account…';
      try {
        await API.register(fd);
        closeModal();
        toast('Account created! Our team will verify your ID within 24 hours.', 'success');
      } catch(err) { toast(err.message, 'error'); }
      finally { btn.disabled = false; btn.textContent = 'Create account'; }
    };
  }
};

window.closeModal = function() {
  document.getElementById('modal-backdrop')?.classList.add('hidden');
};

// ── PAGES ──────────────────────────────────────────────────────────────────

// ── Landing ───────────────────────────────────────────────────────────────
addRoute('', (app) => {
  app.innerHTML = `
    <section class="hero">
      <div class="hero-eyebrow">🌍 Zero-emission urban mobility</div>
      <h1>Rent. Ride. <em>Earn.</em></h1>
      <p>The peer-to-peer bike network where anyone can rent a bike, move one for rewards, or list their own to earn money.</p>
      <div class="hero-actions">
        <button class="btn btn-primary btn-lg" onclick="${Auth.isLoggedIn ? "navigate('bikes')" : "openModal('register')"}">
          🚲 Find a bike
        </button>
        <button class="btn btn-outline btn-lg" onclick="${Auth.isLoggedIn ? "navigate('delivery')" : "openModal('register')"}">
          💰 Earn by delivering
        </button>
      </div>
    </section>

    <div class="stats-bar">
      <div class="stats-grid">
        <div class="stat-item"><div class="stat-value">2,400+</div><div class="stat-label">Bikes listed</div></div>
        <div class="stat-item"><div class="stat-value">180+</div><div class="stat-label">Cities</div></div>
        <div class="stat-item"><div class="stat-value">€640K</div><div class="stat-label">Earned by users</div></div>
        <div class="stat-item"><div class="stat-value">18t</div><div class="stat-label">CO₂ saved</div></div>
      </div>
    </div>

    <section class="section" style="background:var(--surface)">
      <div class="container">
        <div class="section-header">
          <div class="section-eyebrow">How it works</div>
          <div class="section-title">Three ways to use PedalShare</div>
        </div>
        <div class="hiw-grid">
          <div class="hiw-card">
            <div class="hiw-icon">🚲</div>
            <h3>Rent a bike</h3>
            <p>Find a nearby bike, unlock it in the app, and ride. Pay by the hour or day. No subscription needed.</p>
          </div>
          <div class="hiw-card">
            <div class="hiw-icon">📦</div>
            <h3>Move bikes, earn credits</h3>
            <p>Owners need bikes moved to new locations. Pick up a job, deliver the bike, and collect reward points.</p>
          </div>
          <div class="hiw-card">
            <div class="hiw-icon">💳</div>
            <h3>Spend your credits</h3>
            <p>Redeem points for free rides, partner discounts at cafés, gear shops, and more.</p>
          </div>
          <div class="hiw-card">
            <div class="hiw-icon">🏷️</div>
            <h3>List your bike</h3>
            <p>Earn passive income by listing your bike for rent when you're not using it. Set your own price.</p>
          </div>
        </div>
      </div>
    </section>

    <section class="section">
      <div class="container" style="text-align:center">
        <div class="section-title">Ready to ride?</div>
        <p style="color:var(--text-2);margin:12px 0 28px">Join thousands of urban cyclists already earning on PedalShare.</p>
        <button class="btn btn-primary btn-lg" onclick="openModal('register')">Get started — it's free</button>
      </div>
    </section>`;
});

// ── Browse Bikes ───────────────────────────────────────────────────────────
addRoute('bikes', async (app) => {
  if (!Auth.isLoggedIn) { navigate(''); return; }

  app.innerHTML = `
    <div class="container section">
      <div class="flex items-center justify-between" style="margin-bottom:24px">
        <div>
          <h1 style="font-size:24px;font-weight:800">Browse Bikes</h1>
          <p style="color:var(--text-3);font-size:14px;margin-top:4px">Find a bike near you</p>
        </div>
        <button class="btn btn-primary" onclick="navigate('list-bike')">+ List my bike</button>
      </div>
      <div class="filters-row">
        <select class="filter-select" id="filter-type">
          <option value="">All types</option>
          <option value="city">City</option>
          <option value="road">Road</option>
          <option value="mountain">Mountain</option>
          <option value="electric">Electric</option>
          <option value="cargo">Cargo</option>
          <option value="folding">Folding</option>
        </select>
        <input class="form-input" id="filter-radius" type="number" placeholder="Radius (km)" value="10" style="flex:0.5;min-width:120px">
        <input class="form-input" id="filter-max-price" type="number" placeholder="Max €/hr" style="flex:0.5;min-width:120px">
        <button class="btn btn-primary" id="search-btn">Search</button>
      </div>
      <div id="bikes-container"><div class="loading-center"><div class="spinner"></div></div></div>
    </div>`;

  const renderBikes = async () => {
    const cont = document.getElementById('bikes-container');
    cont.innerHTML = `<div class="loading-center"><div class="spinner"></div></div>`;
    try {
      const bikes = await API.searchBikes({
        user_lat: 52.52, user_lon: 13.405,  // default: Berlin
        radius_km: parseFloat(document.getElementById('filter-radius').value) || 10,
        type: document.getElementById('filter-type').value || undefined,
        max_hourly_price: parseFloat(document.getElementById('filter-max-price').value) || undefined,
      });
      if (!bikes.length) {
        cont.innerHTML = `<div class="empty-state"><div class="icon">🚲</div>
          <h3>No bikes found</h3><p>Try expanding your search radius.</p></div>`;
        return;
      }
      cont.innerHTML = `<div class="bikes-grid">${bikes.map(bikeCard).join('')}</div>`;
    } catch(e) { cont.innerHTML = `<p style="color:var(--danger)">${e.message}</p>`; }
  };

  document.getElementById('search-btn').onclick = renderBikes;
  await renderBikes();
});

function bikeCard(b) {
  return `
    <div class="card bike-card" onclick="navigate('bike/${b.id}')">
      <div class="bike-photo">${b.photo_urls?.[0] ? `<img src="${b.photo_urls[0]}" alt="${b.title}" style="width:100%;height:100%;object-fit:cover">` : '🚲'}</div>
      <div class="card-body">
        <div class="flex justify-between items-center">
          <span class="badge badge-blue">${b.type}</span>
          <span class="stars">${stars(b.avg_rating)}</span>
        </div>
        <div class="card-title" style="margin-top:8px">${b.title}</div>
        <div class="card-subtitle">${b.distance_from_user ? b.distance_from_user.toFixed(1) + ' km away' : ''}</div>
        <div class="divider"></div>
        <div class="flex justify-between items-center">
          <div class="bike-price">€${b.hourly_price}<span>/hr</span></div>
          <div class="bike-price" style="font-size:13px">€${b.daily_price}<span>/day</span></div>
        </div>
      </div>
    </div>`;
}

// ── Bike Detail ───────────────────────────────────────────────────────────
addRoute('bike', async (app, id) => {
  if (!Auth.isLoggedIn) { navigate(''); return; }

  const [bike, reviews] = await Promise.all([API.getBike(id), API.getBikeReviews(id)]);

  const photosHtml = bike.photo_urls?.length
    ? bike.photo_urls.map(u => `<img src="${u}" style="width:100%;height:260px;object-fit:cover;border-radius:var(--r-lg)">`).join('')
    : `<div class="bike-photo" style="height:260px;border-radius:var(--r-lg);font-size:72px">🚲</div>`;

  app.innerHTML = `
    <div class="container section" style="max-width:800px">
      <button class="btn btn-ghost btn-sm" onclick="navigate('bikes')" style="margin-bottom:16px">← Back</button>
      <div style="display:grid;gap:24px;grid-template-columns:1fr 1fr;align-items:start">
        <div>${photosHtml}</div>
        <div>
          <div class="flex gap-2" style="margin-bottom:8px">
            ${statusBadge(bike.status)}
            <span class="badge badge-blue">${bike.type}</span>
          </div>
          <h1 style="font-size:24px;font-weight:800;margin-bottom:4px">${bike.title}</h1>
          <div class="stars" style="font-size:18px">${stars(bike.avg_rating)}</div>
          <p style="color:var(--text-2);margin:12px 0;line-height:1.6">${bike.description || 'No description provided.'}</p>
          ${bike.brand ? `<div class="flex gap-2" style="margin-bottom:8px"><span style="font-size:13px;color:var(--text-3)">Brand:</span><span style="font-size:13px;font-weight:600">${bike.brand}</span></div>` : ''}
          ${bike.frame_size ? `<div class="flex gap-2" style="margin-bottom:12px"><span style="font-size:13px;color:var(--text-3)">Frame:</span><span style="font-size:13px;font-weight:600">${bike.frame_size}</span></div>` : ''}
          <div class="card" style="padding:16px;margin:16px 0">
            <div class="flex justify-between" style="margin-bottom:8px">
              <span style="color:var(--text-3);font-size:13px">Hourly</span>
              <span class="bike-price">€${bike.hourly_price}<span>/hr</span></span>
            </div>
            <div class="flex justify-between" style="margin-bottom:8px">
              <span style="color:var(--text-3);font-size:13px">Daily</span>
              <span class="bike-price">€${bike.daily_price}<span>/day</span></span>
            </div>
            <div class="flex justify-between">
              <span style="color:var(--text-3);font-size:13px">Deposit</span>
              <span style="font-weight:600">€${bike.deposit}</span>
            </div>
          </div>
          ${bike.status === 'available'
            ? `<button class="btn btn-primary btn-block btn-lg" id="book-btn">Book this bike</button>`
            : `<button class="btn btn-outline btn-block btn-lg" disabled>Not available</button>`}
        </div>
      </div>

      <div style="margin-top:40px">
        <h2 style="font-size:18px;font-weight:700;margin-bottom:16px">Reviews (${reviews.length})</h2>
        ${reviews.length
          ? reviews.map(r => `
            <div class="card" style="padding:16px;margin-bottom:12px">
              <div class="flex justify-between items-center">
                <span class="stars">${stars(r.rating)}</span>
                <span style="font-size:12px;color:var(--text-3)">${new Date(r.created_at).toLocaleDateString()}</span>
              </div>
              ${r.comment ? `<p style="font-size:14px;color:var(--text-2);margin-top:8px">${r.comment}</p>` : ''}
            </div>`).join('')
          : `<div class="empty-state" style="padding:32px"><div class="icon">💬</div><p>No reviews yet. Be the first!</p></div>`}
      </div>
    </div>`;

  document.getElementById('book-btn')?.addEventListener('click', async () => {
    try {
      const rental = await API.bookBike({ bike_id: bike.id, pickup_lat: bike.current_lat, pickup_lon: bike.current_lon });
      toast('Bike booked! Go to My Rentals to start your ride.', 'success');
      navigate('profile');
    } catch(e) { toast(e.message, 'error'); }
  });
});

// ── Delivery Jobs ─────────────────────────────────────────────────────────
addRoute('delivery', async (app) => {
  if (!Auth.isLoggedIn) { navigate(''); return; }

  app.innerHTML = `
    <div class="container section">
      <div class="section-header" style="text-align:left;margin-bottom:16px">
        <h1 style="font-size:24px;font-weight:800">Delivery Jobs</h1>
        <p style="color:var(--text-3);font-size:14px;margin-top:4px">Move bikes, earn points. Relay deliveries supported.</p>
      </div>
      <div id="jobs-container"><div class="loading-center"><div class="spinner"></div></div></div>
    </div>`;

  try {
    const jobs = await API.listOpenJobs();
    const cont = document.getElementById('jobs-container');
    if (!jobs.length) {
      cont.innerHTML = `<div class="empty-state"><div class="icon">📦</div>
        <h3>No open jobs</h3><p>Check back soon — new jobs are posted daily.</p></div>`;
      return;
    }
    cont.innerHTML = `<div style="display:grid;gap:16px">${jobs.map(jobCard).join('')}</div>`;
    cont.querySelectorAll('[data-job-accept]').forEach(btn => {
      btn.addEventListener('click', async () => {
        const jobId = btn.dataset.jobAccept;
        try {
          await API.acceptSegment(jobId, { start_lat: 52.52, start_lon: 13.405 });
          toast('Job accepted! Start riding to the pickup point.', 'success');
          navigate('profile');
        } catch(e) { toast(e.message, 'error'); }
      });
    });
  } catch(e) {
    document.getElementById('jobs-container').innerHTML = `<p style="color:var(--danger)">${e.message}</p>`;
  }
});

function jobCard(j) {
  return `
    <div class="card job-card">
      <div class="flex justify-between items-center">
        <div>
          <div class="card-title">Delivery Job #${j.id}</div>
          <div class="card-subtitle">${j.distance_km.toFixed(1)} km route</div>
        </div>
        <div class="job-reward">${j.reward_points} <span>pts</span></div>
      </div>
      <div class="job-route">
        <div class="job-dot job-dot-green"></div>
        <span style="font-size:13px;color:var(--text-2)">(${j.pickup_lat.toFixed(3)}, ${j.pickup_lon.toFixed(3)})</span>
        <div class="job-line"></div>
        <div class="job-dot job-dot-red"></div>
        <span style="font-size:13px;color:var(--text-2)">(${j.dropoff_lat.toFixed(3)}, ${j.dropoff_lon.toFixed(3)})</span>
      </div>
      <div class="flex justify-between items-center" style="margin-top:8px">
        ${statusBadge(j.status)}
        <button class="btn btn-primary btn-sm" data-job-accept="${j.id}">Accept job</button>
      </div>
    </div>`;
}

// ── Rewards Shop ──────────────────────────────────────────────────────────
addRoute('shop', async (app) => {
  if (!Auth.isLoggedIn) { navigate(''); return; }

  const [offers, user] = await Promise.all([API.listOffers(), API.getProfile()]);

  app.innerHTML = `
    <div class="container section">
      <div class="flex justify-between items-center" style="margin-bottom:32px">
        <div>
          <h1 style="font-size:24px;font-weight:800">Rewards Shop</h1>
          <p style="color:var(--text-3);font-size:14px;margin-top:4px">Spend your points on exclusive discounts</p>
        </div>
        <div class="nav-points">🌿 ${user.points_balance} pts available</div>
      </div>
      ${!offers.length
        ? `<div class="empty-state"><div class="icon">🏪</div><h3>No offers yet</h3><p>Partner offers are coming soon!</p></div>`
        : `<div class="offers-grid">${offers.map(o => offerCard(o, user.points_balance)).join('')}</div>`}
    </div>`;

  app.querySelectorAll('[data-redeem]').forEach(btn => {
    btn.addEventListener('click', async () => {
      const offerId = btn.dataset.redeem;
      try {
        const res = await API.redeemOffer(offerId);
        toast(`✅ Redeemed! Code: ${res.discount_code}`, 'success');
        navigate('shop');
      } catch(e) { toast(e.message, 'error'); }
    });
  });
});

function offerCard(o, balance) {
  const canAfford = balance >= o.points_cost;
  return `
    <div class="card offer-card">
      <div class="offer-body">
        <div class="offer-partner">${o.partner_name}</div>
        <div class="offer-title">${o.title}</div>
        <div class="offer-desc">${o.description}</div>
        ${o.quantity !== null ? `<div style="font-size:12px;color:var(--text-3);margin-top:8px">${o.quantity} left</div>` : ''}
      </div>
      <div class="offer-footer">
        <div class="offer-cost">${o.points_cost} <span>pts</span></div>
        <button class="btn btn-primary btn-sm" data-redeem="${o.id}" ${!canAfford ? 'disabled title="Not enough points"' : ''}>
          ${canAfford ? 'Redeem' : 'Need more pts'}
        </button>
      </div>
    </div>`;
}

// ── Profile ──────────────────────────────────────────────────────────────
addRoute('profile', async (app) => {
  if (!Auth.isLoggedIn) { navigate(''); return; }

  const [user, gamification, rentals, deliveries, ledger] = await Promise.all([
    API.getProfile(), API.getGamification(), API.getMyRentals(),
    API.getMyDeliveries(), API.getPointLedger(),
  ]);

  const xpNext = Math.pow(gamification.level + 1, 1 / 0.45);
  const xpPct = Math.min(100, Math.round((gamification.xp / xpNext) * 100));

  app.innerHTML = `
    <div class="profile-header">
      <div class="container">
        <div class="flex items-center gap-4" style="margin-bottom:24px">
          <div class="avatar">${user.name[0].toUpperCase()}</div>
          <div style="flex:1">
            <div style="font-size:20px;font-weight:800">${user.name}</div>
            <div style="font-size:13px;color:var(--text-3)">${user.email}</div>
            ${user.verified
              ? `<span class="badge badge-green" style="margin-top:6px">✓ Verified</span>`
              : `<span class="badge badge-amber" style="margin-top:6px">Pending verification</span>`}
          </div>
        </div>
        <div style="margin-bottom:4px;font-size:13px;font-weight:600;color:var(--text-2)">
          Level ${gamification.level} · ${gamification.xp} XP
        </div>
        <div class="xp-bar"><div class="xp-fill" style="width:${xpPct}%"></div></div>
      </div>
    </div>

    <div class="container">
      <div class="stats-cards">
        <div class="stat-card"><div class="stat-card-value" style="color:var(--primary)">🌿 ${user.points_balance}</div><div class="stat-card-label">Points</div></div>
        <div class="stat-card"><div class="stat-card-value">🚲 ${gamification.total_rentals}</div><div class="stat-card-label">Rentals</div></div>
        <div class="stat-card"><div class="stat-card-value">📦 ${gamification.total_deliveries}</div><div class="stat-card-label">Deliveries</div></div>
        <div class="stat-card"><div class="stat-card-value">🛣️ ${gamification.total_km.toFixed(0)}</div><div class="stat-card-label">km ridden</div></div>
        <div class="stat-card"><div class="stat-card-value">🌍 ${gamification.co2_saved_kg.toFixed(1)}</div><div class="stat-card-label">kg CO₂ saved</div></div>
        <div class="stat-card"><div class="stat-card-value">🔥 ${gamification.streak_days}</div><div class="stat-card-label">Day streak</div></div>
      </div>

      <div class="tabs">
        <div class="tab active" data-tab="rentals">Rentals (${rentals.length})</div>
        <div class="tab" data-tab="deliveries">Deliveries (${deliveries.length})</div>
        <div class="tab" data-tab="points">Points (${ledger.length})</div>
      </div>

      <div id="tab-content">
        ${renderRentalsList(rentals)}
      </div>
    </div>`;

  document.querySelectorAll('.tab').forEach(tab => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
      tab.classList.add('active');
      const key = tab.dataset.tab;
      const content = document.getElementById('tab-content');
      if (key === 'rentals') content.innerHTML = renderRentalsList(rentals);
      if (key === 'deliveries') content.innerHTML = renderDeliveriesList(deliveries);
      if (key === 'points') content.innerHTML = renderLedger(ledger);
    });
  });
});

function renderRentalsList(rentals) {
  if (!rentals.length) return `<div class="empty-state"><div class="icon">🚲</div><h3>No rentals yet</h3><p><a href="#bikes" style="color:var(--primary)">Browse bikes</a> to start riding.</p></div>`;
  return rentals.map(r => `
    <div class="card" style="padding:16px;margin-bottom:12px">
      <div class="flex justify-between items-center">
        <div>
          <div class="card-title">Rental #${r.id} — Bike #${r.bike_id}</div>
          <div class="card-subtitle">${r.start_time ? new Date(r.start_time).toLocaleDateString() : 'Booked'}</div>
        </div>
        <div class="flex gap-2 items-center">
          ${r.total_price > 0 ? `<span style="font-weight:700">€${r.total_price.toFixed(2)}</span>` : ''}
          ${statusBadge(r.status)}
        </div>
      </div>
      ${r.status === 'pending' ? `
        <div class="flex gap-2" style="margin-top:12px">
          <button class="btn btn-primary btn-sm" data-start-rental="${r.id}">Start rental</button>
          <button class="btn btn-outline btn-sm" data-cancel-rental="${r.id}">Cancel</button>
        </div>` : ''}
      ${r.status === 'active' ? `
        <button class="btn btn-danger btn-sm" style="margin-top:12px" data-end-rental="${r.id}">Return bike</button>` : ''}
    </div>`).join('');
}

function renderDeliveriesList(deliveries) {
  if (!deliveries.length) return `<div class="empty-state"><div class="icon">📦</div><h3>No deliveries yet</h3><p><a href="#delivery" style="color:var(--primary)">Browse jobs</a> to earn points.</p></div>`;
  return deliveries.map(d => `
    <div class="card" style="padding:16px;margin-bottom:12px">
      <div class="flex justify-between items-center">
        <div>
          <div class="card-title">Segment #${d.id} — Job #${d.job_id}</div>
          <div class="card-subtitle">${d.distance_km.toFixed(2)} km · ${new Date(d.started_at).toLocaleDateString()}</div>
        </div>
        <div class="flex gap-2 items-center">
          <span class="badge badge-green">+${d.earned_points} pts</span>
          ${statusBadge(d.status)}
        </div>
      </div>
      ${d.status === 'active' ? `
        <div class="flex gap-2" style="margin-top:12px">
          <button class="btn btn-primary btn-sm" data-complete-seg="${d.id}" data-relay="false">Complete delivery</button>
          <button class="btn btn-outline btn-sm" data-complete-seg="${d.id}" data-relay="true">Relay (partial drop)</button>
        </div>` : ''}
    </div>`).join('');
}

function renderLedger(ledger) {
  if (!ledger.length) return `<div class="empty-state"><div class="icon">🌿</div><h3>No transactions yet</h3></div>`;
  return `<div class="card" style="padding:0 20px">${ledger.slice().reverse().map(t => `
    <div class="ledger-row">
      <div>
        <div style="font-size:14px;font-weight:500">${t.description}</div>
        <div style="font-size:12px;color:var(--text-3)">${new Date(t.created_at).toLocaleDateString()}</div>
      </div>
      <div class="ledger-amount ${t.amount >= 0 ? 'positive' : 'negative'}">${t.amount >= 0 ? '+' : ''}${t.amount} pts</div>
    </div>`).join('')}</div>`;
}

// ── Leaderboard ───────────────────────────────────────────────────────────
addRoute('leaderboard', async (app) => {
  if (!Auth.isLoggedIn) { navigate(''); return; }
  const board = await API.getLeaderboard();

  app.innerHTML = `
    <div class="container section" style="max-width:700px">
      <h1 style="font-size:24px;font-weight:800;margin-bottom:8px">🏆 Leaderboard</h1>
      <p style="color:var(--text-3);margin-bottom:28px">Top couriers this month</p>
      <div style="display:grid;gap:12px">
        ${board.map(e => `
          <div class="card" style="padding:16px">
            <div class="flex items-center gap-4">
              <div style="font-size:24px;font-weight:800;color:var(--text-3);min-width:32px">${
                e.rank === 1 ? '🥇' : e.rank === 2 ? '🥈' : e.rank === 3 ? '🥉' : e.rank
              }</div>
              <div class="avatar" style="width:40px;height:40px;font-size:16px">${e.name[0]}</div>
              <div style="flex:1">
                <div style="font-weight:700">${e.name}</div>
                <div style="font-size:12px;color:var(--text-3)">Level ${e.level} · ${e.total_deliveries} deliveries</div>
              </div>
              <div style="font-size:18px;font-weight:800;color:var(--primary)">${e.xp} XP</div>
            </div>
          </div>`).join('')}
      </div>
    </div>`;
});

// ── List my bike ─────────────────────────────────────────────────────────
addRoute('list-bike', (app) => {
  if (!Auth.isLoggedIn) { navigate(''); return; }
  app.innerHTML = `
    <div class="container section" style="max-width:560px">
      <button class="btn btn-ghost btn-sm" onclick="navigate('bikes')" style="margin-bottom:16px">← Back</button>
      <h1 style="font-size:24px;font-weight:800;margin-bottom:24px">List your bike</h1>
      <form id="list-bike-form" class="flex flex-col gap-4">
        <div class="form-group">
          <label class="form-label">Title</label>
          <input class="form-input" name="title" placeholder="e.g. Trek FX3 City Bike" required>
        </div>
        <div class="form-group">
          <label class="form-label">Description</label>
          <textarea class="form-input" name="description" rows="3" placeholder="Condition, features, accessories…"></textarea>
        </div>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px">
          <div class="form-group">
            <label class="form-label">Type</label>
            <select class="form-input" name="type">
              <option value="city">City</option><option value="road">Road</option>
              <option value="mountain">Mountain</option><option value="electric">Electric</option>
              <option value="cargo">Cargo</option><option value="folding">Folding</option>
            </select>
          </div>
          <div class="form-group">
            <label class="form-label">Brand</label>
            <input class="form-input" name="brand" placeholder="Trek, Canyon…">
          </div>
          <div class="form-group">
            <label class="form-label">Frame size</label>
            <input class="form-input" name="frame_size" placeholder="M, 52cm…">
          </div>
        </div>
        <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:16px">
          <div class="form-group">
            <label class="form-label">€/hour</label>
            <input class="form-input" name="hourly_price" type="number" step="0.5" min="0" value="3">
          </div>
          <div class="form-group">
            <label class="form-label">€/day</label>
            <input class="form-input" name="daily_price" type="number" step="1" min="0" value="18">
          </div>
          <div class="form-group">
            <label class="form-label">Deposit €</label>
            <input class="form-input" name="deposit" type="number" step="10" min="0" value="50">
          </div>
        </div>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px">
          <div class="form-group">
            <label class="form-label">Latitude</label>
            <input class="form-input" name="current_lat" type="number" step="any" value="52.52" required>
          </div>
          <div class="form-group">
            <label class="form-label">Longitude</label>
            <input class="form-input" name="current_lon" type="number" step="any" value="13.405" required>
          </div>
        </div>
        <button type="submit" class="btn btn-primary btn-block btn-lg">Publish bike</button>
      </form>
    </div>`;

  document.getElementById('list-bike-form').onsubmit = async (e) => {
    e.preventDefault();
    const fd = new FormData(e.target);
    const body = Object.fromEntries(fd.entries());
    ['hourly_price','daily_price','deposit','current_lat','current_lon'].forEach(k => body[k] = parseFloat(body[k]));
    const btn = e.target.querySelector('button[type=submit]');
    btn.disabled = true; btn.textContent = 'Publishing…';
    try {
      await API.createBike(body);
      toast('Bike listed successfully!', 'success');
      navigate('bikes');
    } catch(err) { toast(err.message, 'error'); }
    finally { btn.disabled = false; btn.textContent = 'Publish bike'; }
  };
});

// ── Profile action handlers ─────────────────────────────────────────────
document.addEventListener('click', async (e) => {
  const startId = e.target.dataset.startRental;
  const cancelId = e.target.dataset.cancelRental;
  const endId = e.target.dataset.endRental;
  const segId = e.target.dataset.completeSeg;

  if (startId) {
    try { await API.startRental(startId); toast('Rental started — enjoy your ride!', 'success'); navigate('profile'); }
    catch(err) { toast(err.message, 'error'); }
  }
  if (cancelId) {
    try { await API.cancelRental(cancelId); toast('Rental cancelled', 'info'); navigate('profile'); }
    catch(err) { toast(err.message, 'error'); }
  }
  if (endId) {
    // Use bike's last known position for return coords (simplified)
    try {
      await API.endRental(endId, { return_lat: 52.52, return_lon: 13.405 });
      toast('Bike returned. Thanks for riding!', 'success'); navigate('profile');
    } catch(err) { toast(err.message, 'error'); }
  }
  if (segId) {
    const relay = e.target.dataset.relay === 'true';
    try {
      await API.completeSegment(segId, { end_lat: 52.52, end_lon: 13.405, relay });
      toast(relay ? 'Relay drop complete! Points earned.' : 'Delivery complete! Points earned.', 'success');
      navigate('profile');
    } catch(err) { toast(err.message, 'error'); }
  }
});

// ── Route parsing ─────────────────────────────────────────────────────────
window.navigate = navigate;

window.addEventListener('hashchange', () => {
  const parts = window.location.hash.slice(1).split('/');
  const route = parts[0];
  const param = parts[1];
  const app = document.getElementById('app');
  const handler = routes[route] || routes[''];
  if (!handler) return;
  document.querySelectorAll('.nav-link[data-route]').forEach(el => {
    el.classList.toggle('active', el.dataset.route === route);
  });
  app.innerHTML = `<div class="loading-center"><div class="spinner"></div></div>`;
  handler(app, param).catch(err => {
    app.innerHTML = `<div class="container section"><div class="empty-state">
      <div class="icon">⚠️</div><h3>Error</h3><p>${err.message}</p>
    </div></div>`;
  });
  updateNavAuthState();
});

// ── Init ──────────────────────────────────────────────────────────────────
(async () => {
  await updateNavAuthState();
  const parts = window.location.hash.slice(1).split('/');
  const route = parts[0] || '';
  const param = parts[1];
  const app = document.getElementById('app');
  const handler = routes[route] || routes[''];
  if (handler) await handler(app, param).catch(console.error);
})();
