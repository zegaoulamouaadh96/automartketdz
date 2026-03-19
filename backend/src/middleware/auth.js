const jwt = require('jsonwebtoken');
const config = require('../config');
const db = require('../config/database');
const { findDemoUserById } = require('../utils/demoUsers');

const isDatabaseUnavailable = (error) => {
  if (!error) return false;
  return error.code === 'ECONNREFUSED' || error.name === 'AggregateError';
};

const auth = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    const decoded = jwt.verify(token, config.jwt.secret);

    try {
      const result = await db.query('SELECT id, email, first_name, last_name, phone, role, wilaya, avatar, is_active FROM users WHERE id = $1', [decoded.userId]);

      if (result.rows.length === 0) {
        return res.status(401).json({ error: 'User not found' });
      }

      if (!result.rows[0].is_active) {
        return res.status(403).json({ error: 'Account is deactivated' });
      }

      req.user = result.rows[0];
      req.token = token;
      return next();
    } catch (dbError) {
      if (isDatabaseUnavailable(dbError) && decoded.demo) {
        const demoUser = findDemoUserById(decoded.userId);
        if (demoUser) {
          req.user = demoUser;
          req.token = token;
          return next();
        }
      }

      throw dbError;
    }
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token expired' });
    }

    if (isDatabaseUnavailable(err)) {
      return res.status(503).json({ error: 'Database service is unavailable' });
    }

    res.status(401).json({ error: 'Invalid token' });
  }
};

const authorize = (...roles) => {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Access denied. Insufficient permissions.' });
    }
    next();
  };
};

const optionalAuth = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    if (token) {
      const decoded = jwt.verify(token, config.jwt.secret);
      try {
        const result = await db.query('SELECT id, email, first_name, last_name, role, wilaya, avatar FROM users WHERE id = $1 AND is_active = true', [decoded.userId]);
        if (result.rows.length > 0) {
          req.user = result.rows[0];
        }
      } catch (dbError) {
        if (isDatabaseUnavailable(dbError) && decoded.demo) {
          const demoUser = findDemoUserById(decoded.userId);
          if (demoUser) {
            req.user = demoUser;
          }
        }
      }
    }
  } catch (err) {
    // Ignore token errors for optional auth
  }
  next();
};

module.exports = { auth, authorize, optionalAuth };
