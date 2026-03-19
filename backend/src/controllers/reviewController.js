const db = require('../config/database');

const addProductReview = async (req, res, next) => {
  try {
    // Check if reviews are enabled
    if (req.appSettings && (req.appSettings.reviews_enabled === false || req.appSettings.reviews_enabled === 'false')) {
      return res.status(403).json({ error: 'التقييمات معطلة حالياً' });
    }

    const { id } = req.params; // product_id
    const { rating, comment } = req.body;

    // Check if product exists
    const product = await db.query('SELECT id, store_id FROM products WHERE id = $1', [id]);
    if (product.rows.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }

    // Check verified purchase
    const purchase = await db.query(
      `SELECT 1 FROM order_items oi
       JOIN orders o ON oi.order_id = o.id
       WHERE oi.product_id = $1 AND o.buyer_id = $2 AND o.status = 'delivered'`,
      [id, req.user.id]
    );

    const result = await db.query(
      `INSERT INTO product_reviews (product_id, user_id, rating, comment, is_verified_purchase)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [id, req.user.id, rating, comment, purchase.rows.length > 0]
    );

    // Update product rating
    const avgResult = await db.query(
      'SELECT AVG(rating) as avg_rating, COUNT(*) as count FROM product_reviews WHERE product_id = $1 AND is_active = true',
      [id]
    );
    await db.query(
      'UPDATE products SET rating = $1, total_reviews = $2 WHERE id = $3',
      [avgResult.rows[0].avg_rating, avgResult.rows[0].count, id]
    );

    res.status(201).json({ message: 'Review added', review: result.rows[0] });
  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ error: 'You already reviewed this product' });
    }
    next(err);
  }
};

const getProductReviews = async (req, res, next) => {
  try {
    const { id } = req.params;
    const result = await db.query(
      `SELECT pr.*, u.first_name, u.last_name, u.avatar
       FROM product_reviews pr
       JOIN users u ON pr.user_id = u.id
       WHERE pr.product_id = $1 AND pr.is_active = true
       ORDER BY pr.created_at DESC`,
      [id]
    );

    res.json({ reviews: result.rows });
  } catch (err) {
    next(err);
  }
};

const addStoreReview = async (req, res, next) => {
  try {
    const { id } = req.params; // store_id
    const { rating, comment } = req.body;

    const store = await db.query('SELECT id FROM stores WHERE id = $1', [id]);
    if (store.rows.length === 0) {
      return res.status(404).json({ error: 'Store not found' });
    }

    const result = await db.query(
      `INSERT INTO store_reviews (store_id, user_id, rating, comment)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [id, req.user.id, rating, comment]
    );

    // Update store rating
    const avgResult = await db.query(
      'SELECT AVG(rating) as avg_rating, COUNT(*) as count FROM store_reviews WHERE store_id = $1 AND is_active = true',
      [id]
    );
    await db.query(
      'UPDATE stores SET rating = $1, total_reviews = $2 WHERE id = $3',
      [avgResult.rows[0].avg_rating, avgResult.rows[0].count, id]
    );

    res.status(201).json({ message: 'Review added', review: result.rows[0] });
  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ error: 'You already reviewed this store' });
    }
    next(err);
  }
};

const getStoreReviews = async (req, res, next) => {
  try {
    const { id } = req.params;
    const result = await db.query(
      `SELECT sr.*, u.first_name, u.last_name, u.avatar
       FROM store_reviews sr
       JOIN users u ON sr.user_id = u.id
       WHERE sr.store_id = $1 AND sr.is_active = true
       ORDER BY sr.created_at DESC`,
      [id]
    );

    res.json({ reviews: result.rows });
  } catch (err) {
    next(err);
  }
};

module.exports = { addProductReview, getProductReviews, addStoreReview, getStoreReviews };
