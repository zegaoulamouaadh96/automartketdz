const db = require('../config/database');
const { generateSlug, paginate, buildPaginationResponse } = require('../utils/helpers');

let storeColumnsEnsured = false;

const ensureStoreColumns = async () => {
  if (storeColumnsEnsured) {
    return;
  }

  await db.query('ALTER TABLE stores ADD COLUMN IF NOT EXISTS activity_type VARCHAR(30)');
  storeColumnsEnsured = true;
};

const createStore = async (req, res, next) => {
  try {
    await ensureStoreColumns();

    const { name, description, phone, email, wilaya, address, activity_type, replace_existing } = req.body;
    const shouldReplaceExisting =
      replace_existing === true ||
      replace_existing === 'true' ||
      replace_existing === '1' ||
      replace_existing === 1;

    const slug = generateSlug(name) + '-' + Date.now().toString(36);
    const logo = req.file ? `/uploads/${req.file.filename}` : null;

    // Check if user already has an active store
    const existing = await db.query(
      'SELECT id FROM stores WHERE user_id = $1 AND is_active = true ORDER BY updated_at DESC NULLS LAST, created_at DESC LIMIT 1',
      [req.user.id]
    );

    if (existing.rows.length > 0) {
      if (!shouldReplaceExisting) {
        return res.status(409).json({ error: 'You already have a store' });
      }

      // Archive current active store before creating a replacement.
      await db.query(
        'UPDATE stores SET is_active = false, updated_at = CURRENT_TIMESTAMP WHERE id = $1',
        [existing.rows[0].id]
      );
    }

    const result = await db.query(
      `INSERT INTO stores (user_id, name, slug, description, phone, email, wilaya, address, logo, activity_type, is_active)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
       RETURNING *`,
      [req.user.id, name, slug, description, phone, email, wilaya, address, logo, activity_type || null,
       req.appSettings?.auto_approve_stores !== false && req.appSettings?.auto_approve_stores !== 'false']
    );

    // Update user role to seller if buyer
    if (req.user.role === 'buyer') {
      await db.query('UPDATE users SET role = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2', ['seller', req.user.id]);
    }

    res.status(201).json({
      message: 'Store created',
      store: result.rows[0],
      role_upgraded: req.user.role === 'buyer',
    });
  } catch (err) {
    next(err);
  }
};

const getStore = async (req, res, next) => {
  try {
    await ensureStoreColumns();

    const { id } = req.params;
    const isUUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id);

    let result;
    if (isUUID) {
      result = await db.query(
        `SELECT s.*, u.first_name as owner_first_name, u.last_name as owner_last_name, u.avatar as owner_avatar
         FROM stores s JOIN users u ON s.user_id = u.id WHERE s.id = $1`, [id]
      );
    } else {
      result = await db.query(
        `SELECT s.*, u.first_name as owner_first_name, u.last_name as owner_last_name, u.avatar as owner_avatar
         FROM stores s JOIN users u ON s.user_id = u.id WHERE s.slug = $1`, [id]
      );
    }

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Store not found' });
    }

    res.json({ store: result.rows[0] });
  } catch (err) {
    next(err);
  }
};

const updateStore = async (req, res, next) => {
  try {
    await ensureStoreColumns();

    const { name, description, phone, email, wilaya, address, activity_type } = req.body;
    const logo = req.files?.logo?.[0] ? `/uploads/${req.files.logo[0].filename}` : null;
    const banner = req.files?.banner?.[0] ? `/uploads/${req.files.banner[0].filename}` : null;

    const result = await db.query(
      `UPDATE stores SET name = COALESCE($1, name), description = COALESCE($2, description),
       phone = COALESCE($3, phone), email = COALESCE($4, email),
       wilaya = COALESCE($5, wilaya), address = COALESCE($6, address),
       logo = COALESCE($7, logo), banner = COALESCE($8, banner),
       activity_type = COALESCE($9, activity_type),
       updated_at = CURRENT_TIMESTAMP
       WHERE id = (
         SELECT id FROM stores
         WHERE user_id = $10 AND is_active = true
         ORDER BY updated_at DESC NULLS LAST, created_at DESC
         LIMIT 1
       )
       RETURNING *`,
      [name, description, phone, email, wilaya, address, logo, banner, activity_type || null, req.user.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Store not found' });
    }

    res.json({ message: 'Store updated', store: result.rows[0] });
  } catch (err) {
    next(err);
  }
};

const getMyStore = async (req, res, next) => {
  try {
    await ensureStoreColumns();

    const result = await db.query(
      `SELECT * FROM stores
       WHERE user_id = $1 AND is_active = true
       ORDER BY updated_at DESC NULLS LAST, created_at DESC
       LIMIT 1`,
      [req.user.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'You don\'t have a store yet' });
    }
    res.json({ store: result.rows[0] });
  } catch (err) {
    next(err);
  }
};

