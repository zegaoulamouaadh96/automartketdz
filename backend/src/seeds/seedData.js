const bcrypt = require('bcryptjs');
const { Pool } = require('pg');
const { v4: uuidv4 } = require('uuid');
require('dotenv').config();

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME || 'automarket_dz',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
});

const wilayas = [
  'Adrar', 'Chlef', 'Laghouat', 'Oum El Bouaghi', 'Batna', 'Béjaïa', 'Biskra',
  'Béchar', 'Blida', 'Bouira', 'Tamanrasset', 'Tébessa', 'Tlemcen', 'Tiaret',
  'Tizi Ouzou', 'Alger', 'Djelfa', 'Jijel', 'Sétif', 'Saïda', 'Skikda',
  'Sidi Bel Abbès', 'Annaba', 'Guelma', 'Constantine', 'Médéa', 'Mostaganem',
  'M\'Sila', 'Mascara', 'Ouargla', 'Oran', 'El Bayadh', 'Illizi', 'Bordj Bou Arreridj',
  'Boumerdès', 'El Tarf', 'Tindouf', 'Tissemsilt', 'El Oued', 'Khenchela',
  'Souk Ahras', 'Tipaza', 'Mila', 'Aïn Defla', 'Naâma', 'Aïn Témouchent',
  'Ghardaïa', 'Relizane'
];

