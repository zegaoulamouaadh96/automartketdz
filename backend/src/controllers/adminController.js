const db = require('../config/database');
const { generateSlug, paginate, buildPaginationResponse } = require('../utils/helpers');

// ===================== DASHBOARD STATS =====================
const getAdminDashboardStats = async (req, res, next) => {
  try {
    const [usersR, storesR, productsR, ordersR, revenueR, reportsR, todayOrdersR, todayUsersR] = await Promise.all([
      db.query(`SELECT COUNT(*) as total FROM users`),
      db.query(`SELECT COUNT(*) as total, COUNT(*) FILTER (WHERE is_active = true) as active, COUNT(*) FILTER (WHERE is_active = false) as inactive FROM stores`),
      db.query(`SELECT COUNT(*) as total FROM products`),
      db.query(`SELECT COUNT(*) as total, status FROM orders GROUP BY status`),
      db.query(`SELECT COALESCE(SUM(total), 0) as total FROM orders WHERE status = 'delivered'`),
      db.query(`SELECT COUNT(*) as total, COUNT(*) FILTER (WHERE status = 'pending') as pending FROM reports`),
      db.query(`SELECT COUNT(*) as total FROM orders WHERE created_at >= CURRENT_DATE`),
      db.query(`SELECT COUNT(*) as total FROM users WHERE created_at >= CURRENT_DATE`),
    ]);

    const ordersByStatus = {};
    let totalOrders = 0;
    ordersR.rows.forEach(r => { ordersByStatus[r.status] = parseInt(r.total); totalOrders += parseInt(r.total); });

    res.json({
      total_users: parseInt(usersR.rows[0].total),
      total_stores: parseInt(storesR.rows[0].total),
      active_stores: parseInt(storesR.rows[0].active),
      total_products: parseInt(productsR.rows[0].total),
      total_orders: totalOrders,
      total_revenue: parseFloat(revenueR.rows[0].total),
      total_reports: parseInt(reportsR.rows[0].total),
      pending_reports: parseInt(reportsR.rows[0].pending),
      orders_pending: ordersByStatus.pending || 0,
      orders_processing: ordersByStatus.processing || 0,
      orders_shipped: ordersByStatus.shipped || 0,
      orders_delivered: ordersByStatus.delivered || 0,
      orders_cancelled: ordersByStatus.cancelled || 0,
      today_orders: parseInt(todayOrdersR.rows[0].total),
      today_users: parseInt(todayUsersR.rows[0].total),
    });
  } catch (err) {
    next(err);
  }
};

// ===================== ACTIVITY LOG =====================
const getAdminActivity = async (req, res, next) => {
  try {
    const result = await db.query(
      `SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT 20`
    );
    res.json({ activity: result.rows });
  } catch (err) {
    next(err);
  }
};

// ===================== USER BY ID =====================
const getAdminUserById = async (req, res, next) => {
  try {
    const { id } = req.params;
    const result = await db.query(
      `SELECT id, email, first_name, last_name, phone, role, wilaya, address, avatar, is_active, is_verified, created_at, updated_at FROM users WHERE id = $1`,
      [id]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'User not found' });

    const [ordersR, storeR, reportsR] = await Promise.all([
      db.query(`SELECT COUNT(*) as total FROM orders WHERE buyer_id = $1`, [id]),
      db.query(`SELECT id, name, is_active FROM stores WHERE user_id = $1`, [id]),
      db.query(`SELECT COUNT(*) as total FROM reports WHERE reporter_id = $1`, [id]),
    ]);

    const user = result.rows[0];
    user.total_orders = parseInt(ordersR.rows[0].total);
    user.stores = storeR.rows;
    user.total_reports = parseInt(reportsR.rows[0].total);

    res.json({ user });
  } catch (err) {
    next(err);
  }
};

