const API_URL = 'http://5.135.79.223:3001/api';
const UPLOAD_URL = 'http://5.135.79.223:3001/uploads';

// ===================== AUTH =====================
function getLoginUrl() {
    return '/pages/login.html';
}

function getBasePath() {
    return window.location.pathname.includes('/pages/') ? '..' : '.';
}

function checkAuth() {
    const token = localStorage.getItem('token');
    const user = JSON.parse(localStorage.getItem('user') || '{}');
    if (!token || !['admin', 'founder', 'employee'].includes(user.role)) {
        window.location.href = getLoginUrl();
        return null;
    }
    return { token, user };
}

// ===================== API =====================
async function apiRequest(endpoint, options = {}) {
    const token = localStorage.getItem('token');
    const headers = { ...options.headers };
    if (token) headers['Authorization'] = `Bearer ${token}`;
    if (!(options.body instanceof FormData)) headers['Content-Type'] = 'application/json';
    try {
        const res = await fetch(`${API_URL}${endpoint}`, { ...options, headers });
        if (res.status === 401) {
            localStorage.removeItem('token');
            localStorage.removeItem('user');
            window.location.href = getLoginUrl();
            return;
        }
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || data.message || 'خطأ في الخادم');
        return data;
    } catch (err) {
        if (err.message === 'Failed to fetch') throw new Error('لا يمكن الاتصال بالخادم');
        throw err;
    }
}

// ===================== FORMATTERS =====================
function formatPrice(price) {
    return new Intl.NumberFormat('ar-DZ', { style: 'currency', currency: 'DZD', minimumFractionDigits: 0 }).format(price || 0);
}

function formatDate(dateStr) {
    if (!dateStr) return '-';
    return new Date(dateStr).toLocaleDateString('ar-DZ', { year: 'numeric', month: 'short', day: 'numeric' });
}