const listStores = async (req, res, next) => {
  try {
    await ensureStoreColumns();

    const { page: p, limit: l } = paginate(req.query.page, req.query.limit);
    const { wilaya, search } = req.query;

    let whereClause = 'WHERE s.is_active = true';
    const params = [];
    let paramIndex = 1;

    if (wilaya) {
      whereClause += ` AND s.wilaya = $${paramIndex}`;
      params.push(wilaya);
      paramIndex++;
    }

    if (search) {
      whereClause += ` AND (s.name ILIKE $${paramIndex} OR s.description ILIKE $${paramIndex})`;
      params.push(`%${search}%`);
      paramIndex++;
    }

    const countResult = await db.query(`SELECT COUNT(*) FROM stores s ${whereClause}`, params);
    const total = parseInt(countResult.rows[0].count);

    params.push(l, (p - 1) * l);
    const result = await db.query(
      `SELECT s.*, u.first_name as owner_first_name, u.last_name as owner_last_name
       FROM stores s JOIN users u ON s.user_id = u.id
       ${whereClause}
       ORDER BY s.created_at DESC
       LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
      params
    );

    res.json(buildPaginationResponse(result.rows, total, p, l));
  } catch (err) {
    next(err);
  }
};

const getStoreStats = async (req, res, next) => {
  try {
    const store = await db.query(
      `SELECT id FROM stores
       WHERE user_id = $1 AND is_active = true
       ORDER BY updated_at DESC NULLS LAST, created_at DESC
       LIMIT 1`,
      [req.user.id]
    );

    if (store.rows.length === 0) {
      return res.status(404).json({ error: 'Store not found' });
    }
    const storeId = store.rows[0].id;

    const [products, orders, revenue, reviews, topProducts, monthlySales] = await Promise.all([
      db.query('SELECT COUNT(*)::int as total_products FROM products WHERE store_id = $1 AND is_active = true', [storeId]),
      db.query('SELECT status, COUNT(*)::int as count FROM orders WHERE store_id = $1 GROUP BY status', [storeId]),
      db.query('SELECT COALESCE(SUM(total), 0)::float as total_revenue FROM orders WHERE store_id = $1 AND status = $2', [storeId, 'delivered']),
      db.query('SELECT COUNT(*)::int as total_reviews, COALESCE(AVG(rating), 0)::float as avg_rating FROM store_reviews WHERE store_id = $1', [storeId]),
      db.query(
        `SELECT oi.product_id, oi.product_name,
         SUM(oi.quantity)::int as sold_qty,
         COALESCE(SUM(oi.total), 0)::float as total_amount
         FROM order_items oi
         JOIN orders o ON oi.order_id = o.id
         WHERE o.store_id = $1 AND o.status IN ('confirmed', 'processing', 'shipped', 'delivered')
         GROUP BY oi.product_id, oi.product_name
         ORDER BY sold_qty DESC, total_amount DESC
         LIMIT 5`,
        [storeId]
      ),
      db.query(
        `SELECT TO_CHAR(DATE_TRUNC('month', created_at), 'YYYY-MM') as month,
         COUNT(*)::int as orders_count,
         COALESCE(SUM(total), 0)::float as total_sales
         FROM orders
         WHERE store_id = $1 AND status = 'delivered'
         GROUP BY DATE_TRUNC('month', created_at)
         ORDER BY DATE_TRUNC('month', created_at) DESC
         LIMIT 12`,
        [storeId]
      ),
    ]);

    const ordersByStatus = orders.rows.reduce((acc, row) => {
      acc[row.status] = parseInt(row.count || 0);
      return acc;
    }, {});

    const totalOrders = Object.values(ordersByStatus).reduce((sum, count) => sum + count, 0);
    const newOrders = (ordersByStatus.pending || 0) + (ordersByStatus.confirmed || 0);
    const totalRevenue = parseFloat(revenue.rows[0].total_revenue || 0);
    const profits = totalRevenue;

    res.json({
      stats: {
        total_products: parseInt(products.rows[0].total_products || 0),
        new_orders: newOrders,
        total_orders: totalOrders,
        total_revenue: totalRevenue,
        profits,
        total_reviews: parseInt(reviews.rows[0].total_reviews || 0),
        avg_rating: parseFloat(reviews.rows[0].avg_rating || 0),
        orders_by_status: ordersByStatus,
        best_selling_products: topProducts.rows,
        monthly_sales: monthlySales.rows,
      },
    });
  } catch (err) {
    next(err);
  }
};

module.exports = { createStore, getStore, updateStore, getMyStore, listStores, getStoreStats };
