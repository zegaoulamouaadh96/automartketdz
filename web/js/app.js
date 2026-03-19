// ==================== API Configuration ====================
const API_BASE = 'http://5.135.79.223:3001/api';
const API_URL = API_BASE; // compatibility alias
const UPLOAD_BASE = 'http://5.135.79.223:3001/uploads';

// ==================== State Management ====================
const state = {
  user: null,
  token: localStorage.getItem('token'),
  cart: JSON.parse(localStorage.getItem('cart') || '[]'),
  categories: [],
  brands: [],
};

// ==================== API Helper ====================
async function api(endpoint, options = {}) {
  const url = `${API_BASE}${endpoint}`;
  const config = {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  };

  if (state.token) {
    config.headers['Authorization'] = `Bearer ${state.token}`;
  }

  if (options.body && typeof options.body === 'object' && !(options.body instanceof FormData)) {
    config.body = JSON.stringify(options.body);
  }

  if (options.body instanceof FormData) {
    delete config.headers['Content-Type'];
  }

  try {
    const response = await fetch(url, config);
    const data = await response.json();
    if (!response.ok) {
      throw new Error(data.error || 'Request failed');
    }
    return data;
  } catch (error) {
    console.error('API Error:', error);
    throw error;
  }
}

// ==================== Auth Functions ====================
async function login(email, password) {
  const data = await api('/auth/login', {
    method: 'POST',
    body: { email, password },
  });
  state.user = data.user;
  state.token = data.token;
  localStorage.setItem('token', data.token);
  localStorage.setItem('user', JSON.stringify(data.user));
  updateAuthUI();
  return data;
}

async function register(formData) {
  const data = await api('/auth/register', {
    method: 'POST',
    body: formData,
  });
  state.user = data.user;
  state.token = data.token;
  localStorage.setItem('token', data.token);
  localStorage.setItem('user', JSON.stringify(data.user));
  updateAuthUI();
  return data;
}

function logout() {
  state.user = null;
  state.token = null;
  localStorage.removeItem('token');
  localStorage.removeItem('user');
  updateAuthUI();
  showToast('Logged out successfully', 'success');
  setTimeout(() => window.location.href = 'index.html', 500);
}

function checkAuth() {
  const user = localStorage.getItem('user');
  if (user && state.token) {
    state.user = JSON.parse(user);
    updateAuthUI();
  }
}

function updateAuthUI() {
  const authLinks = document.getElementById('auth-links');
  if (!authLinks) return;

  if (state.user) {
    authLinks.innerHTML = `
      <a href="pages/orders.html">📦 My Orders</a>
      <a href="pages/cart.html">🛒 Cart <span class="cart-badge" id="cart-count">${state.cart.length}</span></a>
      <div class="user-menu">
        <button onclick="toggleUserMenu()">${state.user.first_name} ▾</button>
        <div class="user-dropdown" id="user-dropdown" style="display:none;position:absolute;right:0;top:100%;background:#fff;box-shadow:0 4px 12px rgba(0,0,0,0.15);border-radius:8px;padding:8px 0;min-width:180px;z-index:100;">
          <a href="pages/profile.html" style="display:block;padding:10px 16px;">👤 Profile</a>
          ${state.user.role === 'seller' ? '<a href="../seller-dashboard/index.html" style="display:block;padding:10px 16px;">🏪 My Store</a>' : ''}
          ${state.user.role === 'admin' ? '<a href="../admin-dashboard/index.html" style="display:block;padding:10px 16px;">⚙️ Admin Panel</a>' : ''}
          <a href="#" onclick="logout()" style="display:block;padding:10px 16px;color:#EF4444;">🚪 Logout</a>
        </div>
      </div>
    `;
  } else {
    authLinks.innerHTML = `
      <a href="pages/login.html" class="btn-outline">Login</a>
      <a href="pages/register.html" class="btn-primary">Register</a>
    `;
  }
}