function formatDateTime(dateStr) {
    if (!dateStr) return '-';
    return new Date(dateStr).toLocaleString('ar-DZ', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
}

function formatNumber(n) {
    if (n >= 1000000) return (n / 1000000).toFixed(1) + 'M';
    if (n >= 1000) return (n / 1000).toFixed(1) + 'K';
    return String(n || 0);
}

function timeAgo(dateStr) {
    if (!dateStr) return '-';
    const diff = Date.now() - new Date(dateStr).getTime();
    const mins = Math.floor(diff / 60000);
    if (mins < 1) return 'الآن';
    if (mins < 60) return `منذ ${mins} دقيقة`;
    const hours = Math.floor(mins / 60);
    if (hours < 24) return `منذ ${hours} ساعة`;
    const days = Math.floor(hours / 24);
    if (days < 7) return `منذ ${days} يوم`;
    return formatDate(dateStr);
}

// ===================== UI UTILITIES =====================
function showNotification(message, type = 'success') {
    const existing = document.querySelectorAll('.toast-notification');
    existing.forEach((el, i) => { el.style.top = `${20 + (i + 1) * 60}px`; });
    const n = document.createElement('div');
    n.className = `toast-notification ${type}`;
    n.innerHTML = `<span>${type === 'success' ? '✓' : type === 'error' ? '✕' : '⚠'}</span> ${message}`;
    document.body.appendChild(n);
    setTimeout(() => { n.style.opacity = '0'; n.style.transform = 'translateX(-30px)'; setTimeout(() => n.remove(), 300); }, 3500);
}

function showLoading(containerId) {
    const el = document.getElementById(containerId);
    if (el) el.innerHTML = '<div class="loading-spinner"></div>';
}

function showEmpty(containerId, icon = '📭', title = 'لا توجد بيانات', text = '') {
    const el = document.getElementById(containerId);
    if (el) el.innerHTML = `<tr><td colspan="20"><div class="empty-state"><div class="empty-icon">${icon}</div><h4>${title}</h4>${text ? `<p>${text}</p>` : ''}</div></td></tr>`;
}

function confirmAction(message) {
    return confirm(message);
}

// ===================== SIDEBAR =====================
function renderSidebar(activePage) {
    const base = getBasePath();
    const user = JSON.parse(localStorage.getItem('user') || '{}');
    const isFounder = user.role === 'founder';
    const links = [
        { href: `${base}/index.html`, icon: '📊', label: 'لوحة القيادة', id: 'dashboard' },
        { section: 'إدارة المحتوى' },
        { href: `${base}/pages/users.html`, icon: '👥', label: 'المستخدمين', id: 'users' },
        { href: `${base}/pages/stores.html`, icon: '🏪', label: 'المتاجر', id: 'stores' },
        { href: `${base}/pages/products.html`, icon: '📦', label: 'المنتجات', id: 'products' },
        { href: `${base}/pages/categories.html`, icon: '📂', label: 'الأصناف', id: 'categories' },
        { section: 'المراقبة' },
        { href: `${base}/pages/orders.html`, icon: '🛒', label: 'الطلبات', id: 'orders' },
        { href: `${base}/pages/reports.html`, icon: '⚠️', label: 'البلاغات', id: 'reports' },
        { href: `${base}/pages/notifications.html`, icon: '🔔', label: 'الإشعارات', id: 'notifications' },
        { section: 'النظام' },
        { href: `${base}/pages/settings.html`, icon: '⚙️', label: 'الإعدادات', id: 'settings' },
    ];

    // Staff management (founder only)
    if (isFounder) {
        links.push({ href: `${base}/pages/staff.html`, icon: '🛡️', label: 'إدارة الموظفين', id: 'staff' });
    }

    // Fix href for dashboard (index.html is at root, pages are in pages/)
    if (base === '.') {
        links[0].href = './index.html';
    } else {
        links[0].href = '../index.html';
    }

    let html = `
        <div class="sidebar-header">
            <h2>🔧 AutoMarket DZ</h2>
            <p>لوحة الإدارة</p>
        </div>
        <nav class="sidebar-nav">`;

    links.forEach(l => {
        if (l.section) {
            html += `<div class="sidebar-section">${l.section}</div>`;
        } else {
            html += `<a href="${l.href}" class="${l.id === activePage ? 'active' : ''}"><span class="icon">${l.icon}</span>${l.label}</a>`;
        }
    });

    html += `
        <div class="sidebar-section">الحساب</div>
        <a href="#" onclick="logout(); return false;"><span class="icon">🚪</span>تسجيل الخروج</a>
        </nav>
        <div style="padding:16px 20px;border-top:1px solid rgba(255,255,255,0.06);margin-top:auto;">
            <div style="font-size:11px;color:#475569;">v2.0 — ${new Date().getFullYear()}</div>
        </div>`;

    const sidebar = document.querySelector('.sidebar');
    if (sidebar) sidebar.innerHTML = html;
}

function logout() {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    window.location.href = getLoginUrl();
}

// ===================== STATUS BADGES =====================
function getStatusBadge(status) {
    const map = {
        pending: ['بانتظار', 'badge-warning'],
        confirmed: ['مؤكد', 'badge-info'],
        processing: ['قيد التحضير', 'badge-primary'],
        shipped: ['تم الشحن', 'badge-info'],
        delivered: ['تم التوصيل', 'badge-success'],
        cancelled: ['ملغي', 'badge-danger'],
        refunded: ['مسترجع', 'badge-danger'],
        active: ['نشط', 'badge-success'],
        inactive: ['غير نشط', 'badge-gray'],
        banned: ['محظور', 'badge-danger'],
        approved: ['موافق', 'badge-success'],
        rejected: ['مرفوض', 'badge-danger'],
        reviewing: ['قيد المراجعة', 'badge-info'],
        resolved: ['تم الحل', 'badge-success'],
        dismissed: ['مرفوض', 'badge-gray'],
    };
    const [label, cls] = map[status] || [status, 'badge-gray'];
    return `<span class="badge ${cls}">${label}</span>`;
}

function getRoleBadge(role) {
    const map = {
        founder: ['المؤسس', 'badge-danger'],
        admin: ['مدير', 'badge-danger'],
        employee: ['موظف', 'badge-warning'],
        seller: ['بائع', 'badge-primary'],
        buyer: ['مشتري', 'badge-info'],
        supplier: ['مورد', 'badge-purple'],
    };
    const [label, cls] = map[role] || [role, 'badge-gray'];
    return `<span class="badge ${cls}">${label}</span>`;
}

// ===================== PAGINATION =====================
function renderPagination(containerId, pagination, loadFn) {
    const el = document.getElementById(containerId);
    if (!el || !pagination || pagination.totalPages <= 1) { if (el) el.innerHTML = ''; return; }

    let html = '<div class="pagination">';
    html += `<button ${pagination.page <= 1 ? 'disabled' : ''} onclick="${loadFn}(${pagination.page - 1})">« السابق</button>`;

    const start = Math.max(1, pagination.page - 2);
    const end = Math.min(pagination.totalPages, pagination.page + 2);

    if (start > 1) { html += `<button onclick="${loadFn}(1)">1</button>`; if (start > 2) html += `<button disabled>...</button>`; }
    for (let i = start; i <= end; i++) {
        html += `<button class="${i === pagination.page ? 'active' : ''}" onclick="${loadFn}(${i})">${i}</button>`;
    }
    if (end < pagination.totalPages) { if (end < pagination.totalPages - 1) html += `<button disabled>...</button>`; html += `<button onclick="${loadFn}(${pagination.totalPages})">${pagination.totalPages}</button>`; }

    html += `<button ${pagination.page >= pagination.totalPages ? 'disabled' : ''} onclick="${loadFn}(${pagination.page + 1})">التالي »</button>`;
    html += '</div>';
    el.innerHTML = html;
}

// ===================== IMAGE HELPER =====================
function getImageUrl(path) {
    if (!path) return '';
    if (path.startsWith('http')) return path;
    return `${UPLOAD_URL}/${path}`;
}

// ===================== MOBILE MENU =====================
function initMobileMenu() {
    if (window.innerWidth <= 768) {
        const topbar = document.querySelector('.topbar');
        if (topbar && !topbar.querySelector('.menu-toggle')) {
            const btn = document.createElement('button');
            btn.className = 'btn btn-ghost menu-toggle';
            btn.innerHTML = '☰';
            btn.onclick = () => document.querySelector('.sidebar')?.classList.toggle('open');
            topbar.prepend(btn);
        }
    }
}
document.addEventListener('DOMContentLoaded', initMobileMenu);