// ===================== DELETE PRODUCT =====================
const deleteAdminProduct = async (req, res, next) => {
  try {
    const { id } = req.params;
    const result = await db.query('DELETE FROM products WHERE id = $1 RETURNING id, name', [id]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Product not found' });
    res.json({ message: 'Product deleted', product: result.rows[0] });
  } catch (err) {
    next(err);
  }
};

// ===================== STORE BY ID =====================
const getAdminStoreById = async (req, res, next) => {
  try {
    const { id } = req.params;
    const result = await db.query(
      `SELECT s.*, u.email as owner_email, u.first_name as owner_first_name, u.last_name as owner_last_name, u.phone as owner_phone
       FROM stores s JOIN users u ON s.user_id = u.id WHERE s.id = $1`,
      [id]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Store not found' });

    const [productsR, ordersR, reviewsR] = await Promise.all([
      db.query(`SELECT COUNT(*) as total FROM products WHERE store_id = $1`, [id]),
      db.query(`SELECT COUNT(*) as total, COALESCE(SUM(total), 0) as revenue FROM orders WHERE store_id = $1 AND status = 'delivered'`, [id]),
      db.query(`SELECT COUNT(*) as total, COALESCE(AVG(rating), 0) as avg_rating FROM store_reviews WHERE store_id = $1`, [id]),
    ]);

    const store = result.rows[0];
    store.product_count = parseInt(productsR.rows[0].total);
    store.total_orders = parseInt(ordersR.rows[0].total);
    store.revenue = parseFloat(ordersR.rows[0].revenue);
    store.review_count = parseInt(reviewsR.rows[0].total);
    store.avg_rating = parseFloat(reviewsR.rows[0].avg_rating).toFixed(1);

    res.json({ store });
  } catch (err) {
    next(err);
  }
};

// ===================== DELETE STORE =====================
const deleteAdminStore = async (req, res, next) => {
  try {
    const { id } = req.params;
    const result = await db.query('DELETE FROM stores WHERE id = $1 RETURNING id, name', [id]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Store not found' });
    res.json({ message: 'Store deleted', store: result.rows[0] });
  } catch (err) {
    next(err);
  }
};

// ===================== ORDER BY ID =====================
const getAdminOrderById = async (req, res, next) => {
  try {
    const { id } = req.params;
    const result = await db.query(
      `SELECT o.*, s.name as store_name, u.first_name as buyer_first_name, u.last_name as buyer_last_name, u.email as buyer_email, u.phone as buyer_phone
       FROM orders o JOIN stores s ON o.store_id = s.id JOIN users u ON o.buyer_id = u.id WHERE o.id = $1`,
      [id]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Order not found' });

    const itemsR = await db.query(
      `SELECT oi.*, pi.url as image FROM order_items oi LEFT JOIN product_images pi ON pi.product_id = oi.product_id AND pi.is_primary = true WHERE oi.order_id = $1`,
      [id]
    );

    const order = result.rows[0];
    order.buyer_name = `${order.buyer_first_name} ${order.buyer_last_name}`;
    order.items = itemsR.rows;

    res.json({ order });
  } catch (err) {
    next(err);
  }
};

// ===================== UPDATE ORDER STATUS =====================
const updateAdminOrderStatus = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    const timestamps = {};
    if (status === 'confirmed') timestamps.confirmed_at = 'CURRENT_TIMESTAMP';
    if (status === 'shipped') timestamps.shipped_at = 'CURRENT_TIMESTAMP';
    if (status === 'delivered') timestamps.delivered_at = 'CURRENT_TIMESTAMP';
    if (status === 'cancelled') timestamps.cancelled_at = 'CURRENT_TIMESTAMP';

    let extraSets = '';
    Object.entries(timestamps).forEach(([key, val]) => {
      extraSets += `, ${key} = ${val}`;
    });

    const result = await db.query(
      `UPDATE orders SET status = $1, updated_at = CURRENT_TIMESTAMP ${extraSets} WHERE id = $2 RETURNING *`,
      [status, id]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Order not found' });
    res.json({ message: 'Order status updated', order: result.rows[0] });
  } catch (err) {
    next(err);
  }
};

// ===================== REPORT BY ID =====================
const getAdminReportById = async (req, res, next) => {
  try {
    const { id } = req.params;
    const result = await db.query(
      `SELECT r.*, u.first_name as reporter_first_name, u.last_name as reporter_last_name, u.email as reporter_email
       FROM reports r JOIN users u ON r.reporter_id = u.id WHERE r.id = $1`,
      [id]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Report not found' });

    const report = result.rows[0];
    report.reporter_name = `${report.reporter_first_name} ${report.reporter_last_name}`;

    // Get target info
    if (report.type === 'product') {
      const p = await db.query('SELECT id, name FROM products WHERE id = $1', [report.target_id]);
      report.reported_item_name = p.rows[0]?.name || 'Unknown';
    } else if (report.type === 'store') {
      const s = await db.query('SELECT id, name FROM stores WHERE id = $1', [report.target_id]);
      report.reported_item_name = s.rows[0]?.name || 'Unknown';
    } else if (report.type === 'user') {
      const u = await db.query('SELECT id, first_name, last_name FROM users WHERE id = $1', [report.target_id]);
      report.reported_item_name = u.rows[0] ? `${u.rows[0].first_name} ${u.rows[0].last_name}` : 'Unknown';
    }

    res.json({ report });
  } catch (err) {
    next(err);
  }
};

// ===================== CATEGORY MANAGEMENT =====================
const updateAdminCategory = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { name, name_ar, description, icon, sort_order } = req.body;
    const slug = name ? generateSlug(name) : undefined;

    const result = await db.query(
      `UPDATE categories SET name = COALESCE($1, name), name_ar = COALESCE($2, name_ar), 
       description = COALESCE($3, description), icon = COALESCE($4, icon),
       slug = COALESCE($5, slug), sort_order = COALESCE($6, sort_order)
       WHERE id = $7 RETURNING *`,
      [name, name_ar, description, icon, slug, sort_order, id]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Category not found' });
    res.json({ message: 'Category updated', category: result.rows[0] });
  } catch (err) {
    next(err);
  }
};

const deleteAdminCategory = async (req, res, next) => {
  try {
    const { id } = req.params;
    const result = await db.query('DELETE FROM categories WHERE id = $1 RETURNING id, name', [id]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Category not found' });
    res.json({ message: 'Category deleted', category: result.rows[0] });
  } catch (err) {
    next(err);
  }
};

// ===================== BRAND MANAGEMENT =====================
const createAdminBrand = async (req, res, next) => {
  try {
    const { name, vehicle_type } = req.body;
    const slug = generateSlug(name);
    const result = await db.query(
      `INSERT INTO vehicle_brands (name, slug, vehicle_type) VALUES ($1, $2, $3) RETURNING *`,
      [name, slug, vehicle_type]
    );
    res.status(201).json({ message: 'Brand created', brand: result.rows[0] });
  } catch (err) {
    next(err);
  }
};

const deleteAdminBrand = async (req, res, next) => {
  try {
    const { id } = req.params;
    const result = await db.query('DELETE FROM vehicle_brands WHERE id = $1 RETURNING id, name', [id]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Brand not found' });
    res.json({ message: 'Brand deleted', brand: result.rows[0] });
  } catch (err) {
    next(err);
  }
};

// ===================== SETTINGS =====================
const getAdminSettings = async (req, res, next) => {
  try {
    // Try to read from a settings table, or return defaults
    try {
      const result = await db.query(`SELECT key, value FROM app_settings`);
      const settings = {};
      result.rows.forEach(r => {
        try { settings[r.key] = JSON.parse(r.value); } catch { settings[r.key] = r.value; }
      });
      res.json({ settings });
    } catch {
      // Table doesn't exist, create it and return defaults
      await db.query(`
        CREATE TABLE IF NOT EXISTS app_settings (
          key VARCHAR(100) PRIMARY KEY,
          value TEXT,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      res.json({ settings: {} });
    }
  } catch (err) {
    next(err);
  }
};

const updateAdminSettings = async (req, res, next) => {
  try {
    await db.query(`
      CREATE TABLE IF NOT EXISTS app_settings (
        key VARCHAR(100) PRIMARY KEY,
        value TEXT,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    const settings = req.body;
    const client = await db.getClient();
    try {
      await client.query('BEGIN');
      for (const [key, value] of Object.entries(settings)) {
        const val = typeof value === 'object' ? JSON.stringify(value) : String(value);
        await client.query(
          `INSERT INTO app_settings (key, value, updated_at) VALUES ($1, $2, CURRENT_TIMESTAMP)
           ON CONFLICT (key) DO UPDATE SET value = $2, updated_at = CURRENT_TIMESTAMP`,
          [key, val]
        );
      }
      await client.query('COMMIT');
      res.json({ message: 'Settings saved', settings });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } catch (err) {
    next(err);
  }
};

// ===================== ANNOUNCEMENTS =====================
const ensureAnnouncementsTable = async () => {
  await db.query(`
    CREATE TABLE IF NOT EXISTS announcements (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      text TEXT NOT NULL,
      type VARCHAR(20) NOT NULL DEFAULT 'info',
      is_active BOOLEAN DEFAULT true,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);
};

const getAdminAnnouncements = async (req, res, next) => {
  try {
    await ensureAnnouncementsTable();
    const result = await db.query(
      'SELECT * FROM announcements ORDER BY created_at DESC LIMIT 20'
    );
    res.json({ announcements: result.rows });
  } catch (err) {
    next(err);
  }
};

const createAnnouncement = async (req, res, next) => {
  try {
    await ensureAnnouncementsTable();
    const { text, type } = req.body;
    if (!text || !text.trim()) {
      return res.status(400).json({ error: 'Announcement text is required' });
    }
    const validTypes = ['info', 'warning', 'success', 'danger'];
    const safeType = validTypes.includes(type) ? type : 'info';
    const result = await db.query(
      'INSERT INTO announcements (text, type) VALUES ($1, $2) RETURNING *',
      [text.trim(), safeType]
    );
    res.status(201).json({ announcement: result.rows[0] });
  } catch (err) {
    next(err);
  }
};

const deleteAnnouncement = async (req, res, next) => {
  try {
    await ensureAnnouncementsTable();
    const { id } = req.params;
    await db.query('DELETE FROM announcements WHERE id = $1', [id]);
    res.json({ message: 'Announcement deleted' });
  } catch (err) {
    next(err);
  }
};

// ===================== NOTIFICATIONS =====================
const ensureNotificationsTable = async () => {
  await db.query(`
    CREATE TABLE IF NOT EXISTS notifications (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      user_id UUID REFERENCES users(id) ON DELETE CASCADE,
      title VARCHAR(255) NOT NULL,
      message TEXT NOT NULL,
      type VARCHAR(30) NOT NULL DEFAULT 'info',
      is_read BOOLEAN DEFAULT false,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);
};

const getNotifications = async (req, res, next) => {
  try {
    await ensureNotificationsTable();
    const { page = 1, limit = 20 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);
    const result = await db.query(
      `SELECT n.*, u.first_name, u.last_name, u.email as user_email
       FROM notifications n
       LEFT JOIN users u ON n.user_id = u.id
       ORDER BY n.created_at DESC
       LIMIT $1 OFFSET $2`,
      [parseInt(limit), offset]
    );
    const countR = await db.query('SELECT COUNT(*) as total FROM notifications');
    res.json({
      notifications: result.rows,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: parseInt(countR.rows[0].total),
        totalPages: Math.ceil(parseInt(countR.rows[0].total) / parseInt(limit)),
      },
    });
  } catch (err) {
    next(err);
  }
};

const sendNotification = async (req, res, next) => {
  try {
    await ensureNotificationsTable();
    const { title, message, type, user_email, user_id, send_to_all } = req.body;
    if (!title || !message) {
      return res.status(400).json({ error: 'Title and message are required' });
    }
    const validTypes = ['info', 'warning', 'success', 'danger', 'order', 'system'];
    const safeType = validTypes.includes(type) ? type : 'info';

    if (send_to_all) {
      // Send to all users
      const users = await db.query('SELECT id FROM users WHERE is_active = true');
      const client = await db.getClient();
      try {
        await client.query('BEGIN');
        for (const user of users.rows) {
          await client.query(
            'INSERT INTO notifications (user_id, title, message, type) VALUES ($1, $2, $3, $4)',
            [user.id, title.trim(), message.trim(), safeType]
          );
        }
        await client.query('COMMIT');
        res.status(201).json({ message: `Notification sent to ${users.rows.length} users` });
      } catch (err) {
        await client.query('ROLLBACK');
        throw err;
      } finally {
        client.release();
      }
    } else {
      // Send to specific user by email or ID
      let targetUserId = user_id;
      if (!targetUserId && user_email) {
        const userR = await db.query('SELECT id FROM users WHERE email = $1', [user_email]);
        if (userR.rows.length === 0) {
          return res.status(404).json({ error: 'User not found with this email' });
        }
        targetUserId = userR.rows[0].id;
      }
      if (!targetUserId) {
        return res.status(400).json({ error: 'user_email, user_id, or send_to_all is required' });
      }
      const result = await db.query(
        'INSERT INTO notifications (user_id, title, message, type) VALUES ($1, $2, $3, $4) RETURNING *',
        [targetUserId, title.trim(), message.trim(), safeType]
      );
      res.status(201).json({ notification: result.rows[0] });
    }
  } catch (err) {
    next(err);
  }
};

const deleteNotification = async (req, res, next) => {
  try {
    await ensureNotificationsTable();
    const { id } = req.params;
    await db.query('DELETE FROM notifications WHERE id = $1', [id]);
    res.json({ message: 'Notification deleted' });
  } catch (err) {
    next(err);
  }
};

// ===================== STAFF MANAGEMENT (FOUNDER ONLY) =====================
const bcrypt = require('bcryptjs');

const getStaffMembers = async (req, res, next) => {
  try {
    const result = await db.query(
      `SELECT id, email, first_name, last_name, phone, role, wilaya, avatar, is_active, created_at, updated_at
       FROM users WHERE role IN ('admin', 'employee')
       ORDER BY created_at DESC`
    );
    res.json({ staff: result.rows });
  } catch (err) {
    next(err);
  }
};

const createStaffMember = async (req, res, next) => {
  try {
    const { email, password, first_name, last_name, phone, role } = req.body;
    if (!email || !password || !first_name || !last_name) {
      return res.status(400).json({ error: 'Email, password, first name, and last name are required' });
    }
    if (!['admin', 'employee'].includes(role)) {
      return res.status(400).json({ error: 'Role must be admin or employee' });
    }
    // Check if email already exists
    const existing = await db.query('SELECT id FROM users WHERE email = $1', [email]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Email already registered' });
    }
    const hashedPassword = await bcrypt.hash(password, 10);
    const result = await db.query(
      `INSERT INTO users (email, password, first_name, last_name, phone, role, is_active, is_verified)
       VALUES ($1, $2, $3, $4, $5, $6, true, true) RETURNING id, email, first_name, last_name, phone, role, is_active, created_at`,
      [email, hashedPassword, first_name, last_name, phone || null, role]
    );
    res.status(201).json({ message: 'Staff member created', staff: result.rows[0] });
  } catch (err) {
    next(err);
  }
};

const updateStaffMember = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { email, password, first_name, last_name, phone, role, is_active } = req.body;

    // Can't edit founder accounts
    const target = await db.query('SELECT role FROM users WHERE id = $1', [id]);
    if (target.rows.length === 0) return res.status(404).json({ error: 'User not found' });
    if (target.rows[0].role === 'founder') {
      return res.status(403).json({ error: 'Cannot modify founder account' });
    }

    // Build update query dynamically
    const updates = [];
    const values = [];
    let paramIdx = 1;

    if (email) { updates.push(`email = $${paramIdx++}`); values.push(email); }
    if (first_name) { updates.push(`first_name = $${paramIdx++}`); values.push(first_name); }
    if (last_name) { updates.push(`last_name = $${paramIdx++}`); values.push(last_name); }
    if (phone !== undefined) { updates.push(`phone = $${paramIdx++}`); values.push(phone); }
    if (role && ['admin', 'employee'].includes(role)) { updates.push(`role = $${paramIdx++}`); values.push(role); }
    if (is_active !== undefined) { updates.push(`is_active = $${paramIdx++}`); values.push(is_active); }
    if (password) {
      const hashedPassword = await bcrypt.hash(password, 10);
      updates.push(`password = $${paramIdx++}`);
      values.push(hashedPassword);
    }

    if (updates.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }

    updates.push(`updated_at = CURRENT_TIMESTAMP`);
    values.push(id);
    const result = await db.query(
      `UPDATE users SET ${updates.join(', ')} WHERE id = $${paramIdx} RETURNING id, email, first_name, last_name, phone, role, is_active, updated_at`,
      values
    );
    res.json({ message: 'Staff member updated', staff: result.rows[0] });
  } catch (err) {
    next(err);
  }
};

const deleteStaffMember = async (req, res, next) => {
  try {
    const { id } = req.params;
    // Can't delete founder
    const target = await db.query('SELECT role FROM users WHERE id = $1', [id]);
    if (target.rows.length === 0) return res.status(404).json({ error: 'User not found' });
    if (target.rows[0].role === 'founder') {
      return res.status(403).json({ error: 'Cannot delete founder account' });
    }
    await db.query('DELETE FROM users WHERE id = $1 AND role IN ($2, $3)', [id, 'admin', 'employee']);
    res.json({ message: 'Staff member deleted' });
  } catch (err) {
    next(err);
  }
};

module.exports = {
  getAdminDashboardStats,
  getAdminActivity,
  getAdminUserById,
  deleteAdminProduct,
  getAdminStoreById,
  deleteAdminStore,
  getAdminOrderById,
  updateAdminOrderStatus,
  getAdminReportById,
  updateAdminCategory,
  deleteAdminCategory,
  createAdminBrand,
  deleteAdminBrand,
  getAdminSettings,
  updateAdminSettings,
  getAdminAnnouncements,
  createAnnouncement,
  deleteAnnouncement,
  getNotifications,
  sendNotification,
  deleteNotification,
  getStaffMembers,
  createStaffMember,
  updateStaffMember,
  deleteStaffMember,
};
