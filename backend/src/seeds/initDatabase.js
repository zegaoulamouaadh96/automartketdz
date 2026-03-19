const { Pool } = require('pg');
require('dotenv').config();

const config = {
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT) || 5432,
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
};

async function initDatabase() {
  // Connect without database to create it
  const adminPool = new Pool({ ...config, database: 'postgres' });

  try {
    const dbName = process.env.DB_NAME || 'automarket_dz';
    const res = await adminPool.query(`SELECT 1 FROM pg_database WHERE datname = $1`, [dbName]);
    if (res.rows.length === 0) {
      await adminPool.query(`CREATE DATABASE ${dbName}`);
      console.log(`✅ Database "${dbName}" created`);
    } else {
      console.log(`ℹ️  Database "${dbName}" already exists`);
    }
  } catch (err) {
    console.error('❌ Error creating database:', err.message);
  } finally {
    await adminPool.end();
  }

  // Now connect to the new database and create tables
  const pool = new Pool({ ...config, database: process.env.DB_NAME || 'automarket_dz' });

  const schema = `
    -- Enable UUID extension
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

    -- ============================================
    -- USERS
    -- ============================================
    CREATE TABLE IF NOT EXISTS users (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      email VARCHAR(255) UNIQUE NOT NULL,
      password VARCHAR(255) NOT NULL,
      first_name VARCHAR(100) NOT NULL,
      last_name VARCHAR(100) NOT NULL,
      phone VARCHAR(20),
      avatar VARCHAR(500),
      role VARCHAR(20) NOT NULL DEFAULT 'buyer' CHECK (role IN ('buyer', 'seller', 'supplier', 'admin', 'founder', 'employee')),
      wilaya VARCHAR(100),
      address TEXT,
      is_active BOOLEAN DEFAULT true,
      is_verified BOOLEAN DEFAULT false,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- ============================================
    -- STORES
    -- ============================================
    CREATE TABLE IF NOT EXISTS stores (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      name VARCHAR(255) NOT NULL,
      slug VARCHAR(255) UNIQUE NOT NULL,
      description TEXT,
      logo VARCHAR(500),
      banner VARCHAR(500),
      phone VARCHAR(20),
      email VARCHAR(255),
      wilaya VARCHAR(100),
      address TEXT,
      is_active BOOLEAN DEFAULT true,
      is_verified BOOLEAN DEFAULT false,
      rating DECIMAL(3,2) DEFAULT 0,
      total_reviews INTEGER DEFAULT 0,
      total_sales INTEGER DEFAULT 0,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- ============================================
    -- CATEGORIES
    -- ============================================
    CREATE TABLE IF NOT EXISTS categories (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      name VARCHAR(255) NOT NULL,
      name_ar VARCHAR(255),
      slug VARCHAR(255) UNIQUE NOT NULL,
      description TEXT,
      icon VARCHAR(500),
      parent_id UUID REFERENCES categories(id) ON DELETE SET NULL,
      sort_order INTEGER DEFAULT 0,
      is_active BOOLEAN DEFAULT true,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- ============================================
    -- VEHICLE BRANDS
    -- ============================================
    CREATE TABLE IF NOT EXISTS vehicle_brands (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      name VARCHAR(255) NOT NULL,
      slug VARCHAR(255) UNIQUE NOT NULL,
      logo VARCHAR(500),
      vehicle_type VARCHAR(20) NOT NULL CHECK (vehicle_type IN ('car', 'truck', 'motorcycle')),
      is_active BOOLEAN DEFAULT true,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- ============================================
    -- VEHICLE MODELS
    -- ============================================
    CREATE TABLE IF NOT EXISTS vehicle_models (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      brand_id UUID NOT NULL REFERENCES vehicle_brands(id) ON DELETE CASCADE,
      name VARCHAR(255) NOT NULL,
      slug VARCHAR(255) NOT NULL,
      is_active BOOLEAN DEFAULT true,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(brand_id, slug)
    );

    -- ============================================
    -- VEHICLE YEARS
    -- ============================================
    CREATE TABLE IF NOT EXISTS vehicle_years (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      model_id UUID NOT NULL REFERENCES vehicle_models(id) ON DELETE CASCADE,
      year INTEGER NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(model_id, year)
    );

    -- ============================================
    -- PRODUCTS
    -- ============================================
    CREATE TABLE IF NOT EXISTS products (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
      category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
      name VARCHAR(500) NOT NULL,
      slug VARCHAR(500) NOT NULL,
      description TEXT,
      price DECIMAL(12,2) NOT NULL,
      original_price DECIMAL(12,2),
      quantity INTEGER DEFAULT 0,
      min_order INTEGER DEFAULT 1,
      sku VARCHAR(100),
      condition VARCHAR(20) DEFAULT 'new' CHECK (condition IN ('new', 'used', 'refurbished')),
      warranty VARCHAR(255),
      weight DECIMAL(10,2),
      dimensions VARCHAR(100),
      is_active BOOLEAN DEFAULT true,
      is_featured BOOLEAN DEFAULT false,
      is_wholesale BOOLEAN DEFAULT false,
      wholesale_price DECIMAL(12,2),
      wholesale_min_qty INTEGER,
      rating DECIMAL(3,2) DEFAULT 0,
      total_reviews INTEGER DEFAULT 0,
      total_sold INTEGER DEFAULT 0,
      views INTEGER DEFAULT 0,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- ============================================
    -- PRODUCT IMAGES
    -- ============================================
    CREATE TABLE IF NOT EXISTS product_images (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
      url VARCHAR(500) NOT NULL,
      alt_text VARCHAR(255),
      sort_order INTEGER DEFAULT 0,
      is_primary BOOLEAN DEFAULT false,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- ============================================
    -- PRODUCT FITMENTS (which vehicles a part fits)
    -- ============================================
    CREATE TABLE IF NOT EXISTS product_fitments (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
      brand_id UUID REFERENCES vehicle_brands(id) ON DELETE SET NULL,
      model_id UUID REFERENCES vehicle_models(id) ON DELETE SET NULL,
      year_start INTEGER,
      year_end INTEGER,
      notes TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- ============================================
    -- OEM REFERENCES
    -- ============================================
    CREATE TABLE IF NOT EXISTS oem_references (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
      oem_number VARCHAR(255) NOT NULL,
      manufacturer VARCHAR(255),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- ============================================
    -- ORDERS
    -- ============================================
    CREATE TABLE IF NOT EXISTS orders (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      order_number VARCHAR(50) UNIQUE NOT NULL,
      buyer_id UUID NOT NULL REFERENCES users(id),
      store_id UUID NOT NULL REFERENCES stores(id),
      status VARCHAR(30) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded')),
      subtotal DECIMAL(12,2) NOT NULL,
      shipping_cost DECIMAL(12,2) DEFAULT 0,
      total DECIMAL(12,2) NOT NULL,
      shipping_wilaya VARCHAR(100),
      shipping_address TEXT,
      shipping_phone VARCHAR(20),
      shipping_name VARCHAR(255),
      notes TEXT,
      cancelled_reason TEXT,
      confirmed_at TIMESTAMP,
      shipped_at TIMESTAMP,
      delivered_at TIMESTAMP,
      cancelled_at TIMESTAMP,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- ============================================
    -- ORDER ITEMS
    -- ============================================
    CREATE TABLE IF NOT EXISTS order_items (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
      product_id UUID NOT NULL REFERENCES products(id),
      product_name VARCHAR(500),
      product_price DECIMAL(12,2) NOT NULL,
      quantity INTEGER NOT NULL,
      total DECIMAL(12,2) NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- ============================================
    -- PAYMENTS
    -- ============================================
    CREATE TABLE IF NOT EXISTS payments (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
      method VARCHAR(50) NOT NULL CHECK (method IN ('cash_on_delivery', 'ccp', 'baridimob', 'bank_transfer')),
      status VARCHAR(30) DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
      amount DECIMAL(12,2) NOT NULL,
      reference VARCHAR(255),
      notes TEXT,
      paid_at TIMESTAMP,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- ============================================
    -- CONVERSATIONS
    -- ============================================
    CREATE TABLE IF NOT EXISTS conversations (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      buyer_id UUID NOT NULL REFERENCES users(id),
      seller_id UUID NOT NULL REFERENCES users(id),
      product_id UUID REFERENCES products(id) ON DELETE SET NULL,
      last_message TEXT,
      last_message_at TIMESTAMP,
      buyer_unread INTEGER DEFAULT 0,
      seller_unread INTEGER DEFAULT 0,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(buyer_id, seller_id, product_id)
    );

    -- ============================================
    -- MESSAGES
    -- ============================================
    CREATE TABLE IF NOT EXISTS messages (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
      sender_id UUID NOT NULL REFERENCES users(id),
      content TEXT NOT NULL,
      is_read BOOLEAN DEFAULT false,
      read_at TIMESTAMP,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- ============================================
    -- PRODUCT REVIEWS
    -- ============================================
    CREATE TABLE IF NOT EXISTS product_reviews (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
      user_id UUID NOT NULL REFERENCES users(id),
      rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
      comment TEXT,
      is_verified_purchase BOOLEAN DEFAULT false,
      is_active BOOLEAN DEFAULT true,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(product_id, user_id)
    );

    -- ============================================
    -- STORE REVIEWS
    -- ============================================
    CREATE TABLE IF NOT EXISTS store_reviews (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
      user_id UUID NOT NULL REFERENCES users(id),
      rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
      comment TEXT,
      is_active BOOLEAN DEFAULT true,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(store_id, user_id)
    );

    -- ============================================
    -- REPORTS
    -- ============================================
    CREATE TABLE IF NOT EXISTS reports (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      reporter_id UUID NOT NULL REFERENCES users(id),
      type VARCHAR(30) NOT NULL CHECK (type IN ('product', 'store', 'user', 'review')),
      target_id UUID NOT NULL,
      reason VARCHAR(50) NOT NULL,
      description TEXT,
      status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'reviewing', 'resolved', 'dismissed')),
      admin_notes TEXT,
      resolved_by UUID REFERENCES users(id),
      resolved_at TIMESTAMP,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- ============================================
    -- AUDIT LOGS
    -- ============================================
    CREATE TABLE IF NOT EXISTS audit_logs (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      user_id UUID REFERENCES users(id),
      action VARCHAR(100) NOT NULL,
      entity_type VARCHAR(50),
      entity_id UUID,
      old_values JSONB,
      new_values JSONB,
      ip_address VARCHAR(45),
      user_agent TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- ============================================
    -- SUPPLIERS
    -- ============================================
    CREATE TABLE IF NOT EXISTS suppliers (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      company_name VARCHAR(255) NOT NULL,
      slug VARCHAR(255) UNIQUE NOT NULL,
      description TEXT,
      logo VARCHAR(500),
      phone VARCHAR(20),
      email VARCHAR(255),
      wilaya VARCHAR(100),
      address TEXT,
      is_active BOOLEAN DEFAULT true,
      is_verified BOOLEAN DEFAULT false,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- ============================================
    -- SUPPLY ORDERS
    -- ============================================
    CREATE TABLE IF NOT EXISTS supply_orders (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      order_number VARCHAR(50) UNIQUE NOT NULL,
      seller_id UUID NOT NULL REFERENCES users(id),
      supplier_id UUID NOT NULL REFERENCES suppliers(id),
      status VARCHAR(30) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled')),
      subtotal DECIMAL(12,2) NOT NULL,
      shipping_cost DECIMAL(12,2) DEFAULT 0,
      total DECIMAL(12,2) NOT NULL,
      notes TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- ============================================
    -- SUPPLY ORDER ITEMS
    -- ============================================
    CREATE TABLE IF NOT EXISTS supply_order_items (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      supply_order_id UUID NOT NULL REFERENCES supply_orders(id) ON DELETE CASCADE,
      product_id UUID NOT NULL REFERENCES products(id),
      product_name VARCHAR(500),
      unit_price DECIMAL(12,2) NOT NULL,
      quantity INTEGER NOT NULL,
      total DECIMAL(12,2) NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- ============================================
    -- WISHLISTS
    -- ============================================
    CREATE TABLE IF NOT EXISTS wishlists (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(user_id, product_id)
    );

    -- ============================================
    -- INDEXES
    -- ============================================
    -- ============================================
    -- NOTIFICATIONS
    -- ============================================
    CREATE TABLE IF NOT EXISTS notifications (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      user_id UUID REFERENCES users(id) ON DELETE CASCADE,
      title VARCHAR(255) NOT NULL,
      message TEXT NOT NULL,
      type VARCHAR(30) NOT NULL DEFAULT 'info',
      is_read BOOLEAN DEFAULT false,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
    CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(user_id, is_read);

    CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
    CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
    CREATE INDEX IF NOT EXISTS idx_stores_user_id ON stores(user_id);
    CREATE INDEX IF NOT EXISTS idx_stores_slug ON stores(slug);
    CREATE INDEX IF NOT EXISTS idx_stores_wilaya ON stores(wilaya);
    CREATE INDEX IF NOT EXISTS idx_categories_slug ON categories(slug);
    CREATE INDEX IF NOT EXISTS idx_categories_parent ON categories(parent_id);
    CREATE INDEX IF NOT EXISTS idx_products_store ON products(store_id);
    CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id);
    CREATE INDEX IF NOT EXISTS idx_products_slug ON products(slug);
    CREATE INDEX IF NOT EXISTS idx_products_price ON products(price);
    CREATE INDEX IF NOT EXISTS idx_products_condition ON products(condition);
    CREATE INDEX IF NOT EXISTS idx_product_fitments_product ON product_fitments(product_id);
    CREATE INDEX IF NOT EXISTS idx_product_fitments_brand ON product_fitments(brand_id);
    CREATE INDEX IF NOT EXISTS idx_product_fitments_model ON product_fitments(model_id);
    CREATE INDEX IF NOT EXISTS idx_oem_references_product ON oem_references(product_id);
    CREATE INDEX IF NOT EXISTS idx_oem_references_number ON oem_references(oem_number);
    CREATE INDEX IF NOT EXISTS idx_orders_buyer ON orders(buyer_id);
    CREATE INDEX IF NOT EXISTS idx_orders_store ON orders(store_id);
    CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
    CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);
    CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id);
    CREATE INDEX IF NOT EXISTS idx_conversations_buyer ON conversations(buyer_id);
    CREATE INDEX IF NOT EXISTS idx_conversations_seller ON conversations(seller_id);
    CREATE INDEX IF NOT EXISTS idx_product_reviews_product ON product_reviews(product_id);
    CREATE INDEX IF NOT EXISTS idx_store_reviews_store ON store_reviews(store_id);
    CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id);
    CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
  `;

  try {
    await pool.query(schema);
    console.log('✅ All tables created successfully');
  } catch (err) {
    console.error('❌ Error creating tables:', err.message);
  } finally {
    await pool.end();
  }
}

initDatabase().then(() => {
  console.log('🏁 Database initialization complete');
  process.exit(0);
}).catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
