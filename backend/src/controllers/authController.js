const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../config/database');
const config = require('../config');
const { findDemoUserByCredentials } = require('../utils/demoUsers');

const isDatabaseUnavailable = (error) => {
  if (!error) return false;
  return error.code === 'ECONNREFUSED' || error.name === 'AggregateError';
};

const register = async (req, res, next) => {
  try {
    // Check if registration is open
    if (req.appSettings && (req.appSettings.registration_open === false || req.appSettings.registration_open === 'false')) {
      return res.status(403).json({ error: 'التسجيل مغلق حالياً' });
    }

    const { email, password, first_name, last_name, phone, role, wilaya } = req.body;

    // Check if user exists
    const existing = await db.query('SELECT id FROM users WHERE email = $1', [email]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Email already registered' });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Create user
    const result = await db.query(
      `INSERT INTO users (email, password, first_name, last_name, phone, role, wilaya)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id, email, first_name, last_name, phone, role, wilaya, created_at`,
      [email, hashedPassword, first_name, last_name, phone, role || 'buyer', wilaya]
    );

    const user = result.rows[0];
    const token = jwt.sign({ userId: user.id, role: user.role }, config.jwt.secret, {
      expiresIn: config.jwt.expiresIn,
    });

    res.status(201).json({
      message: 'Registration successful',
      user,
      token,
    });
  } catch (err) {
    next(err);
  }
};

const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    const result = await db.query(
      'SELECT id, email, password, first_name, last_name, phone, role, wilaya, avatar, is_active FROM users WHERE email = $1',
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const user = result.rows[0];

    if (!user.is_active) {
      return res.status(403).json({ error: 'Account is deactivated' });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const token = jwt.sign({ userId: user.id, role: user.role }, config.jwt.secret, {
      expiresIn: config.jwt.expiresIn,
    });

    delete user.password;

    res.json({
      message: 'Login successful',
      user,
      token,
    });
  } catch (err) {
    if (isDatabaseUnavailable(err)) {
      const { email, password } = req.body;
      const demoUser = findDemoUserByCredentials(email, password);

      if (!demoUser) {
        return res.status(401).json({ error: 'Invalid email or password' });
      }

      const token = jwt.sign(
        { userId: demoUser.id, role: demoUser.role, demo: true },
        config.jwt.secret,
        { expiresIn: config.jwt.expiresIn }
      );

      return res.json({
        message: 'Login successful (demo mode)',
        user: demoUser,
        token,
        demo_mode: true,
      });
    }

    next(err);
  }
};

const getProfile = async (req, res, next) => {
  try {
    if (req.user?.demo_mode) {
      return res.json({ user: req.user });
    }

    const result = await db.query(
      `SELECT id, email, first_name, last_name, phone, role, wilaya, address, avatar, is_verified, created_at
       FROM users WHERE id = $1`,
      [req.user.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ user: result.rows[0] });
  } catch (err) {
    next(err);
  }
};

const updateProfile = async (req, res, next) => {
  try {
    if (req.user?.demo_mode) {
      return res.status(400).json({ error: 'Profile updates are disabled in demo mode' });
    }

    const { first_name, last_name, phone, wilaya, address } = req.body;

    const result = await db.query(
      `UPDATE users SET first_name = COALESCE($1, first_name), last_name = COALESCE($2, last_name),
       phone = COALESCE($3, phone), wilaya = COALESCE($4, wilaya), address = COALESCE($5, address),
       updated_at = CURRENT_TIMESTAMP
       WHERE id = $6
       RETURNING id, email, first_name, last_name, phone, role, wilaya, address, avatar`,
      [first_name, last_name, phone, wilaya, address, req.user.id]
    );

    res.json({ message: 'Profile updated', user: result.rows[0] });
  } catch (err) {
    next(err);
  }
};

const updateAvatar = async (req, res, next) => {
  try {
    if (req.user?.demo_mode) {
      return res.status(400).json({ error: 'Avatar updates are disabled in demo mode' });
    }

    const removeAvatar =
      req.body?.remove_avatar === true ||
      req.body?.remove_avatar === 'true' ||
      req.body?.remove_avatar === '1' ||
      req.body?.remove_avatar === 1;

    if (!req.file && !removeAvatar) {
      return res.status(400).json({ error: 'Avatar file is required' });
    }

    const avatar = removeAvatar ? null : `/uploads/${req.file.filename}`;

    const result = await db.query(
      `UPDATE users
       SET avatar = $1,
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $2
       RETURNING id, email, first_name, last_name, phone, role, wilaya, address, avatar`,
      [avatar, req.user.id]
    );

    res.json({
      message: avatar ? 'Avatar updated' : 'Avatar removed',
      user: result.rows[0],
    });
  } catch (err) {
    next(err);
  }
};

const changePassword = async (req, res, next) => {
  try {
    if (req.user?.demo_mode) {
      return res.status(400).json({ error: 'Password change is disabled in demo mode' });
    }

    const { current_password, new_password } = req.body;

    const result = await db.query('SELECT password FROM users WHERE id = $1', [req.user.id]);
    const isMatch = await bcrypt.compare(current_password, result.rows[0].password);

    if (!isMatch) {
      return res.status(400).json({ error: 'Current password is incorrect' });
    }

    const hashedPassword = await bcrypt.hash(new_password, 10);
    await db.query('UPDATE users SET password = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2', [hashedPassword, req.user.id]);

    res.json({ message: 'Password changed successfully' });
  } catch (err) {
    next(err);
  }
};

module.exports = { register, login, getProfile, updateProfile, updateAvatar, changePassword };
