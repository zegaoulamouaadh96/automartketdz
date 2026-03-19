const bcrypt = require('bcryptjs');
const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME || 'automarket_dz',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
});

async function createFounder() {
  const client = await pool.connect();
  try {
    await client.query('CREATE EXTENSION IF NOT EXISTS "uuid-ossp";');

    // Update role constraint to support founder and employee
    await client.query(`
      ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
      ALTER TABLE users ADD CONSTRAINT users_role_check 
        CHECK (role IN ('buyer', 'seller', 'supplier', 'admin', 'founder', 'employee'));
    `);
    console.log('✅ Role constraint updated');

    // Create notifications table if not exists
    await client.query(`
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
    `);
    console.log('✅ Notifications table ready');

    // Create founder account
    const password = await bcrypt.hash('5E76LMTMD33', 10);
    const result = await client.query(`
      INSERT INTO users (email, password, first_name, last_name, phone, role, wilaya, is_active, is_verified)
      VALUES ($1, $2, $3, $4, $5, 'founder', $6, true, true)
      ON CONFLICT (email) DO UPDATE SET
        password = EXCLUDED.password,
        first_name = EXCLUDED.first_name,
        last_name = EXCLUDED.last_name,
        phone = EXCLUDED.phone,
        role = 'founder',
        wilaya = EXCLUDED.wilaya,
        is_active = true,
        is_verified = true
      RETURNING id, email, role
    `, ['zegaoulamouaadh@gmail.com', password, 'Mouaadh', 'Zegaoula', '0555999999', 'Alger']);

    console.log('✅ Founder account created/updated:', result.rows[0]);
  } catch (err) {
    console.error('❌ Error:', err.message);
  } finally {
    client.release();
    await pool.end();
  }
}

createFounder().then(() => {
  process.exit(0);
}).catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
