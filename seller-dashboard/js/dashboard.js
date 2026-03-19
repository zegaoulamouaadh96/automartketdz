const API_URL = 'http://5.135.79.223:3001/api';

function getToken() { return localStorage.getItem('token'); }
function getUser() { return JSON.parse(localStorage.getItem('user') || '{}'); }

function checkAuth() {
  const token = getToken();
  const user = getUser();
  if (!token || !user.id) {
    window.location.href = '/pages/login.html';
    return false;
  }
  if (user.role !== 'seller' && user.role !== 'admin') {
    alert('Access denied. Seller account required.');
    window.location.href = '/';
    return false;
  }
  return true;
}

async function apiRequest(endpoint, options = {}) {
  const token = getToken();
  const defaultHeaders = { 'Authorization': `Bearer ${token}` };
  if (!(options.body instanceof FormData)) {
    defaultHeaders['Content-Type'] = 'application/json';
  }
  const res = await fetch(`${API_URL}${endpoint}`, {
    ...options,
    headers: { ...defaultHeaders, ...options.headers },
  });
  const data = await res.json();
  if (res.status === 401) {
    localStorage.clear();
    window.location.href = '/pages/login.html';
    return null;
  }
  return { ok: res.ok, status: res.status, data };
}

function formatPrice(price) {
  return new Intl.NumberFormat('fr-DZ').format(price) + ' DA';
}

function formatDate(date) {
  return new Date(date).toLocaleDateString('fr-FR', {
    year: 'numeric', month: 'short', day: 'numeric'
  });
}

function showNotification(message, type = 'success') {
  const notif = document.createElement('div');
  notif.className = `notification notification-${type}`;
  notif.textContent = message;
  notif.style.cssText = `position:fixed;top:20px;right:20px;padding:12px 24px;border-radius:8px;color:white;z-index:9999;font-size:14px;
    background:${type === 'success' ? '#10B981' : type === 'danger' ? '#EF4444' : '#F59E0B'};`;
  document.body.appendChild(notif);
  setTimeout(() => notif.remove(), 3000);
}

function renderSidebar(activePage) {
  const user = getUser();
  return `
    <div class="sidebar-header">
      <h2>🔧 AutoMarket DZ</h2>
      <p>Seller Dashboard</p>
    </div>
    <nav class="sidebar-nav">
      <div class="sidebar-section">Main</div>
      <a href="/seller-dashboard/index.html" class="${activePage === 'dashboard' ? 'active' : ''}">
        <span class="icon">📊</span> Dashboard
      </a>
      <div class="sidebar-section">Manage</div>
      <a href="/seller-dashboard/pages/products.html" class="${activePage === 'products' ? 'active' : ''}">
        <span class="icon">📦</span> Products
      </a>
      <a href="/seller-dashboard/pages/orders.html" class="${activePage === 'orders' ? 'active' : ''}">
        <span class="icon">🛒</span> Orders
      </a>
      <a href="/seller-dashboard/pages/messages.html" class="${activePage === 'messages' ? 'active' : ''}">
        <span class="icon">💬</span> Messages
      </a>
      <div class="sidebar-section">Settings</div>
      <a href="/seller-dashboard/pages/store-settings.html" class="${activePage === 'store' ? 'active' : ''}">
        <span class="icon">🏪</span> Store Settings
      </a>
      <a href="/">
        <span class="icon">🌐</span> View Website
      </a>
      <a href="#" onclick="logout()">
        <span class="icon">🚪</span> Logout
      </a>
    </nav>
  `;
}


function logout() {
  localStorage.clear();
  window.location.href = '/';
}
