const db = require('../config/database');
const { paginate, buildPaginationResponse } = require('../utils/helpers');

let userFollowsTableEnsured = false;

const ensureUserFollowsTable = async () => {
  if (userFollowsTableEnsured) {
    return;
  }

  await db.query(`
    CREATE TABLE IF NOT EXISTS user_follows (
      follower_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      following_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (follower_id, following_id),
      CHECK (follower_id <> following_id)
    )
  `);

  await db.query(
    'CREATE INDEX IF NOT EXISTS idx_user_follows_following ON user_follows(following_id)'
  );
  await db.query(
    'CREATE INDEX IF NOT EXISTS idx_user_follows_follower ON user_follows(follower_id)'
  );

  userFollowsTableEnsured = true;
};

const parseLimit = (value, fallback = 20, max = 50) => {
  const parsed = parseInt(value, 10);
  if (Number.isNaN(parsed) || parsed <= 0) {
    return fallback;
  }
  return Math.min(parsed, max);
};

// ===================== CATEGORIES =====================
const getCategories = async (req, res, next) => {
  try {
    const result = await db.query(
      `SELECT c.*, 
       (SELECT COUNT(*) FROM products p WHERE p.category_id = c.id AND p.is_active = true) as product_count
       FROM categories c
       WHERE c.is_active = true
       ORDER BY c.sort_order ASC, c.name ASC`
    );
    res.json({ categories: result.rows });
  } catch (err) {
    next(err);
  }
};

const createCategory = async (req, res, next) => {
  try {
    const { name, name_ar, slug, description, parent_id, sort_order } = req.body;
    const result = await db.query(
      `INSERT INTO categories (name, name_ar, slug, description, parent_id, sort_order)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [name, name_ar, slug, description, parent_id, sort_order || 0]
    );
    res.status(201).json({ category: result.rows[0] });
  } catch (err) {
    next(err);
  }
};

// ===================== VEHICLE DATA =====================
const getVehicleBrands = async (req, res, next) => {
  try {
    const { vehicle_type } = req.query;
    let query = 'SELECT * FROM vehicle_brands WHERE is_active = true';
    const params = [];
    if (vehicle_type) {
      query += ' AND vehicle_type = $1';
      params.push(vehicle_type);
    }
    query += ' ORDER BY name ASC';
    const result = await db.query(query, params);
    res.json({ brands: result.rows });
  } catch (err) {
    next(err);
  }
};

const getVehicleModels = async (req, res, next) => {
  try {
    const { brand_id } = req.params;
    const result = await db.query(
      'SELECT * FROM vehicle_models WHERE brand_id = $1 AND is_active = true ORDER BY name ASC',
      [brand_id]
    );
    res.json({ models: result.rows });
  } catch (err) {
    next(err);
  }
};

const getVehicleYears = async (req, res, next) => {
  try {
    const { model_id } = req.params;
    const result = await db.query(
      'SELECT * FROM vehicle_years WHERE model_id = $1 ORDER BY year DESC',
      [model_id]
    );
    res.json({ years: result.rows });
  } catch (err) {
    next(err);
  }
};

// ===================== ADMIN =====================
const getAdminStats = async (req, res, next) => {
  try {
    const [users, stores, products, orders, revenue] = await Promise.all([
      db.query('SELECT COUNT(*) as total, role FROM users GROUP BY role'),
      db.query('SELECT COUNT(*) as total FROM stores WHERE is_active = true'),
      db.query('SELECT COUNT(*) as total FROM products WHERE is_active = true'),
      db.query('SELECT COUNT(*) as total, status FROM orders GROUP BY status'),
      db.query("SELECT COALESCE(SUM(total), 0) as total FROM orders WHERE status = 'delivered'"),
    ]);

    res.json({
      stats: {
        users: users.rows,
        total_stores: parseInt(stores.rows[0].total),
        total_products: parseInt(products.rows[0].total),
        orders_by_status: orders.rows,
        total_revenue: parseFloat(revenue.rows[0].total),
      },
    });
  } catch (err) {
    next(err);
  }
};

const getAdminUsers = async (req, res, next) => {
  try {
    const { page, limit, offset } = paginate(req.query.page, req.query.limit);
    const { role, search } = req.query;

    let whereClause = 'WHERE 1=1';
    const params = [];
    let paramIndex = 1;

    if (role) {
      whereClause += ` AND role = $${paramIndex}`;
      params.push(role);
      paramIndex++;
    }
    if (search) {
      whereClause += ` AND (email ILIKE $${paramIndex} OR first_name ILIKE $${paramIndex} OR last_name ILIKE $${paramIndex})`;
      params.push(`%${search}%`);
      paramIndex++;
    }

    const countResult = await db.query(`SELECT COUNT(*) FROM users ${whereClause}`, params);
    const total = parseInt(countResult.rows[0].count);

    params.push(limit, offset);
    const result = await db.query(
      `SELECT id, email, first_name, last_name, phone, role, wilaya, is_active, is_verified, created_at
       FROM users ${whereClause}
       ORDER BY created_at DESC
       LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
      params
    );

    res.json(buildPaginationResponse(result.rows, total, page, limit));
  } catch (err) {
    next(err);
  }
};

