const db = require('../config/database');
const { generateSlug, paginate, buildPaginationResponse } = require('../utils/helpers');

const createProduct = async (req, res, next) => {
  try {
    const { name, description, price, original_price, quantity, category_id, condition,
      warranty, sku, min_order, weight, dimensions, is_wholesale, wholesale_price,
      wholesale_min_qty, fitments, oem_numbers } = req.body;

    // Backward compatibility for older mobile payload keys.
    const normalizedOriginalPrice = original_price ?? req.body.old_price;
    const normalizedWarranty = warranty ?? req.body.warranty_info;

    let parsedFitments = fitments;
    if (typeof parsedFitments === 'string') {
      try {
        parsedFitments = JSON.parse(parsedFitments);
      } catch (error) {
        parsedFitments = [];
      }
    }

    let parsedOemNumbers = oem_numbers;
    if (typeof parsedOemNumbers === 'string') {
      try {
        parsedOemNumbers = JSON.parse(parsedOemNumbers);
      } catch (error) {
        parsedOemNumbers = [];
      }
    }

    // Accept OEM entries as either strings (["123"]) or objects ({ number, manufacturer }).
    const normalizedOemNumbers = Array.isArray(parsedOemNumbers)
      ? parsedOemNumbers
          .map((oem) => {
            if (typeof oem === 'string') {
              return { number: oem, manufacturer: null };
            }
            if (oem && typeof oem === 'object') {
              return {
                number: oem.number ?? oem.oem_number,
                manufacturer: oem.manufacturer ?? null,
              };
            }
            return null;
          })
          .filter((oem) => oem && typeof oem.number !== 'undefined' && oem.number !== null)
          .map((oem) => ({
            number: String(oem.number).trim(),
            manufacturer: oem.manufacturer ? String(oem.manufacturer).trim() : null,
          }))
          .filter((oem) => oem.number.length > 0)
      : [];

    // Get seller's store
    const store = await db.query('SELECT id FROM stores WHERE user_id = $1', [req.user.id]);
    if (store.rows.length === 0) {
      return res.status(400).json({ error: 'You must create a store first' });
    }
    const storeId = store.rows[0].id;

    const slug = generateSlug(name) + '-' + Date.now().toString(36);

    const result = await db.query(
      `INSERT INTO products (store_id, category_id, name, slug, description, price, original_price,
       quantity, min_order, sku, condition, warranty, weight, dimensions, is_wholesale,
       wholesale_price, wholesale_min_qty)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
       RETURNING *`,
      [storeId, category_id, name, slug, description, price, normalizedOriginalPrice,
        quantity || 0, min_order || 1, sku, condition || 'new', normalizedWarranty, weight,
        dimensions, is_wholesale || false, wholesale_price, wholesale_min_qty]
    );

    const product = result.rows[0];

    // Add fitments
    if (parsedFitments && Array.isArray(parsedFitments)) {
      for (const fitment of parsedFitments) {
        await db.query(
          `INSERT INTO product_fitments (product_id, brand_id, model_id, year_start, year_end, notes)
           VALUES ($1, $2, $3, $4, $5, $6)`,
          [product.id, fitment.brand_id, fitment.model_id, fitment.year_start, fitment.year_end, fitment.notes]
        );
      }
    }

    // Add OEM references
    if (normalizedOemNumbers.length > 0) {
      for (const oem of normalizedOemNumbers) {
        await db.query(
          `INSERT INTO oem_references (product_id, oem_number, manufacturer)
           VALUES ($1, $2, $3)`,
          [product.id, oem.number, oem.manufacturer]
        );
      }
    }

    // Handle uploaded images
    if (req.files && req.files.length > 0) {
      for (let i = 0; i < req.files.length; i++) {
        await db.query(
          `INSERT INTO product_images (product_id, url, sort_order, is_primary)
           VALUES ($1, $2, $3, $4)`,
          [product.id, `/uploads/${req.files[i].filename}`, i, i === 0]
        );
      }
    }

    res.status(201).json({ message: 'Product created', product });
  } catch (err) {
    next(err);
  }
};

