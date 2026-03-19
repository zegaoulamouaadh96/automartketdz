const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const path = require('path');
const fs = require('fs');

const config = require('./config');
const errorHandler = require('./middleware/errorHandler');
const setupSocket = require('./services/socketService');

// Route imports
const authRoutes = require('./routes/auth');
const storeRoutes = require('./routes/stores');
const productRoutes = require('./routes/products');
const orderRoutes = require('./routes/orders');
const reviewRoutes = require('./routes/reviews');
const chatRoutes = require('./routes/chat');
const adminRoutes = require('./routes/admin');
const generalRoutes = require('./routes/general');

const app = express();
const server = http.createServer(app);

const configuredOrigins = config.cors.origin === '*'
  ? '*'
  : config.cors.origin
      .split(',')
      .map((origin) => origin.trim())
      .filter(Boolean);

const isAllowedOrigin = (origin) => {
  if (configuredOrigins === '*') {
    return true;
  }

  if (!origin) {
    return true;
  }

  if (origin === 'null' && config.nodeEnv !== 'production') {
    return true;
  }

  if (config.nodeEnv !== 'production') {
    try {
      const parsedOrigin = new URL(origin);
      if (parsedOrigin.hostname === 'localhost' || parsedOrigin.hostname === '127.0.0.1') {
        return true;
      }
    } catch (error) {
      // Ignore invalid origin format and continue with explicit checks.
    }
  }

  return configuredOrigins.includes(origin);
};

const corsOriginHandler = (origin, callback) => {
  if (isAllowedOrigin(origin)) {
    return callback(null, true);
  }

  return callback(new Error('Not allowed by CORS'));
};

// Socket.io setup
const io = new Server(server, {
  cors: {
    origin: corsOriginHandler,
    methods: ['GET', 'POST'],
    credentials: true,
  },
});

setupSocket(io);

// Make io accessible in routes
app.set('io', io);

// ==================== MIDDLEWARE ====================

app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' },
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      scriptSrcAttr: ["'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "blob:", "http:", "https:"],
      connectSrc: ["'self'", "ws:", "wss:"],
      fontSrc: ["'self'", "data:"],
    },
  },
}));

app.use(cors({
  origin: corsOriginHandler,
  credentials: true,
}));

app.use(morgan('dev'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Rate limiting
const apiLimiter = rateLimit({
  windowMs: config.rateLimit.windowMs,
  max:
    config.nodeEnv === 'production'
      ? config.rateLimit.max
      : Math.max(config.rateLimit.max, 600),
  message: { error: 'Too many requests, please try again later' },
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req) =>
    req.path === '/health' ||
    req.path.startsWith('/auth/login') ||
    req.path.startsWith('/auth/register'),
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: config.nodeEnv === 'production' ? 20 : 200,
  message: { error: 'Too many login attempts, please try again later' },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/', apiLimiter);
app.use('/api/auth/login', authLimiter);
app.use('/api/auth/register', authLimiter);

// Static files - MUST be before API routes
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

// Try multiple possible locations for web assets
const assetPaths = {
  web: [
    path.join(__dirname, '..', '..', 'web'),
    path.join(__dirname, '..', 'web'),
    '/app/web',
  ],
  seller: [
    path.join(__dirname, '..', '..', 'seller-dashboard'),
    path.join(__dirname, '..', 'seller-dashboard'),
    '/app/seller-dashboard',
  ],
  admin: [
    path.join(__dirname, '..', '..', 'admin-dashboard'),
    path.join(__dirname, '..', 'admin-dashboard'),
    '/app/admin-dashboard',
  ],
};

const findDir = (paths) => {
  for (const p of paths) {
    if (fs.existsSync(p)) {
      console.log(`✓ Found: ${p}`);
      return p;
    }
  }
  console.warn(`✗ Not found: ${paths.join(', ')}`);
  return null;
};

const webDir = findDir(assetPaths.web);
const webIndexFile = webDir ? path.join(webDir, 'index.html') : null;
const sellerDashboardDir = findDir(assetPaths.seller);
const adminDashboardDir = findDir(assetPaths.admin);

// Serve static files from web root (css, js, assets)
if (webDir) {
  app.use(express.static(webDir, { 
    maxAge: '1h',
    etag: false 
  }));
  console.log(`📁 Serving web assets from: ${webDir}`);
}

if (sellerDashboardDir) {
  app.use('/seller-dashboard', express.static(sellerDashboardDir));
  console.log(`📁 Serving seller dashboard from: ${sellerDashboardDir}`);
}

if (adminDashboardDir) {
  app.use('/admin-dashboard', express.static(adminDashboardDir));
  console.log(`📁 Serving admin dashboard from: ${adminDashboardDir}`);
}

app.get('/', (req, res) => {
  if (webIndexFile && fs.existsSync(webIndexFile)) {
    return res.sendFile(webIndexFile);
  }

  return res.json({
    message: 'AutoMarket DZ API is running',
    api: '/api',
    health: '/api/health',
  });
});

// ==================== MAINTENANCE MODE MIDDLEWARE ====================
const db = require('./config/database');

// Cache settings for 30 seconds to avoid DB hit on every request
let settingsCache = {};
let settingsCacheTime = 0;
const SETTINGS_CACHE_TTL = 30000;

async function getAppSettings() {
  const now = Date.now();
  if (now - settingsCacheTime < SETTINGS_CACHE_TTL) return settingsCache;
  try {
    const result = await db.query('SELECT key, value FROM app_settings');
    const settings = {};
    result.rows.forEach(r => {
      try { settings[r.key] = JSON.parse(r.value); } catch { settings[r.key] = r.value; }
    });
    settingsCache = settings;
    settingsCacheTime = now;
    return settings;
  } catch {
    return settingsCache;
  }
}

// Make settings available to all requests
app.use(async (req, res, next) => {
  try {
    req.appSettings = await getAppSettings();
  } catch {
    req.appSettings = {};
  }
  next();
});

// Maintenance mode check (skip for admin routes, health, settings, and login)
app.use('/api', (req, res, next) => {
  const skipPaths = ['/health', '/admin', '/auth/login', '/app-settings', '/announcements'];
  if (skipPaths.some(p => req.path.startsWith(p))) return next();
  if (req.appSettings && (req.appSettings.maintenance_mode === true || req.appSettings.maintenance_mode === 'true')) {
    return res.status(503).json({
      error: 'الموقع في وضع الصيانة حالياً. يرجى المحاولة لاحقاً.',
      maintenance: true,
    });
  }
  next();
});

// ==================== API ROUTES ====================

app.use('/api/auth', authRoutes);
app.use('/api/stores', storeRoutes);
app.use('/api/products', productRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/reviews', reviewRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api', generalRoutes);

// Health check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'OK',
    name: 'AutoMarket DZ API',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
  });
});

// 404 handler
app.use('/api/*', (req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Error handler
app.use(errorHandler);

// ==================== START SERVER ====================

const PORT = config.port;
server.listen(PORT, () => {
  console.log(`
  ╔══════════════════════════════════════════╗
  ║      🚗 AutoMarket DZ API Server 🚗     ║
  ║                                          ║
  ║   Server:  http://localhost:${PORT}          ║
  ║   Mode:    ${config.nodeEnv.padEnd(28)}║
  ║   API:     /api                          ║
  ║   Health:  /api/health                   ║
  ╚══════════════════════════════════════════╝
  `);
});

module.exports = { app, server, io };