const updateUserStatus = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { is_active, is_verified, role } = req.body;

    const result = await db.query(
      `UPDATE users SET is_active = COALESCE($1, is_active), is_verified = COALESCE($2, is_verified),
       role = COALESCE($3, role), updated_at = CURRENT_TIMESTAMP
       WHERE id = $4
       RETURNING id, email, first_name, last_name, role, is_active, is_verified`,
      [is_active, is_verified, role, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ message: 'User updated', user: result.rows[0] });
  } catch (err) {
    next(err);
  }
};

const getAdminProducts = async (req, res, next) => {
  try {
    const { page, limit, offset } = paginate(req.query.page, req.query.limit);

    const countResult = await db.query('SELECT COUNT(*) FROM products');
    const total = parseInt(countResult.rows[0].count);

    const result = await db.query(
      `SELECT p.*, s.name as store_name, c.name as category_name
       FROM products p
       LEFT JOIN stores s ON p.store_id = s.id
       LEFT JOIN categories c ON p.category_id = c.id
       ORDER BY p.created_at DESC
       LIMIT $1 OFFSET $2`,
      [limit, offset]
    );

    res.json(buildPaginationResponse(result.rows, total, page, limit));
  } catch (err) {
    next(err);
  }
};

const getAdminStores = async (req, res, next) => {
  try {
    const { page, limit, offset } = paginate(req.query.page, req.query.limit);

    const countResult = await db.query('SELECT COUNT(*) FROM stores');
    const total = parseInt(countResult.rows[0].count);

    const result = await db.query(
      `SELECT s.*, u.email as owner_email, u.first_name as owner_first_name, u.last_name as owner_last_name
       FROM stores s
       JOIN users u ON s.user_id = u.id
       ORDER BY s.created_at DESC
       LIMIT $1 OFFSET $2`,
      [limit, offset]
    );

    res.json(buildPaginationResponse(result.rows, total, page, limit));
  } catch (err) {
    next(err);
  }
};

const updateStoreStatus = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { is_active, is_verified } = req.body;

    const result = await db.query(
      `UPDATE stores SET is_active = COALESCE($1, is_active), is_verified = COALESCE($2, is_verified),
       updated_at = CURRENT_TIMESTAMP WHERE id = $3 RETURNING *`,
      [is_active, is_verified, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Store not found' });
    }

    res.json({ message: 'Store updated', store: result.rows[0] });
  } catch (err) {
    next(err);
  }
};

const getAdminOrders = async (req, res, next) => {
  try {
    const { page, limit, offset } = paginate(req.query.page, req.query.limit);
    const { status } = req.query;

    let whereClause = '';
    const params = [];
    let paramIndex = 1;

    if (status) {
      whereClause = `WHERE o.status = $${paramIndex}`;
      params.push(status);
      paramIndex++;
    }

    const countResult = await db.query(`SELECT COUNT(*) FROM orders o ${whereClause}`, params);
    const total = parseInt(countResult.rows[0].count);

    params.push(limit, offset);
    const result = await db.query(
      `SELECT o.*, s.name as store_name, u.first_name as buyer_first_name, u.last_name as buyer_last_name
       FROM orders o
       JOIN stores s ON o.store_id = s.id
       JOIN users u ON o.buyer_id = u.id
       ${whereClause}
       ORDER BY o.created_at DESC
       LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
      params
    );

    res.json(buildPaginationResponse(result.rows, total, page, limit));
  } catch (err) {
    next(err);
  }
};

// ===================== REPORTS =====================
const createReport = async (req, res, next) => {
  try {
    const { type, target_id, reason, description } = req.body;
    const result = await db.query(
      `INSERT INTO reports (reporter_id, type, target_id, reason, description)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [req.user.id, type, target_id, reason, description]
    );
    res.status(201).json({ message: 'Report submitted', report: result.rows[0] });
  } catch (err) {
    next(err);
  }
};

