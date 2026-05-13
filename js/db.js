// ================================================
// طبقة قاعدة البيانات — Supabase REST API
// ================================================

const API = {
  url: typeof SB_URL !== 'undefined' ? SB_URL : '',
  key: typeof SB_KEY !== 'undefined' ? SB_KEY : '',
  isReady() { return this.url && !this.url.includes('YOUR_PROJECT') && this.key && !this.key.includes('YOUR_ANON'); },

  headers(extra = {}) {
    return { 'apikey': this.key, 'Authorization': 'Bearer ' + this.key, 'Content-Type': 'application/json', 'Prefer': 'return=representation', ...extra };
  },

  async get(table, params = '') {
    const r = await fetch(`${this.url}/rest/v1/${table}${params ? '?' + params : ''}`, { headers: this.headers() });
    if (!r.ok) throw new Error(await r.text());
    return r.json();
  },

  async post(table, body, params = '') {
    const r = await fetch(`${this.url}/rest/v1/${table}${params ? '?' + params : ''}`, { method: 'POST', headers: this.headers(), body: JSON.stringify(body) });
    if (!r.ok) throw new Error(await r.text());
    const t = await r.text(); return t ? JSON.parse(t) : [];
  },

  async patch(table, filter, body) {
    const r = await fetch(`${this.url}/rest/v1/${table}?${filter}`, { method: 'PATCH', headers: this.headers(), body: JSON.stringify(body) });
    if (!r.ok) throw new Error(await r.text());
    const t = await r.text(); return t ? JSON.parse(t) : [];
  },

  async delete(table, filter) {
    const r = await fetch(`${this.url}/rest/v1/${table}?${filter}`, { method: 'DELETE', headers: this.headers() });
    if (!r.ok) throw new Error(await r.text());
  }
};

// ── فحص الاتصال ──
async function checkConnection() {
  if (!API.isReady()) return false;
  try { await API.get('settings', 'select=key&limit=1'); return true; } catch(e) { return false; }
}

// ================================================
// SETTINGS — PATCH فقط (الصفوف موجودة من الـ schema)
// ================================================
const Settings = {
  async get(key) {
    const rows = await API.get('settings', `select=value&key=eq.${key}`);
    return rows[0]?.value ?? '';
  },
  async getAll() {
    const rows = await API.get('settings', 'select=key,value');
    const obj = {};
    rows.forEach(r => { obj[r.key] = r.value; });
    return obj;
  },
  // PATCH فقط — لا INSERT — الصفوف موجودة من الـ schema
  async save(key, value) {
    const rows = await API.patch('settings', `key=eq.${key}`, { value, updated_at: new Date().toISOString() });
    if (!rows || rows.length === 0) {
      // الصف غير موجود → أنشئه (حالة استثنائية)
      await API.post('settings', { key, value });
    }
    return true;
  },
  async saveMany(obj) {
    for (const [k, v] of Object.entries(obj)) await Settings.save(k, v);
    return true;
  }
};