async function seedData() {
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');

    // Create founder account
    const founderPassword = await bcrypt.hash('5E76LMTMD33', 10);
    const founderId = uuidv4();
    await client.query(`
      INSERT INTO users (id, email, password, first_name, last_name, phone, role, wilaya, is_active, is_verified)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, true, true)
      ON CONFLICT (email) DO NOTHING
    `, [founderId, 'zegaoulamouaadh@gmail.com', founderPassword, 'Mouaadh', 'Zegaoula', '0555999999', 'founder', 'Alger']);

    // Create admin user
    const adminPassword = await bcrypt.hash('admin123', 10);
    const adminId = uuidv4();
    await client.query(`
      INSERT INTO users (id, email, password, first_name, last_name, phone, role, wilaya, is_active, is_verified)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, true, true)
      ON CONFLICT (email) DO NOTHING
    `, [adminId, 'admin@automarket.dz', adminPassword, 'Admin', 'AutoMarket', '0555000000', 'admin', 'Alger']);

    // Create sample seller
    const sellerPassword = await bcrypt.hash('seller123', 10);
    const sellerId = uuidv4();
    await client.query(`
      INSERT INTO users (id, email, password, first_name, last_name, phone, role, wilaya, is_active, is_verified)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, true, true)
      ON CONFLICT (email) DO NOTHING
    `, [sellerId, 'seller@automarket.dz', sellerPassword, 'Ahmed', 'Bensalem', '0555111111', 'seller', 'Alger']);

    // Create sample buyer
    const buyerPassword = await bcrypt.hash('buyer123', 10);
    const buyerId = uuidv4();
    await client.query(`
      INSERT INTO users (id, email, password, first_name, last_name, phone, role, wilaya, is_active, is_verified)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, true, true)
      ON CONFLICT (email) DO NOTHING
    `, [buyerId, 'buyer@automarket.dz', buyerPassword, 'Mohamed', 'Khelifi', '0555222222', 'buyer', 'Oran']);

    // Create sample supplier
    const supplierPassword = await bcrypt.hash('supplier123', 10);
    const supplierId = uuidv4();
    await client.query(`
      INSERT INTO users (id, email, password, first_name, last_name, phone, role, wilaya, is_active, is_verified)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, true, true)
      ON CONFLICT (email) DO NOTHING
    `, [supplierId, 'supplier@automarket.dz', supplierPassword, 'Karim', 'Hadji', '0555333333', 'supplier', 'Blida']);

    // Create store for seller
    const storeId = uuidv4();
    await client.query(`
      INSERT INTO stores (id, user_id, name, slug, description, phone, wilaya, address, is_active, is_verified)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, true, true)
      ON CONFLICT (slug) DO NOTHING
    `, [storeId, sellerId, 'Auto Parts Alger', 'auto-parts-alger', 'Magasin de pièces détachées automobiles', '0555111111', 'Alger', 'Rue Didouche Mourad, Alger Centre']);

    // Create supplier profile
    const supplierProfileId = uuidv4();
    await client.query(`
      INSERT INTO suppliers (id, user_id, company_name, slug, description, phone, wilaya, is_active, is_verified)
      VALUES ($1, $2, $3, $4, $5, $6, $7, true, true)
      ON CONFLICT (slug) DO NOTHING
    `, [supplierProfileId, supplierId, 'Import Auto DZ', 'import-auto-dz', 'Importation et vente en gros de pièces automobiles', '0555333333', 'Blida']);

    // Create categories
    const categories = [
      { name: 'Moteur', name_ar: 'المحرك', slug: 'moteur' },
      { name: 'Freinage', name_ar: 'الفرامل', slug: 'freinage' },
      { name: 'Suspension', name_ar: 'التعليق', slug: 'suspension' },
      { name: 'Electricité', name_ar: 'الكهرباء', slug: 'electricite' },
      { name: 'Carrosserie', name_ar: 'الهيكل', slug: 'carrosserie' },
      { name: 'Transmission', name_ar: 'ناقل الحركة', slug: 'transmission' },
      { name: 'Climatisation', name_ar: 'التكييف', slug: 'climatisation' },
      { name: 'Echappement', name_ar: 'العادم', slug: 'echappement' },
      { name: 'Filtration', name_ar: 'الفلترة', slug: 'filtration' },
      { name: 'Huiles et Fluides', name_ar: 'الزيوت والسوائل', slug: 'huiles-fluides' },
      { name: 'Pneus et Roues', name_ar: 'الإطارات والعجلات', slug: 'pneus-roues' },
      { name: 'Accessoires', name_ar: 'الإكسسوارات', slug: 'accessoires' },
    ];

    const categoryIds = {};
    for (const cat of categories) {
      const catId = uuidv4();
      categoryIds[cat.slug] = catId;
      await client.query(`
        INSERT INTO categories (id, name, name_ar, slug, is_active)
        VALUES ($1, $2, $3, $4, true)
        ON CONFLICT (slug) DO NOTHING
      `, [catId, cat.name, cat.name_ar, cat.slug]);
    }

    // Create vehicle brands
    const carBrands = [
      'Renault', 'Peugeot', 'Citroën', 'Dacia', 'Volkswagen', 'Toyota',
      'Hyundai', 'Kia', 'Chevrolet', 'Seat', 'Skoda', 'BMW', 'Mercedes-Benz',
      'Audi', 'Ford', 'Fiat', 'Nissan', 'Honda', 'Suzuki', 'Mitsubishi'
    ];

    const truckBrands = ['Renault Trucks', 'Mercedes Trucks', 'Iveco', 'MAN', 'Scania', 'Volvo Trucks', 'DAF', 'Isuzu'];
    const motoBrands = ['Yamaha', 'Honda Moto', 'Suzuki Moto', 'Kawasaki', 'BMW Motorrad', 'KTM'];

    const brandIds = {};
    for (const brand of carBrands) {
      const brandId = uuidv4();
      const slug = brand.toLowerCase().replace(/[^a-z0-9]/g, '-');
      brandIds[slug] = brandId;
      await client.query(`
        INSERT INTO vehicle_brands (id, name, slug, vehicle_type, is_active)
        VALUES ($1, $2, $3, 'car', true)
        ON CONFLICT (slug) DO NOTHING
      `, [brandId, brand, slug]);
    }
    for (const brand of truckBrands) {
      const brandId = uuidv4();
      const slug = brand.toLowerCase().replace(/[^a-z0-9]/g, '-');
      brandIds[slug] = brandId;
      await client.query(`
        INSERT INTO vehicle_brands (id, name, slug, vehicle_type, is_active)
        VALUES ($1, $2, $3, 'truck', true)
        ON CONFLICT (slug) DO NOTHING
      `, [brandId, brand, slug]);
    }
    for (const brand of motoBrands) {
      const brandId = uuidv4();
      const slug = brand.toLowerCase().replace(/[^a-z0-9]/g, '-');
      brandIds[slug] = brandId;
      await client.query(`
        INSERT INTO vehicle_brands (id, name, slug, vehicle_type, is_active)
        VALUES ($1, $2, $3, 'motorcycle', true)
        ON CONFLICT (slug) DO NOTHING
      `, [brandId, brand, slug]);
    }

    // Create vehicle models for Renault
    const renaultModels = ['Clio', 'Symbol', 'Megane', 'Scenic', 'Kadjar', 'Duster', 'Logan', 'Sandero', 'Stepway'];
    const renaultBrandId = brandIds['renault'];
    const modelIds = {};
    if (renaultBrandId) {
      for (const model of renaultModels) {
        const modelId = uuidv4();
        const slug = model.toLowerCase().replace(/[^a-z0-9]/g, '-');
        modelIds[slug] = modelId;
        await client.query(`
          INSERT INTO vehicle_models (id, brand_id, name, slug, is_active)
          VALUES ($1, $2, $3, $4, true)
          ON CONFLICT (brand_id, slug) DO NOTHING
        `, [modelId, renaultBrandId, model, slug]);

        // Add years
        for (let year = 2000; year <= 2025; year++) {
          await client.query(`
            INSERT INTO vehicle_years (id, model_id, year)
            VALUES ($1, $2, $3)
            ON CONFLICT (model_id, year) DO NOTHING
          `, [uuidv4(), modelId, year]);
        }
      }
    }

    // Create Peugeot models
    const peugeotModels = ['206', '207', '208', '301', '308', '3008', '2008', '5008', '508', 'Partner'];
    const peugeotBrandId = brandIds['peugeot'];
    if (peugeotBrandId) {
      for (const model of peugeotModels) {
        const modelId = uuidv4();
        const slug = model.toLowerCase().replace(/[^a-z0-9]/g, '-');
        modelIds[slug] = modelId;
        await client.query(`
          INSERT INTO vehicle_models (id, brand_id, name, slug, is_active)
          VALUES ($1, $2, $3, $4, true)
          ON CONFLICT (brand_id, slug) DO NOTHING
        `, [modelId, peugeotBrandId, model, slug]);
        for (let year = 2000; year <= 2025; year++) {
          await client.query(`
            INSERT INTO vehicle_years (id, model_id, year)
            VALUES ($1, $2, $3)
            ON CONFLICT (model_id, year) DO NOTHING
          `, [uuidv4(), modelId, year]);
        }
      }
    }

    // Create sample products
    const products = [
      { name: 'Plaquettes de frein avant', slug: 'plaquettes-frein-avant-clio', price: 3500, category: 'freinage', desc: 'Plaquettes de frein avant haute qualité pour Renault Clio' },
      { name: 'Filtre à huile', slug: 'filtre-huile-symbol', price: 800, category: 'filtration', desc: 'Filtre à huile original pour Renault Symbol' },
      { name: 'Amortisseur avant', slug: 'amortisseur-avant-206', price: 8500, category: 'suspension', desc: 'Amortisseur avant pour Peugeot 206' },
      { name: 'Alternateur', slug: 'alternateur-megane', price: 25000, category: 'electricite', desc: 'Alternateur neuf pour Renault Megane' },
      { name: 'Kit embrayage', slug: 'kit-embrayage-clio-3', price: 15000, category: 'transmission', desc: 'Kit embrayage complet pour Renault Clio 3' },
      { name: 'Radiateur refroidissement', slug: 'radiateur-308', price: 12000, category: 'moteur', desc: 'Radiateur de refroidissement pour Peugeot 308' },
      { name: 'Pare-chocs avant', slug: 'pare-chocs-avant-207', price: 18000, category: 'carrosserie', desc: 'Pare-chocs avant neuf pour Peugeot 207' },
      { name: 'Compresseur climatisation', slug: 'compresseur-clim-clio-4', price: 35000, category: 'climatisation', desc: 'Compresseur de climatisation pour Renault Clio 4' },
      { name: 'Pot d\'échappement', slug: 'pot-echappement-symbol', price: 6500, category: 'echappement', desc: 'Pot d\'échappement arrière pour Renault Symbol' },
      { name: 'Huile moteur 5W40 5L', slug: 'huile-moteur-5w40-5l', price: 5500, category: 'huiles-fluides', desc: 'Huile moteur synthétique 5W40 bidon 5 litres' },
    ];

    for (const prod of products) {
      const productId = uuidv4();
      const catId = categoryIds[prod.category] || null;
      await client.query(`
        INSERT INTO products (id, store_id, category_id, name, slug, description, price, quantity, is_active, condition)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, true, 'new')
        ON CONFLICT DO NOTHING
      `, [productId, storeId, catId, prod.name, prod.slug, prod.desc, prod.price, 50]);
    }

    await client.query('COMMIT');
    console.log('✅ Seed data inserted successfully');
    console.log('');
    console.log('📧 Test accounts:');
    console.log('   Founder:  zegaoulamouaadh@gmail.com / 5E76LMTMD33');
    console.log('   Admin:    admin@automarket.dz / admin123');
    console.log('   Seller:   seller@automarket.dz / seller123');
    console.log('   Buyer:    buyer@automarket.dz / buyer123');
    console.log('   Supplier: supplier@automarket.dz / supplier123');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌ Error seeding data:', err.message);
  } finally {
    client.release();
    await pool.end();
  }
}

seedData().then(() => {
  process.exit(0);
}).catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