const getReports = async (req, res, next) => {
  try {
    const { page, limit, offset } = paginate(req.query.page, req.query.limit);
    const { status, type } = req.query;

    let whereClause = 'WHERE 1=1';
    const params = [];
    let paramIndex = 1;

    if (status) { whereClause += ` AND r.status = $${paramIndex}`; params.push(status); paramIndex++; }
    if (type) { whereClause += ` AND r.type = $${paramIndex}`; params.push(type); paramIndex++; }

    const countResult = await db.query(`SELECT COUNT(*) FROM reports r ${whereClause}`, params);
    const total = parseInt(countResult.rows[0].count);

    params.push(limit, offset);
    const result = await db.query(
      `SELECT r.*, u.first_name as reporter_first_name, u.last_name as reporter_last_name
       FROM reports r JOIN users u ON r.reporter_id = u.id
       ${whereClause}
       ORDER BY r.created_at DESC
       LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
      params
    );

    res.json(buildPaginationResponse(result.rows, total, page, limit));
  } catch (err) {
    next(err);
  }
};

const updateReport = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { status, admin_notes } = req.body;

    const result = await db.query(
      `UPDATE reports SET status = $1, admin_notes = $2, resolved_by = $3,
       resolved_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
       WHERE id = $4 RETURNING *`,
      [status, admin_notes, req.user.id, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Report not found' });
    }

    res.json({ message: 'Report updated', report: result.rows[0] });
  } catch (err) {
    next(err);
  }
};

// ===================== WILAYAS =====================
const getWilayas = async (req, res) => {
  const wilayas = [
    '01 - Adrar', '02 - Chlef', '03 - Laghouat', '04 - Oum El Bouaghi', '05 - Batna',
    '06 - Béjaïa', '07 - Biskra', '08 - Béchar', '09 - Blida', '10 - Bouira',
    '11 - Tamanrasset', '12 - Tébessa', '13 - Tlemcen', '14 - Tiaret', '15 - Tizi Ouzou',
    '16 - Alger', '17 - Djelfa', '18 - Jijel', '19 - Sétif', '20 - Saïda',
    '21 - Skikda', '22 - Sidi Bel Abbès', '23 - Annaba', '24 - Guelma', '25 - Constantine',
    '26 - Médéa', '27 - Mostaganem', '28 - M\'Sila', '29 - Mascara', '30 - Ouargla',
    '31 - Oran', '32 - El Bayadh', '33 - Illizi', '34 - Bordj Bou Arreridj', '35 - Boumerdès',
    '36 - El Tarf', '37 - Tindouf', '38 - Tissemsilt', '39 - El Oued', '40 - Khenchela',
    '41 - Souk Ahras', '42 - Tipaza', '43 - Mila', '44 - Aïn Defla', '45 - Naâma',
    '46 - Aïn Témouchent', '47 - Ghardaïa', '48 - Relizane',
    '49 - El M\'Ghair', '50 - El Meniaa', '51 - Ouled Djellal', '52 - Bordj Badji Mokhtar',
    '53 - Béni Abbès', '54 - Timimoun', '55 - Touggourt', '56 - Djanet',
    '57 - In Salah', '58 - In Guezzam'
  ];
  res.json({ wilayas });
};

// ===================== PUBLIC ANNOUNCEMENTS =====================
const getPublicAnnouncements = async (req, res, next) => {
  try {
    await db.query(`
      CREATE TABLE IF NOT EXISTS announcements (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        text TEXT NOT NULL,
        type VARCHAR(20) NOT NULL DEFAULT 'info',
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    const result = await db.query(
      'SELECT id, text, type, created_at FROM announcements WHERE is_active = true ORDER BY created_at DESC LIMIT 10'
    );
    res.json({ announcements: result.rows });
  } catch (err) {
    next(err);
  }
};

// ===================== USER NOTIFICATIONS =====================
const getUserNotifications = async (req, res, next) => {
  try {
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
    const result = await db.query(
      'SELECT * FROM notifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT 50',
      [req.user.id]
    );
    const unreadCount = await db.query(
      'SELECT COUNT(*) as count FROM notifications WHERE user_id = $1 AND is_read = false',
      [req.user.id]
    );
    res.json({
      notifications: result.rows,
      unread_count: parseInt(unreadCount.rows[0].count),
    });
  } catch (err) {
    next(err);
  }
};

const markNotificationRead = async (req, res, next) => {
  try {
    const { id } = req.params;
    if (id === 'all') {
      await db.query('UPDATE notifications SET is_read = true WHERE user_id = $1', [req.user.id]);
    } else {
      await db.query('UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2', [id, req.user.id]);
    }
    res.json({ message: 'Notifications marked as read' });
  } catch (err) {
    next(err);
  }
};

// ===================== APP SETTINGS (PUBLIC) =====================
const getAppSettings = async (req, res, next) => {
  try {
    try {
      const result = await db.query('SELECT key, value FROM app_settings');
      const settings = {};
      result.rows.forEach(r => {
        try { settings[r.key] = JSON.parse(r.value); } catch { settings[r.key] = r.value; }
      });
      res.json({ settings });
    } catch {
      res.json({ settings: {} });
    }
  } catch (err) {
    next(err);
  }
};

// ===================== PUBLIC USERS =====================
const searchPublicUsers = async (req, res, next) => {
  try {
    await ensureUserFollowsTable();

    const search = req.query.search?.toString().trim() ?? '';
    const limit = parseLimit(req.query.limit, 20, 50);

    const where = ['u.is_active = true'];
    const params = [];
    let paramIndex = 1;

    if (req.user?.id) {
      where.push(`u.id <> $${paramIndex}`);
      params.push(req.user.id);
      paramIndex++;
    }

    if (search) {
      where.push(`(
        u.first_name ILIKE $${paramIndex}
        OR u.last_name ILIKE $${paramIndex}
        OR u.email ILIKE $${paramIndex}
        OR (u.first_name || ' ' || u.last_name) ILIKE $${paramIndex}
        OR COALESCE(st.name, '') ILIKE $${paramIndex}
      )`);
      params.push(`%${search}%`);
      paramIndex++;
    }

    const viewerIdParam = req.user?.id ? `$${paramIndex}` : null;
    if (req.user?.id) {
      params.push(req.user.id);
    }

    params.push(limit);
    const limitParam = `$${params.length}`;

    const result = await db.query(
      `SELECT
        u.id,
        u.first_name,
        u.last_name,
        u.avatar,
        u.role,
        u.wilaya,
        st.id as store_id,
        st.name as store_name,
        st.slug as store_slug,
        st.logo as store_logo,
        COALESCE(fstats.followers_count, 0)::int as followers_count,
        COALESCE(fstats.following_count, 0)::int as following_count,
        ${viewerIdParam
          ? `EXISTS (
               SELECT 1 FROM user_follows uf
               WHERE uf.follower_id = ${viewerIdParam} AND uf.following_id = u.id
             )`
          : 'false'} as is_following
       FROM users u
       LEFT JOIN LATERAL (
         SELECT s.id, s.name, s.slug, s.logo
         FROM stores s
         WHERE s.user_id = u.id AND s.is_active = true
         ORDER BY s.updated_at DESC NULLS LAST, s.created_at DESC
         LIMIT 1
       ) st ON true
       LEFT JOIN LATERAL (
         SELECT
           (SELECT COUNT(*) FROM user_follows f1 WHERE f1.following_id = u.id) as followers_count,
           (SELECT COUNT(*) FROM user_follows f2 WHERE f2.follower_id = u.id) as following_count
       ) fstats ON true
       WHERE ${where.join(' AND ')}
       ORDER BY
         CASE WHEN st.id IS NOT NULL THEN 0 ELSE 1 END,
         COALESCE(fstats.followers_count, 0) DESC,
         u.created_at DESC
       LIMIT ${limitParam}`,
      params
    );

    res.json({ users: result.rows, count: result.rows.length });
  } catch (err) {
    next(err);
  }
};

const getPublicUserProfile = async (req, res, next) => {
  try {
    await ensureUserFollowsTable();

    const { id } = req.params;
    const params = [id];

    const viewerIdParam = req.user?.id ? '$2' : null;
    if (req.user?.id) {
      params.push(req.user.id);
    }

    const result = await db.query(
      `SELECT
        u.id,
        u.first_name,
        u.last_name,
        u.avatar,
        u.role,
        u.wilaya,
        u.created_at,
        st.id as store_id,
        st.name as store_name,
        st.slug as store_slug,
        st.logo as store_logo,
        st.description as store_description,
        st.wilaya as store_wilaya,
        COALESCE(st.rating, 0)::float as store_rating,
        COALESCE(st.total_reviews, 0)::int as store_review_count,
        COALESCE((SELECT COUNT(*) FROM products p WHERE p.store_id = st.id AND p.is_active = true), 0)::int as store_product_count,
        COALESCE((SELECT COUNT(*) FROM user_follows uf WHERE uf.following_id = u.id), 0)::int as followers_count,
        COALESCE((SELECT COUNT(*) FROM user_follows uf WHERE uf.follower_id = u.id), 0)::int as following_count,
        ${viewerIdParam
          ? `EXISTS (
               SELECT 1 FROM user_follows uf
               WHERE uf.follower_id = ${viewerIdParam} AND uf.following_id = u.id
             )`
          : 'false'} as is_following
       FROM users u
       LEFT JOIN LATERAL (
         SELECT s.id, s.name, s.slug, s.logo, s.description, s.wilaya, s.rating, s.total_reviews
         FROM stores s
         WHERE s.user_id = u.id AND s.is_active = true
         ORDER BY s.updated_at DESC NULLS LAST, s.created_at DESC
         LIMIT 1
       ) st ON true
       WHERE u.id = $1 AND u.is_active = true
       LIMIT 1`,
      params
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    return res.json({ profile: result.rows[0] });
  } catch (err) {
    return next(err);
  }
};

const followUser = async (req, res, next) => {
  try {
    await ensureUserFollowsTable();

    const followerId = req.user.id;
    const { id: targetUserId } = req.params;

    if (followerId === targetUserId) {
      return res.status(400).json({ error: 'لا يمكنك متابعة نفسك' });
    }

    const userCheck = await db.query(
      'SELECT id FROM users WHERE id = $1 AND is_active = true',
      [targetUserId]
    );
    if (userCheck.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    await db.query(
      'INSERT INTO user_follows (follower_id, following_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
      [followerId, targetUserId]
    );

    const count = await db.query(
      'SELECT COUNT(*)::int as followers_count FROM user_follows WHERE following_id = $1',
      [targetUserId]
    );

    return res.json({
      message: 'تمت المتابعة',
      following: true,
      followers_count: parseInt(count.rows[0].followers_count || 0, 10),
    });
  } catch (err) {
    return next(err);
  }
};

const unfollowUser = async (req, res, next) => {
  try {
    await ensureUserFollowsTable();

    const followerId = req.user.id;
    const { id: targetUserId } = req.params;

    await db.query(
      'DELETE FROM user_follows WHERE follower_id = $1 AND following_id = $2',
      [followerId, targetUserId]
    );

    const count = await db.query(
      'SELECT COUNT(*)::int as followers_count FROM user_follows WHERE following_id = $1',
      [targetUserId]
    );

    return res.json({
      message: 'تم إلغاء المتابعة',
      following: false,
      followers_count: parseInt(count.rows[0].followers_count || 0, 10),
    });
  } catch (err) {
    return next(err);
  }
};

module.exports = {
  getCategories, createCategory,
  getVehicleBrands, getVehicleModels, getVehicleYears,
  getAdminStats, getAdminUsers, updateUserStatus,
  getAdminProducts, getAdminStores, updateStoreStatus,
  getAdminOrders, createReport, getReports, updateReport,
  getWilayas, getPublicAnnouncements,
  getUserNotifications, markNotificationRead, getAppSettings,
  searchPublicUsers, getPublicUserProfile,
  followUser, unfollowUser,
};