// ================================================
// DB — كل عمليات قاعدة البيانات
// ================================================
const DB = {

  // SETTINGS
  async getSetting(key)         { return Settings.get(key); },
  async getAllSettings()         { return Settings.getAll(); },
  async saveSetting(key, value) { return Settings.save(key, value); },
  async saveSettings(obj)       { return Settings.saveMany(obj); },

  // CATEGORIES
  async getCategories()         { return API.get('categories', 'is_active=eq.true&order=sort_order.asc'); },
  async getAllCategories()       { return API.get('categories', 'order=sort_order.asc'); },
  async addCategory(d)          { const r = await API.post('categories', d); return r[0]; },
  async updateCategory(id, d)   { return API.patch('categories', `id=eq.${id}`, d); },
  async deleteCategory(id)      { return API.delete('categories', `id=eq.${id}`); },

  // PRODUCTS
  async getProducts(catId)      { const f = catId ? `&category_id=eq.${catId}` : ''; return API.get('products_full', `order=sort_order.asc,id.asc${f}`); },
  async getFeatured()           { return API.get('products', 'is_featured=eq.true&is_available=eq.true&order=sort_order.asc&limit=10'); },
  async getProduct(id)          { const r = await API.get('products_full', `id=eq.${id}`); return r[0]; },
  async addProduct(d)           { const r = await API.post('products', d); return r[0]; },
  async updateProduct(id, d)    { return API.patch('products', `id=eq.${id}`, { ...d, updated_at: new Date().toISOString() }); },
  async updateStock(id, stock)  { return API.patch('products', `id=eq.${id}`, { stock, is_available: stock > 0, updated_at: new Date().toISOString() }); },
  async deleteProduct(id)       { await API.delete('product_extras', `product_id=eq.${id}`); return API.delete('products', `id=eq.${id}`); },

  // EXTRAS
  async getExtras(pid)          { return API.get('product_extras', `product_id=eq.${pid}&is_active=eq.true`); },
  async addExtra(d)             { return API.post('product_extras', d); },
  async deleteExtrasByProduct(pid) { return API.delete('product_extras', `product_id=eq.${pid}`); },

  // SLIDERS
  async getSliders()            { return API.get('slider_images', 'is_active=eq.true&order=sort_order.asc'); },
  async getAllSliders()          { return API.get('slider_images', 'order=sort_order.asc'); },
  async addSlider(d)            { return API.post('slider_images', d); },
  async deleteSlider(id)        { return API.delete('slider_images', `id=eq.${id}`); },

  // ORDERS
  async getOrders(status)       {
    const f = status ? `status=eq.${status}&` : '';
    return API.get('orders', `${f}order=created_at.desc`);
  },
  async getOrder(id)            { const r = await API.get('orders', `id=eq.${id}`); return r[0]; },
  async getOrderItems(oid)      { return API.get('order_items', `order_id=eq.${oid}`); },

  async createOrder(data) {
    const num = 'ORD-' + Date.now();
    const [order] = await API.post('orders', {
      order_number: num,
      table_number: data.table_number || null,
      order_type:   data.order_type || 'dine_in',
      status:       'pending',
      total_amount: data.total_amount,
      notes:             data.notes || '',
      customer_name:     data.customer_name || '',
      customer_phone:    data.customer_phone || '',
      customer_address:  data.customer_address || '',
      customer_landmark: data.customer_landmark || ''
    });
    if (data.items?.length) {
      await API.post('order_items', data.items.map(it => ({
        order_id: order.id, product_id: it.product_id,
        product_name: it.product_name, product_price: it.product_price,
        quantity: it.quantity, extras: JSON.stringify(it.extras || []),
        extras_price: it.extras_price || 0, item_total: it.item_total, notes: it.notes || ''
      })));
      for (const it of data.items) {
        try {
          const p = await DB.getProduct(it.product_id);
          if (p) await DB.updateStock(it.product_id, Math.max(0, p.stock - it.quantity));
        } catch(e) {}
      }
    }
    if (data.table_number && data.order_type === 'dine_in') {
      await DB.setTableStatus(data.table_number, 'occupied', order.id);
    }
    return { orderId: order.id, orderNum: num };
  },

  async addItemsToOrder(orderId, items, extra) {
    const order = await DB.getOrder(orderId);
    await API.post('order_items', items.map(it => ({
      order_id: orderId, product_id: it.product_id,
      product_name: it.product_name, product_price: it.product_price,
      quantity: it.quantity, extras: JSON.stringify(it.extras || []),
      extras_price: it.extras_price || 0, item_total: it.item_total, notes: it.notes || ''
    })));
    const newTotal = (+order.total_amount || 0) + extra;
    await API.patch('orders', `id=eq.${orderId}`, { total_amount: newTotal, updated_at: new Date().toISOString() });
    for (const it of items) {
      try {
        const p = await DB.getProduct(it.product_id);
        if (p) await DB.updateStock(it.product_id, Math.max(0, p.stock - it.quantity));
      } catch(e) {}
    }
    return newTotal;
  },

  async updateOrderStatus(id, status) { return API.patch('orders', `id=eq.${id}`, { status, updated_at: new Date().toISOString() }); },

  async deleteOrder(id) {
    await API.delete('order_items', `order_id=eq.${id}`);
    return API.delete('orders', `id=eq.${id}`);
  },

  async getActiveOrderForTable(num) {
    const r = await API.get('orders', `table_number=eq.${num}&status=in.(pending,confirmed,preparing,ready)&order=created_at.desc&limit=1`);
    return r[0] || null;
  },

  async getTodayStats() {
    const today = new Date().toISOString().split('T')[0];
    const [orders, pending] = await Promise.all([
      API.get('orders', `created_at=gte.${today}T00:00:00&status=neq.cancelled&select=total_amount`),
      API.get('orders', `status=eq.pending&select=id`)
    ]);
    return { total: orders.length, revenue: orders.reduce((s, o) => s + (+o.total_amount || 0), 0), pending: pending.length };
  },

  // TABLES
  async getTables()             { return API.get('restaurant_tables', 'is_active=eq.true&order=table_number.asc'); },
  async setTableStatus(num, status, orderId = null) {
    return API.patch('restaurant_tables', `table_number=eq.${num}`, {
      status, current_order_id: orderId,
      opened_at: status === 'occupied' ? new Date().toISOString() : null
    });
  },
  async closeTable(num) {
    await API.patch('orders', `table_number=eq.${num}&status=in.(pending,confirmed,preparing,ready)`, { status: 'delivered', updated_at: new Date().toISOString() });
    return DB.setTableStatus(num, 'available', null);
  },

  // REALTIME
  subscribe(table, cb) {
    if (!API.isReady()) return null;
    const ws = new WebSocket(API.url.replace('https://', 'wss://') + '/realtime/v1/websocket?apikey=' + API.key + '&vsn=1.0.0');
    ws.onopen = () => ws.send(JSON.stringify({ topic: `realtime:public:${table}`, event: 'phx_join', payload: {}, ref: 1 }));
    ws.onmessage = e => { try { const m = JSON.parse(e.data); if (['INSERT','UPDATE','DELETE'].includes(m.event)) cb(m.event, m.payload?.record); } catch(_) {} };
    return ws;
  },

  isReady: () => API.isReady()
};

window.DB = DB;
window.checkConnection = checkConnection;
