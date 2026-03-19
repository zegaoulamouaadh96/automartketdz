const db = require('../config/database');
const { generateOrderNumber, paginate, buildPaginationResponse } = require('../utils/helpers');

const createOrder = async (req, res, next) => {
  try {
    const { items, shipping_wilaya, shipping_address, shipping_phone, shipping_name, notes, payment_method } = req.body;
    const client = await db.getClient();

    try {
      await client.query('BEGIN');

      // Group items by store
      const storeItems = {};
      for (const item of items) {
        const product = await client.query(
          'SELECT id, store_id, name, price, quantity FROM products WHERE id = $1 AND is_active = true',
          [item.product_id]
        );
        if (product.rows.length === 0) {
          throw { status: 400, message: `Product ${item.product_id} not found` };
        }
        const p = product.rows[0];
        if (p.quantity < item.quantity) {
          throw { status: 400, message: `Insufficient stock for ${p.name}` };
        }
        if (!storeItems[p.store_id]) storeItems[p.store_id] = [];
        storeItems[p.store_id].push({ ...p, order_qty: item.quantity });
      }

      const orders = [];
      for (const [storeId, products] of Object.entries(storeItems)) {
        const subtotal = products.reduce((sum, p) => sum + p.price * p.order_qty, 0);
        const shippingCost = 0; // Can be calculated based on wilaya
        const total = subtotal + shippingCost;
        const orderNumber = generateOrderNumber();

        const orderResult = await client.query(
          `INSERT INTO orders (order_number, buyer_id, store_id, subtotal, shipping_cost, total,
           shipping_wilaya, shipping_address, shipping_phone, shipping_name, notes)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
           RETURNING *`,
          [orderNumber, req.user.id, storeId, subtotal, shippingCost, total,
            shipping_wilaya, shipping_address, shipping_phone, shipping_name, notes]
        );

        const order = orderResult.rows[0];

        for (const p of products) {
          await client.query(
            `INSERT INTO order_items (order_id, product_id, product_name, product_price, quantity, total)
             VALUES ($1, $2, $3, $4, $5, $6)`,
            [order.id, p.id, p.name, p.price, p.order_qty, p.price * p.order_qty]
          );
          // Update stock
          await client.query(
            'UPDATE products SET quantity = quantity - $1, total_sold = total_sold + $1 WHERE id = $2',
            [p.order_qty, p.id]
          );
        }

        // Create payment record
        await client.query(
          `INSERT INTO payments (order_id, method, amount)
           VALUES ($1, $2, $3)`,
          [order.id, payment_method || 'cash_on_delivery', total]
        );

        // Update store sales count
        await client.query(
          'UPDATE stores SET total_sales = total_sales + 1 WHERE id = $1',
          [storeId]
        );

        orders.push(order);
      }

      await client.query('COMMIT');
      res.status(201).json({ message: 'Order created', orders });
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

const getOrders = async (req, res, next) => {
  try {
    const { page, limit, offset } = paginate(req.query.page, req.query.limit);
    const { status } = req.query;

    let whereClause = 'WHERE o.buyer_id = $1';
    const params = [req.user.id];
    let paramIndex = 2;

    if (status) {
      whereClause += ` AND o.status = $${paramIndex}`;
      params.push(status);
      paramIndex++;
    }

    const countResult = await db.query(`SELECT COUNT(*) FROM orders o ${whereClause}`, params);
    const total = parseInt(countResult.rows[0].count);

    params.push(limit, offset);
    const result = await db.query(
      `SELECT o.*, s.name as store_name, s.slug as store_slug,
       (SELECT json_agg(json_build_object('id', oi.id, 'product_name', oi.product_name,
        'product_price', oi.product_price, 'quantity', oi.quantity, 'total', oi.total))
        FROM order_items oi WHERE oi.order_id = o.id) as items
       FROM orders o
       JOIN stores s ON o.store_id = s.id
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

const getOrder = async (req, res, next) => {
  try {
    const { id } = req.params;

    const result = await db.query(
      `SELECT o.*, s.name as store_name, s.slug as store_slug, s.phone as store_phone,
       p.method as payment_method, p.status as payment_status
       FROM orders o
       JOIN stores s ON o.store_id = s.id
       LEFT JOIN payments p ON p.order_id = o.id
       WHERE o.id = $1 AND (o.buyer_id = $2 OR o.store_id IN (SELECT id FROM stores WHERE user_id = $2))`,
      [id, req.user.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Order not found' });
    }

    const items = await db.query(
      `SELECT oi.*, 
       (SELECT url FROM product_images pi WHERE pi.product_id = oi.product_id AND pi.is_primary = true LIMIT 1) as product_image
       FROM order_items oi WHERE oi.order_id = $1`,
      [id]
    );

    res.json({ order: { ...result.rows[0], items: items.rows } });
  } catch (err) {
    next(err);
  }
};

const getStoreOrders = async (req, res, next) => {
  try {
    const { page, limit, offset } = paginate(req.query.page, req.query.limit);
    const { status } = req.query;

    const store = await db.query('SELECT id FROM stores WHERE user_id = $1', [req.user.id]);
    if (store.rows.length === 0) {
      return res.status(404).json({ error: 'Store not found' });
    }

    let whereClause = 'WHERE o.store_id = $1';
    const params = [store.rows[0].id];
    let paramIndex = 2;

    if (status) {
      whereClause += ` AND o.status = $${paramIndex}`;
      params.push(status);
      paramIndex++;
    }

    const countResult = await db.query(`SELECT COUNT(*) FROM orders o ${whereClause}`, params);
    const total = parseInt(countResult.rows[0].count);

    params.push(limit, offset);
    const result = await db.query(
      `SELECT o.*, u.first_name as buyer_first_name, u.last_name as buyer_last_name,
       u.phone as buyer_phone,
       (SELECT json_agg(json_build_object('id', oi.id, 'product_name', oi.product_name,
        'product_price', oi.product_price, 'quantity', oi.quantity, 'total', oi.total))
        FROM order_items oi WHERE oi.order_id = o.id) as items
       FROM orders o
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

const updateOrderStatus = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { status, cancelled_reason } = req.body;

    const allowedStatuses = ['pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded'];
    if (!allowedStatuses.includes(status)) {
      return res.status(400).json({ error: 'Invalid order status' });
    }

    const orderResult = await db.query(
      'SELECT id, buyer_id, store_id, status FROM orders WHERE id = $1',
      [id]
    );

    if (orderResult.rows.length === 0) {
      return res.status(404).json({ error: 'Order not found' });
    }

    const currentOrder = orderResult.rows[0];
    const isBuyerOwner = currentOrder.buyer_id === req.user.id;

    const sellerOwnsStore = await db.query(
      'SELECT 1 FROM stores WHERE id = $1 AND user_id = $2 LIMIT 1',
      [currentOrder.store_id, req.user.id]
    );
    const isSellerOwner = sellerOwnsStore.rows.length > 0;

    if (!isBuyerOwner && !isSellerOwner) {
      return res.status(403).json({ error: 'You are not allowed to update this order' });
    }

    // Buyers can only cancel their own orders.
    if (isBuyerOwner && !isSellerOwner && status !== 'cancelled') {
      return res.status(403).json({ error: 'You can only cancel your orders' });
    }

    // Prevent invalid repeated or late cancellation.
    if (status === 'cancelled') {
      if (currentOrder.status === 'cancelled') {
        return res.status(400).json({ error: 'Order is already cancelled' });
      }

      if (currentOrder.status === 'delivered') {
        return res.status(400).json({ error: 'Delivered orders cannot be cancelled' });
      }
    }

    const timestampField = {
      confirmed: 'confirmed_at',
      shipped: 'shipped_at',
      delivered: 'delivered_at',
      cancelled: 'cancelled_at',
    }[status];

    const updates = ['status = $1', 'updated_at = CURRENT_TIMESTAMP'];
    const updateParams = [status];
    let nextParamIndex = 2;

    if (timestampField) {
      updates.push(`${timestampField} = CURRENT_TIMESTAMP`);
    }

    if (cancelled_reason !== undefined) {
      updates.push(`cancelled_reason = $${nextParamIndex}`);
      updateParams.push(cancelled_reason);
      nextParamIndex++;
    }

    const result = await db.query(
      `UPDATE orders SET ${updates.join(', ')} WHERE id = $${updateParams.length + 1} RETURNING *`,
      [...updateParams, id]
    );

    // If cancelled, restore stock
    if (status === 'cancelled' && currentOrder.status !== 'cancelled') {
      const items = await db.query('SELECT product_id, quantity FROM order_items WHERE order_id = $1', [id]);
      for (const item of items.rows) {
        await db.query(
          'UPDATE products SET quantity = quantity + $1, total_sold = total_sold - $1 WHERE id = $2',
          [item.quantity, item.product_id]
        );
      }
    }

    res.json({ message: 'Order status updated', order: result.rows[0] });
  } catch (err) {
    next(err);
  }
};

module.exports = { createOrder, getOrders, getOrder, getStoreOrders, updateOrderStatus };
