-- ================================================
-- مطعم النخبة — قاعدة البيانات الكاملة
-- شغّل هذا في Supabase → SQL Editor
-- ================================================

-- ── الأقسام ──
CREATE TABLE IF NOT EXISTS categories (
  id         SERIAL PRIMARY KEY,
  name_ar    TEXT NOT NULL,
  name_en    TEXT DEFAULT '',
  icon       TEXT DEFAULT '🍽️',
  sort_order INTEGER DEFAULT 0,
  is_active  BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── المنتجات ──
CREATE TABLE IF NOT EXISTS products (
  id             SERIAL PRIMARY KEY,
  category_id    INTEGER REFERENCES categories(id) ON DELETE SET NULL,
  name_ar        TEXT NOT NULL,
  name_en        TEXT DEFAULT '',
  description_ar TEXT DEFAULT '',
  price          NUMERIC(10,2) NOT NULL DEFAULT 0,
  image_url      TEXT DEFAULT '',
  video_url      TEXT DEFAULT '',
  stock          INTEGER DEFAULT 100,
  is_available   BOOLEAN DEFAULT true,
  is_featured    BOOLEAN DEFAULT false,
  sort_order     INTEGER DEFAULT 0,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ── إضافات المنتجات ──
CREATE TABLE IF NOT EXISTS product_extras (
  id         SERIAL PRIMARY KEY,
  product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
  name_ar    TEXT NOT NULL,
  name_en    TEXT DEFAULT '',
  price      NUMERIC(10,2) DEFAULT 0,
  is_active  BOOLEAN DEFAULT true
);

-- ── الطاولات ──
CREATE TABLE IF NOT EXISTS restaurant_tables (
  id               SERIAL PRIMARY KEY,
  table_number     INTEGER UNIQUE NOT NULL,
  name             TEXT DEFAULT '',
  capacity         INTEGER DEFAULT 4,
  status           TEXT DEFAULT 'available' CHECK (status IN ('available','occupied','reserved')),
  current_order_id INTEGER,
  opened_at        TIMESTAMPTZ,
  is_active        BOOLEAN DEFAULT true
);

-- ── الطلبات ──
CREATE TABLE IF NOT EXISTS orders (
  id                SERIAL PRIMARY KEY,
  order_number      TEXT UNIQUE NOT NULL,
  table_number      INTEGER,
  order_type        TEXT DEFAULT 'dine_in' CHECK (order_type IN ('dine_in','takeaway')),
  status            TEXT DEFAULT 'pending'
    CHECK (status IN ('pending','confirmed','preparing','ready','delivered','cancelled')),
  total_amount      NUMERIC(10,2) DEFAULT 0,
  notes             TEXT DEFAULT '',
  customer_name     TEXT DEFAULT '',
  customer_phone    TEXT DEFAULT '',
  customer_address  TEXT DEFAULT '',
  customer_landmark TEXT DEFAULT '',
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);

-- ── تفاصيل الطلبات ──
CREATE TABLE IF NOT EXISTS order_items (
  id            SERIAL PRIMARY KEY,
  order_id      INTEGER REFERENCES orders(id) ON DELETE CASCADE,
  product_id    INTEGER REFERENCES products(id) ON DELETE SET NULL,
  product_name  TEXT NOT NULL,
  product_price NUMERIC(10,2) NOT NULL,
  quantity      INTEGER DEFAULT 1,
  extras        JSONB DEFAULT '[]',
  extras_price  NUMERIC(10,2) DEFAULT 0,
  item_total    NUMERIC(10,2) DEFAULT 0,
  notes         TEXT DEFAULT ''
);

-- ── إعدادات المطعم ──
CREATE TABLE IF NOT EXISTS settings (
  key        TEXT PRIMARY KEY,
  value      TEXT DEFAULT '',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── صور السلايدر ──
CREATE TABLE IF NOT EXISTS slider_images (
  id         SERIAL PRIMARY KEY,
  image_url  TEXT NOT NULL,
  title_ar   TEXT DEFAULT '',
  subtitle_ar TEXT DEFAULT '',
  sort_order INTEGER DEFAULT 0,
  is_active  BOOLEAN DEFAULT true
);

-- ================================================
-- View: منتجات مع اسم القسم
-- ================================================
CREATE OR REPLACE VIEW products_full AS
SELECT p.*, c.name_ar AS cat_name, c.icon AS cat_icon
FROM products p
LEFT JOIN categories c ON p.category_id = c.id;

-- ================================================
-- Triggers: تحديث updated_at تلقائياً
-- ================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_products_updated ON products;
CREATE TRIGGER trg_products_updated BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_orders_updated ON orders;
CREATE TRIGGER trg_orders_updated BEFORE UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ================================================
-- RLS — أمان مع صلاحية كاملة للأنون كي
-- ================================================
ALTER TABLE categories        ENABLE ROW LEVEL SECURITY;
ALTER TABLE products          ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_extras    ENABLE ROW LEVEL SECURITY;
ALTER TABLE restaurant_tables ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders            ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items       ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings          ENABLE ROW LEVEL SECURITY;
ALTER TABLE slider_images     ENABLE ROW LEVEL SECURITY;

-- حذف أي policies قديمة
DO $$ DECLARE r RECORD;
BEGIN
  FOR r IN SELECT policyname, tablename FROM pg_policies
    WHERE tablename IN ('categories','products','product_extras',
      'restaurant_tables','orders','order_items','settings','slider_images')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', r.policyname, r.tablename);
  END LOOP;
END $$;

-- منح صلاحية كاملة (قراءة + كتابة + تعديل + حذف)
CREATE POLICY "allow_all" ON categories        FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all" ON products          FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all" ON product_extras    FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all" ON restaurant_tables FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all" ON orders            FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all" ON order_items       FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all" ON settings          FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all" ON slider_images     FOR ALL USING (true) WITH CHECK (true);

-- Realtime للطلبات
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime FOR TABLE orders, restaurant_tables;

-- ================================================
-- البيانات الافتراضية
-- ================================================

-- الإعدادات (PRIMARY KEY = key → لا تكرار ممكن)
INSERT INTO settings (key, value) VALUES
  ('restaurant_name',  'مطعم النخبة'),
  ('restaurant_logo',  ''),
  ('currency',         'ج.م'),
  ('welcome_message',  'أهلاً بكم في مطعمنا'),
  ('admin_password',   '1234')
ON CONFLICT (key) DO NOTHING;

-- الأقسام
INSERT INTO categories (name_ar, name_en, icon, sort_order) VALUES
  ('المقبلات',        'Appetizers',    '🥗', 1),
  ('الوجبات الرئيسية','Main Courses',  '🍽️', 2),
  ('المشويات',        'Grills',        '🔥', 3),
  ('البيتزا',         'Pizza',         '🍕', 4),
  ('البرجر',          'Burgers',       '🍔', 5),
  ('المعكرونة',       'Pasta',         '🍝', 6),
  ('السلطات',         'Salads',        '🥙', 7),
  ('الحلويات',        'Desserts',      '🍰', 8),
  ('المشروبات',       'Beverages',     '🥤', 9)
ON CONFLICT DO NOTHING;

-- المنتجات
INSERT INTO products (category_id, name_ar, name_en, description_ar, price, stock, is_featured, image_url) VALUES
  (2,'شيش طاووق','Chicken Shish','دجاج مشوي بالتوابل الشرقية مع خبز وصلصة ثوم',85,50,true,'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=500'),
  (2,'كباب مشوي','Grilled Kebab','كباب لحم بالفحم مع أرز وسلطة طازجة',95,30,true,'https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?w=500'),
  (5,'برجر كلاسيك','Classic Burger','برجر لحم بقري 200جم مع خس وطماطم وجبن',75,40,true,'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500'),
  (4,'بيتزا مارجريتا','Margherita Pizza','بيتزا بصلصة الطماطم والجبن والريحان الطازج',90,25,false,'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=500'),
  (6,'مكرونة بولونيز','Bolognese Pasta','مكرونة بصلصة اللحم الإيطالية الأصيلة',70,35,false,'https://images.unsplash.com/photo-1555949258-eb67b1ef0ceb?w=500'),
  (8,'كنافة بالجبن','Knafeh','كنافة نابلسية أصيلة بالجبن القشقوان والعسل',45,20,true,'https://images.unsplash.com/photo-1579954115545-a95591f28bfc?w=500'),
  (9,'عصير مانجو','Mango Juice','عصير مانجو طازج 100% بدون إضافات',30,100,false,'https://images.unsplash.com/photo-1546173159-315724a31696?w=500'),
  (1,'سمبوسك','Sambousek','سمبوسك مقرمش بالجبن واللحم المفروم',35,0,false,'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=500'),
  (3,'دجاج مشوي كامل','Whole Grilled Chicken','دجاجة كاملة مشوية على الفحم بالأعشاب',120,15,true,'https://images.unsplash.com/photo-1598103442097-8b74394b95c8?w=500'),
  (5,'كريسبي برجر','Crispy Burger','برجر دجاج مقرمش بصلصة خاصة',80,45,false,'https://images.unsplash.com/photo-1606755962773-d324e0a13086?w=500')
ON CONFLICT DO NOTHING;

-- إضافات المنتجات
INSERT INTO product_extras (product_id, name_ar, name_en, price)
SELECT p.id, e.name_ar, e.name_en, e.price
FROM products p, (VALUES
  ('شيش طاووق','إضافة جبن','Extra Cheese',10),
  ('شيش طاووق','حار إضافي','Extra Spicy',0),
  ('برجر كلاسيك','جبن مزدوج','Double Cheese',15),
  ('برجر كلاسيك','لحم مضاعف','Double Meat',25),
  ('برجر كلاسيك','بيض مقلي','Fried Egg',10),
  ('بيتزا مارجريتا','جبن إضافي','Extra Cheese',15),
  ('بيتزا مارجريتا','فطر','Mushrooms',10),
  ('بيتزا مارجريتا','زيتون','Olives',8),
  ('دجاج مشوي كامل','صلصة ثوم','Garlic Sauce',5),
  ('دجاج مشوي كامل','خبز رقيق','Thin Bread',5)
) AS e(product_name, name_ar, name_en, price)
WHERE p.name_ar = e.product_name
ON CONFLICT DO NOTHING;

-- السلايدر
INSERT INTO slider_images (image_url, title_ar, subtitle_ar, sort_order) VALUES
  ('https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=1200','أهلاً بكم في مطعم النخبة','تجربة طعام لا تُنسى',1),
  ('https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=1200','أشهى المأكولات الشرقية','مع أفضل الطهاة المحترفين',2),
  ('https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=1200','عروض خاصة يومية','وجبات طازجة بأسعار مميزة',3)
ON CONFLICT DO NOTHING;

-- الطاولات 1-20
INSERT INTO restaurant_tables (table_number, name, capacity)
SELECT n, 'طاولة '||n, CASE WHEN n<=4 THEN 2 WHEN n<=14 THEN 4 ELSE 6 END
FROM generate_series(1,20) AS n
ON CONFLICT (table_number) DO NOTHING;

-- ✅ اكتمل
SELECT 'تم إعداد قاعدة البيانات بنجاح ✅' AS result;
