# 🔧 AutoMarket DZ - منصة قطع غيار المركبات في الجزائر

منصة إلكترونية شاملة لبيع وشراء قطع غيار جميع أنواع المركبات (سيارات، شاحنات، دراجات نارية) في الجزائر.

---

## 📋 المحتويات

- [المميزات](#المميزات)
- [البنية التقنية](#البنية-التقنية)
- [التثبيت والتشغيل](#التثبيت-والتشغيل)
- [حسابات الاختبار](#حسابات-الاختبار)
- [API Documentation](#api-documentation)
- [هيكل المشروع](#هيكل-المشروع)

---

## ✨ المميزات

### للمشترين
- 🔍 البحث المتقدم عن قطع الغيار حسب الماركة والموديل والصنف
- 🛒 سلة مشتريات متكاملة مع نظام الطلبات
- 💬 محادثة مباشرة مع البائعين (Socket.io)
- ⭐ نظام تقييمات ومراجعات للمنتجات والمتاجر
- 🚗 دعم جميع أنواع المركبات: سيارات، شاحنات، دراجات نارية

### للبائعين
- 🏪 لوحة تحكم خاصة لإدارة المتجر
- 📦 إدارة المنتجات (إضافة، تعديل، حذف، صور)
- 🛒 متابعة وإدارة الطلبات بجميع حالاتها
- 💬 نظام رسائل للتواصل مع المشترين
- 📊 إحصائيات المبيعات والأداء

### للمدير
- 👥 إدارة المستخدمين (حظر/تفعيل)
- 🏪 إدارة المتاجر (موافقة/تعطيل)
- 📂 إدارة الأصناف والماركات
- ⚠️ نظام البلاغات والمراقبة
- 📊 لوحة قيادة مع إحصائيات شاملة

### طرق الدفع
- 💵 الدفع عند الاستلام
- 📮 CCP
- 📱 بريدي موب (BaridiMob)
- 🏦 تحويل بنكي

---

## 🏗 البنية التقنية

| المكون | التقنية |
|--------|---------|
| Backend | Node.js + Express.js |
| قاعدة البيانات | PostgreSQL |
| المصادقة | JWT (JSON Web Tokens) |
| الوقت الحقيقي | Socket.io |
| البحث | Meilisearch |
| الواجهة الأمامية | HTML + CSS + JavaScript |
| تطبيق الموبايل | Flutter (Dart) |
| الحاويات | Docker + Docker Compose |

---

## 🚀 التثبيت والتشغيل

### المتطلبات
- Node.js 18+
- PostgreSQL 14+
- Flutter SDK 3.0+ (للموبايل)
- Docker & Docker Compose (اختياري)

### الطريقة 1: Docker (الأسهل)

```bash
# نسخ المشروع
cd MAR

# تشغيل كل الخدمات
docker-compose up -d

# تهيئة قاعدة البيانات
docker exec automarket_api node src/seeds/initDatabase.js
docker exec automarket_api node src/seeds/seedData.js
```

الخدمات تعمل على:
- **Backend API**: http://localhost:3000
- **PostgreSQL**: localhost:5432
- **Meilisearch**: http://localhost:7700

### الطريقة 2: التثبيت اليدوي

#### 1. قاعدة البيانات
```bash
# إنشاء قاعدة البيانات
createdb automarket_dz
```

#### 2. Backend
```bash
cd backend

# تثبيت المكتبات
npm install

# إعداد ملف البيئة
cp .env.example .env
# عدّل .env حسب إعداداتك

# تهيئة قاعدة البيانات
npm run db:init
npm run db:seed

# تشغيل الخادم
npm run dev
```

#### 3. الواجهة الأمامية (Web)
```bash
# افتح الملف في المتصفح مباشرة أو استخدم Live Server
# web/index.html
```

أو مباشرة عبر الـ Backend (المفضل لتجنب مشاكل CORS):
- `http://localhost:3000/`
- `http://localhost:3000/pages/login.html`

#### 4. لوحة البائع
```bash
# seller-dashboard/index.html
```

رابط مباشر عبر السيرفر:
- `http://localhost:3000/seller-dashboard/index.html`

#### 5. لوحة الإدارة
```bash
# admin-dashboard/index.html
```

رابط مباشر عبر السيرفر:
- `http://localhost:3000/admin-dashboard/index.html`

#### 6. تطبيق الموبايل (Flutter)
```bash
cd mobile

# تثبيت المكتبات
flutter pub get

# تشغيل التطبيق
flutter run
```

---

## 🔑 حسابات الاختبار

| الدور | البريد الإلكتروني | كلمة المرور |
|-------|-------------------|-------------|
| مدير | admin@automarket.dz | admin123 |
| بائع | seller@automarket.dz | seller123 |
| مشتري | buyer@automarket.dz | buyer123 |
| مورد | supplier@automarket.dz | supplier123 |

> ملاحظة: إذا كانت PostgreSQL متوقفة، يمكن تسجيل الدخول بهذه الحسابات في وضع تجريبي (Demo Mode) فقط. لتشغيل جميع الميزات (المنتجات/الطلبات/المحادثات...) يجب تشغيل قاعدة البيانات ثم تنفيذ:
>
> `npm run db:init && npm run db:seed`

---

## 📡 API Documentation

### المصادقة
| Method | Endpoint | الوصف |
|--------|----------|-------|
| POST | `/api/auth/register` | تسجيل حساب جديد |
| POST | `/api/auth/login` | تسجيل الدخول |
| GET | `/api/auth/profile` | معلومات الحساب |
| PUT | `/api/auth/profile` | تحديث الحساب |

### المنتجات
| Method | Endpoint | الوصف |
|--------|----------|-------|
| GET | `/api/products` | قائمة المنتجات (مع فلاتر) |
| GET | `/api/products/:id` | تفاصيل منتج |
| POST | `/api/products` | إضافة منتج (بائع) |
| PUT | `/api/products/:id` | تعديل منتج |
| DELETE | `/api/products/:id` | حذف منتج |
| GET | `/api/products/search?q=` | بحث عن منتجات |

### المتاجر
| Method | Endpoint | الوصف |
|--------|----------|-------|
| GET | `/api/stores` | قائمة المتاجر |
| GET | `/api/stores/:id` | تفاصيل متجر |
| POST | `/api/stores` | إنشاء متجر |
| PUT | `/api/stores/:id` | تعديل متجر |

### الطلبات
| Method | Endpoint | الوصف |
|--------|----------|-------|
| POST | `/api/orders` | إنشاء طلب |
| GET | `/api/orders` | طلباتي |
| GET | `/api/orders/:id` | تفاصيل طلب |
| PUT | `/api/orders/:id/status` | تحديث حالة طلب |

### التقييمات
| Method | Endpoint | الوصف |
|--------|----------|-------|
| GET | `/api/reviews/product/:id` | تقييمات منتج |
| POST | `/api/reviews` | إضافة تقييم |

### المحادثات
| Method | Endpoint | الوصف |
|--------|----------|-------|
| GET | `/api/chat/conversations` | قائمة المحادثات |
| POST | `/api/chat/conversations` | بدء محادثة |
| GET | `/api/chat/conversations/:id/messages` | رسائل محادثة |
| POST | `/api/chat/conversations/:id/messages` | إرسال رسالة |

### عام
| Method | Endpoint | الوصف |
|--------|----------|-------|
| GET | `/api/categories` | الأصناف |
| GET | `/api/brands` | الماركات |
| GET | `/api/wilayas` | الولايات |

---

## 📁 هيكل المشروع

```
MAR/
├── backend/                    # الخادم (Node.js + Express)
│   ├── src/
│   │   ├── config/            # إعدادات (DB, env)
│   │   ├── controllers/       # وحدات التحكم
│   │   ├── middleware/        # وسيط (auth, validation, upload)
│   │   ├── routes/            # مسارات API
│   │   ├── seeds/             # تهيئة وبذر قاعدة البيانات
│   │   ├── utils/             # أدوات مساعدة
│   │   └── server.js          # نقطة الدخول
│   ├── uploads/               # ملفات الصور المرفوعة
│   ├── package.json
│   ├── .env
│   └── .env.example
│
├── web/                        # الواجهة الأمامية للمشتري
│   ├── css/style.css
│   ├── js/app.js
│   ├── index.html             # الصفحة الرئيسية
│   └── pages/                 # الصفحات
│       ├── login.html
│       ├── register.html
│       ├── search.html
│       ├── product.html
│       ├── cart.html
│       ├── orders.html
│       ├── profile.html
│       └── store.html
│
├── seller-dashboard/           # لوحة تحكم البائع
│   ├── css/dashboard.css
│   ├── js/dashboard.js
│   ├── index.html
│   └── pages/
│       ├── products.html
│       ├── orders.html
│       ├── messages.html
│       └── store-settings.html
│
├── admin-dashboard/            # لوحة تحكم المدير
│   ├── css/admin.css
│   ├── js/admin.js
│   ├── index.html
│   └── pages/
│       ├── users.html
│       ├── stores.html
│       ├── products.html
│       ├── categories.html
│       ├── orders.html
│       └── reports.html
│
├── mobile/                     # تطبيق الموبايل (Flutter)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/            # نماذج البيانات
│   │   ├── providers/         # إدارة الحالة
│   │   ├── screens/           # الشاشات
│   │   ├── services/          # خدمات API
│   │   └── widgets/           # مكونات قابلة لإعادة الاستخدام
│   └── pubspec.yaml
│
├── docker-compose.yml          # إعداد Docker
├── Dockerfile                  # بناء صورة Backend
├── .dockerignore
└── README.md
```

---

## 🗄 قاعدة البيانات

الجداول الرئيسية (22+ جدول):
- `users` - المستخدمين (مشتري، بائع، مورد، مدير)
- `stores` - المتاجر
- `products` - المنتجات
- `product_images` - صور المنتجات
- `categories` - أصناف قطع الغيار
- `vehicle_brands` - ماركات المركبات
- `vehicle_models` - موديلات المركبات
- `product_fitments` - توافق المنتجات مع المركبات
- `oem_references` - أرقام OEM المرجعية
- `orders` - الطلبات
- `order_items` - عناصر الطلبات
- `payments` - المدفوعات
- `conversations` - المحادثات
- `messages` - الرسائل
- `product_reviews` - تقييمات المنتجات
- `store_reviews` - تقييمات المتاجر
- `reports` - البلاغات
- `wishlists` - قوائم الأمنيات

---

## 🌍 الولايات المدعومة

دعم كامل لجميع 58 ولاية جزائرية مع نظام شحن محلي.

---

## 📄 الترخيص

هذا المشروع للأغراض التعليمية والتطويرية.

---

**تم تطويره بـ ❤️ للجزائر 🇩🇿**
