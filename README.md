# 🍽️ مطعم النخبة — منيو إلكتروني احترافي

## 🚀 خطوات التشغيل

### 1️⃣ إعداد Supabase
1. اذهب إلى **supabase.com** → سجّل مجاناً → **New Project**
2. من **SQL Editor** → انسخ محتوى `db/schema.sql` والصقه → **Run**
3. من **Settings → API** انسخ:
   - **Project URL**
   - **anon / public key**

### 2️⃣ إعداد config.js
افتح `js/config.js` وضع بياناتك:
```js
const SB_URL = 'https://XXXXX.supabase.co';
const SB_KEY = 'eyJhbGci...';
```

### 3️⃣ الرفع على GitHub
```bash
git init
git add .
git commit -m "مطعم النخبة"
git branch -M main
git remote add origin https://github.com/USERNAME/REPO.git
git push -u origin main
```

### 4️⃣ تفعيل GitHub Pages
Settings → Pages → Source: **GitHub Actions**

---

## 🔐 الدخول للإدارة
- الرابط: `https://USERNAME.github.io/REPO/admin/`
- الرمز السري الافتراضي: **1234**

---

## 📁 هيكل المشروع
```
├── index.html          ← المنيو للعملاء
├── admin/
│   └── index.html      ← لوحة الإدارة
├── js/
│   ├── config.js       ← ضع هنا مفاتيح Supabase
│   └── db.js           ← طبقة قاعدة البيانات
├── db/
│   └── schema.sql      ← قاعدة البيانات الكاملة
└── .github/workflows/
    └── deploy.yml      ← نشر تلقائي
```

---

## ✨ المميزات
- شاشة Splash باللوجو
- سلايدر متحرك
- منتجات مع فيديو وإضافات
- المنتجات المنفذة تظهر شفافة
- إدارة الطاولات الذكية (دمج الفاتورة)
- تيك أواي مع بيانات التوصيل
- لوحة إدارة كاملة
- تقارير مع تصدير Excel
- Realtime للطلبات الجديدة