const getProduct = async (req, res, next) => {
  try {
    const { id } = req.params;
    const isUUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id);

    let result;
    if (isUUID) {
      result = await db.query(
        `SELECT p.*, c.name as category_name, s.name as store_name, s.slug as store_slug,
         s.wilaya as store_wilaya, s.rating as store_rating
         FROM products p
         LEFT JOIN categories c ON p.category_id = c.id
         JOIN stores s ON p.store_id = s.id
         WHERE p.id = $1`, [id]
      );
    } else {
      result = await db.query(
        `SELECT p.*, c.name as category_name, s.name as store_name, s.slug as store_slug,
         s.wilaya as store_wilaya, s.rating as store_rating
         FROM products p
         LEFT JOIN categories c ON p.category_id = c.id
         JOIN stores s ON p.store_id = s.id
         WHERE p.slug = $1`, [id]
      );
    }

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }

    const product = result.rows[0];

    // Increment views
    await db.query('UPDATE products SET views = views + 1 WHERE id = $1', [product.id]);

    // Get images
    const images = await db.query(
      'SELECT * FROM product_images WHERE product_id = $1 ORDER BY sort_order', [product.id]
    );

    // Get fitments
    const fitments = await db.query(
      `SELECT pf.*, vb.name as brand_name, vm.name as model_name
       FROM product_fitments pf
       LEFT JOIN vehicle_brands vb ON pf.brand_id = vb.id
       LEFT JOIN vehicle_models vm ON pf.model_id = vm.id
       WHERE pf.product_id = $1`, [product.id]
    );

    // Get OEM references
    const oems = await db.query(
      'SELECT * FROM oem_references WHERE product_id = $1', [product.id]
    );

    // Get reviews
    const reviews = await db.query(
      `SELECT pr.*, u.first_name, u.last_name, u.avatar
       FROM product_reviews pr
       JOIN users u ON pr.user_id = u.id
       WHERE pr.product_id = $1 AND pr.is_active = true
       ORDER BY pr.created_at DESC LIMIT 10`, [product.id]
    );

    res.json({
      product: {
        ...product,
        images: images.rows,
        fitments: fitments.rows,
        oem_references: oems.rows,
        reviews: reviews.rows,
      },
    });
  } catch (err) {
    next(err);
  }
};

const updateProduct = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { name, description, price, original_price, quantity, category_id, condition,
      warranty, sku, is_active, is_featured } = req.body;

    // Verify ownership
    const store = await db.query('SELECT id FROM stores WHERE user_id = $1', [req.user.id]);
    if (store.rows.length === 0) {
      return res.status(403).json({ error: 'Store not found' });
    }

    const result = await db.query(
      `UPDATE products SET
       name = COALESCE($1, name), description = COALESCE($2, description),
       price = COALESCE($3, price), original_price = COALESCE($4, original_price),
       quantity = COALESCE($5, quantity), category_id = COALESCE($6, category_id),
       condition = COALESCE($7, condition), warranty = COALESCE($8, warranty),
       sku = COALESCE($9, sku), is_active = COALESCE($10, is_active),
       is_featured = COALESCE($11, is_featured), updated_at = CURRENT_TIMESTAMP
       WHERE id = $12 AND store_id = $13
       RETURNING *`,
      [name, description, price, original_price, quantity, category_id, condition,
        warranty, sku, is_active, is_featured, id, store.rows[0].id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Product not found or access denied' });
    }

    res.json({ message: 'Product updated', product: result.rows[0] });
  } catch (err) {
    next(err);
  }
};