function toggleUserMenu() {
  const dropdown = document.getElementById('user-dropdown');
  if (dropdown) {
    dropdown.style.display = dropdown.style.display === 'none' ? 'block' : 'none';
  }
}

// ==================== Cart Functions ====================
function addToCart(product) {
  const existing = state.cart.find(item => item.id === product.id);
  if (existing) {
    existing.quantity += 1;
  } else {
    state.cart.push({ ...product, quantity: 1 });
  }
  saveCart();
  showToast('Product added to cart!', 'success');
}

function removeFromCart(productId) {
  state.cart = state.cart.filter(item => item.id !== productId);
  saveCart();
}

function updateCartQuantity(productId, quantity) {
  const item = state.cart.find(i => i.id === productId);
  if (item) {
    item.quantity = Math.max(1, parseInt(quantity));
    saveCart();
  }
}

function getCartTotal() {
  return state.cart.reduce((sum, item) => sum + (item.price * item.quantity), 0);
}

function saveCart() {
  localStorage.setItem('cart', JSON.stringify(state.cart));
  const countEl = document.getElementById('cart-count');
  if (countEl) countEl.textContent = state.cart.length;
}

function getCart() {
  return JSON.parse(localStorage.getItem('cart') || '[]');
}

// ==================== Product Functions ====================
async function loadProducts(params = {}) {
  const query = new URLSearchParams(params).toString();
  return await api(`/products?${query}`);
}

async function loadProduct(id) {
  return await api(`/products/${id}`);
}

async function searchProducts(query, params = {}) {
  const searchParams = new URLSearchParams({ q: query, ...params }).toString();
  return await api(`/products/search?${searchParams}`);
}

// ==================== Category Functions ====================
async function loadCategories() {
  const data = await api('/categories');
  state.categories = data.categories;
  return data.categories;
}

// ==================== Vehicle Functions ====================
async function loadBrands(vehicleType = '') {
  const query = vehicleType ? `?vehicle_type=${vehicleType}` : '';
  const data = await api(`/vehicle-brands${query}`);
  state.brands = data.brands;
  return data.brands;
}

async function loadModels(brandId) {
  const data = await api(`/vehicle-brands/${brandId}/models`);
  return data.models;
}

// ==================== Review Functions ====================
async function submitReview(productId, rating, comment) {
  return await api(`/reviews/products/${productId}`, {
    method: 'POST',
    body: { rating, comment },
  });
}

// ==================== Toast Notification ====================
function showToast(message, type = 'info') {
  let container = document.querySelector('.toast-container');
  if (!container) {
    container = document.createElement('div');
    container.className = 'toast-container';
    document.body.appendChild(container);
  }

  const icons = { success: '✅', danger: '❌', warning: '⚠️', info: 'ℹ️' };
  const toast = document.createElement('div');
  toast.className = 'toast';
  toast.innerHTML = `<span>${icons[type] || icons.info}</span><span>${message}</span>`;
  container.appendChild(toast);

  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateX(100%)';
    setTimeout(() => toast.remove(), 300);
  }, 3000);
}

// ==================== Utility Functions ====================
function formatPrice(price) {
  return new Intl.NumberFormat('fr-DZ', { style: 'decimal' }).format(price) + ' DA';
}

function formatDate(date) {
  return new Date(date).toLocaleDateString('fr-FR', {
    year: 'numeric', month: 'long', day: 'numeric',
  });
}

function renderStars(rating) {
  const full = Math.floor(rating);
  const half = rating % 1 >= 0.5 ? 1 : 0;
  const empty = 5 - full - half;
  return '★'.repeat(full) + (half ? '½' : '') + '☆'.repeat(empty);
}

function debounce(func, wait) {
  let timeout;
  return function (...args) {
    clearTimeout(timeout);
    timeout = setTimeout(() => func.apply(this, args), wait);
  };
}

// ==================== Initialize ====================
document.addEventListener('DOMContentLoaded', () => {
  checkAuth();
});