const deleteProduct = async (req, res, next) => {
  try {
    const { id } = req.params;

    const store = await db.query('SELECT id FROM stores WHERE user_id = $1', [req.user.id]);
    if (store.rows.length === 0) {
      return res.status(403).json({ error: 'Store not found' });
    }

    const result = await db.query(
      'UPDATE products SET is_active = false, updated_at = CURRENT_TIMESTAMP WHERE id = $1 AND store_id = $2 RETURNING id',
      [id, store.rows[0].id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }

    res.json({ message: 'Product deleted' });
  } catch (err) {
    next(err);
  }
};

const listProducts = async (req, res, next) => {
  try {
    const { page, limit, offset } = paginate(req.query.page, req.query.limit);
    const { category, store_id, wilaya, condition, min_price, max_price, brand_id,
      model_id, year, sort, featured, vehicle_type } = req.query;

    let whereClause = 'WHERE p.is_active = true';
    const params = [];
    let paramIndex = 1;

    if (category) {
      whereClause += ` AND c.slug = $${paramIndex}`;
      params.push(category);
      paramIndex++;
    }
    if (store_id) {
      whereClause += ` AND p.store_id = $${paramIndex}`;
      params.push(store_id);
      paramIndex++;
    }
    if (wilaya) {
      whereClause += ` AND s.wilaya = $${paramIndex}`;
      params.push(wilaya);
      paramIndex++;
    }
    if (condition) {
      whereClause += ` AND p.condition = $${paramIndex}`;
      params.push(condition);
      paramIndex++;
    }
    if (min_price) {
      whereClause += ` AND p.price >= $${paramIndex}`;
      params.push(min_price);
      paramIndex++;
    }
    if (max_price) {
      whereClause += ` AND p.price <= $${paramIndex}`;
      params.push(max_price);
      paramIndex++;
    }
    if (featured === 'true') {
      whereClause += ' AND p.is_featured = true';
    }
    if (brand_id) {
      whereClause += ` AND EXISTS (SELECT 1 FROM product_fitments pf WHERE pf.product_id = p.id AND pf.brand_id = $${paramIndex})`;
      params.push(brand_id);
      paramIndex++;
    }
    if (model_id) {
      whereClause += ` AND EXISTS (SELECT 1 FROM product_fitments pf WHERE pf.product_id = p.id AND pf.model_id = $${paramIndex})`;
      params.push(model_id);
      paramIndex++;
    }
    if (year) {
      whereClause += ` AND EXISTS (SELECT 1 FROM product_fitments pf WHERE pf.product_id = p.id AND $${paramIndex} BETWEEN pf.year_start AND pf.year_end)`;
      params.push(parseInt(year));
      paramIndex++;
    }
    if (vehicle_type) {
      whereClause += ` AND EXISTS (SELECT 1 FROM product_fitments pf JOIN vehicle_brands vb ON pf.brand_id = vb.id WHERE pf.product_id = p.id AND vb.vehicle_type = $${paramIndex})`;
      params.push(vehicle_type);
      paramIndex++;
    }

    let orderBy = 'ORDER BY p.created_at DESC';
    if (sort === 'price_asc') orderBy = 'ORDER BY p.price ASC';
    else if (sort === 'price_desc') orderBy = 'ORDER BY p.price DESC';
    else if (sort === 'rating') orderBy = 'ORDER BY p.rating DESC';
    else if (sort === 'popular') orderBy = 'ORDER BY p.total_sold DESC';
    else if (sort === 'views') orderBy = 'ORDER BY p.views DESC';

    const countParams = [...params];
    const countResult = await db.query(
      `SELECT COUNT(*) FROM products p
       LEFT JOIN categories c ON p.category_id = c.id
       JOIN stores s ON p.store_id = s.id
       ${whereClause}`, countParams
    );
    const total = parseInt(countResult.rows[0].count);

    params.push(limit, offset);
    const result = await db.query(
      `SELECT p.*, c.name as category_name, s.name as store_name, s.slug as store_slug,
       s.wilaya as store_wilaya,
       (SELECT url FROM product_images pi WHERE pi.product_id = p.id AND pi.is_primary = true LIMIT 1) as primary_image
       FROM products p
       LEFT JOIN categories c ON p.category_id = c.id
       JOIN stores s ON p.store_id = s.id
       ${whereClause}
       ${orderBy}
       LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
      params
    );

    res.json(buildPaginationResponse(result.rows, total, page, limit));
  } catch (err) {
    next(err);
  }
};

const searchProducts = async (req, res, next) => {
  try {
    const { page, limit, offset } = paginate(req.query.page, req.query.limit);
    const { q } = req.query;

    if (!q || q.trim().length < 2) {
      return res.status(400).json({ error: 'Search query must be at least 2 characters' });
    }

    const searchTerm = `%${q.trim()}%`;

    const countResult = await db.query(
      `SELECT COUNT(*) FROM products p
       LEFT JOIN categories c ON p.category_id = c.id
       JOIN stores s ON p.store_id = s.id
       WHERE p.is_active = true AND (
         p.name ILIKE $1 OR p.description ILIKE $1 OR c.name ILIKE $1
         OR EXISTS (SELECT 1 FROM oem_references o WHERE o.product_id = p.id AND o.oem_number ILIKE $1)
       )`,
      [searchTerm]
    );
    const total = parseInt(countResult.rows[0].count);

    const result = await db.query(
      `SELECT p.*, c.name as category_name, s.name as store_name, s.slug as store_slug,
       s.wilaya as store_wilaya,
       (SELECT url FROM product_images pi WHERE pi.product_id = p.id AND pi.is_primary = true LIMIT 1) as primary_image
       FROM products p
       LEFT JOIN categories c ON p.category_id = c.id
       JOIN stores s ON p.store_id = s.id
       WHERE p.is_active = true AND (
         p.name ILIKE $1 OR p.description ILIKE $1 OR c.name ILIKE $1
         OR EXISTS (SELECT 1 FROM oem_references o WHERE o.product_id = p.id AND o.oem_number ILIKE $1)
       )
       ORDER BY p.created_at DESC
       LIMIT $2 OFFSET $3`,
      [searchTerm, limit, offset]
    );

    res.json(buildPaginationResponse(result.rows, total, page, limit));
  } catch (err) {
    next(err);
  }
};

const getMyProducts = async (req, res, next) => {
  try {
    const { page, limit, offset } = paginate(req.query.page, req.query.limit);

    const store = await db.query('SELECT id FROM stores WHERE user_id = $1', [req.user.id]);
    if (store.rows.length === 0) {
      return res.status(404).json({ error: 'Store not found' });
    }

    const storeId = store.rows[0].id;
    const countResult = await db.query('SELECT COUNT(*) FROM products WHERE store_id = $1', [storeId]);
    const total = parseInt(countResult.rows[0].count);

    const result = await db.query(
      `SELECT p.*, c.name as category_name,
       (SELECT url FROM product_images pi WHERE pi.product_id = p.id AND pi.is_primary = true LIMIT 1) as primary_image
       FROM products p
       LEFT JOIN categories c ON p.category_id = c.id
       WHERE p.store_id = $1
       ORDER BY p.created_at DESC
       LIMIT $2 OFFSET $3`,
      [storeId, limit, offset]
    );

    res.json(buildPaginationResponse(result.rows, total, page, limit));
  } catch (err) {
    next(err);
  }
};

module.exports = { createProduct, getProduct, updateProduct, deleteProduct, listProducts, searchProducts, getMyProducts };
