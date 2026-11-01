require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const multer = require('multer');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const ImageKit = require('imagekit');

const { Schema } = mongoose;
const OID = Schema.Types.ObjectId;
const JWT_SECRET = process.env.JWT_SECRET || 'change-this-secret';

/* ===================== MODELS ===================== */
const User = mongoose.model('User', new Schema({
  userId: { type: String, unique: true, required: true, trim: true },
  password: { type: String, required: true },
}));

// Legacy photos already stored in MongoDB remain available at /files/:id.
const Photo = mongoose.model('Photo', new Schema({ data: Buffer, contentType: String }));

const Property = mongoose.model('Property', new Schema({
  name: { type: String, required: true, trim: true },
  location: { type: String, default: '' },
  type: { type: String, default: 'Residential Building' },
  floors: { type: Number, default: 0 },
  description: { type: String, default: '' },
  photo: String,
  archived: { type: Boolean, default: false },
}, { timestamps: true }));

const Room = mongoose.model('Room', new Schema({
  propertyId: { type: OID, index: true, required: true },
  name: { type: String, required: true, trim: true },
  floor: { type: String, default: '' },
}, { timestamps: true }));

const Tenant = mongoose.model('Tenant', new Schema({
  propertyId: { type: OID, index: true },
  roomId: { type: OID, index: true },
  name: { type: String, required: true, trim: true },
  phone: { type: String, required: true, trim: true },
  address: { type: String, default: '' },
  aadhar: { type: String, default: '' },
  photo: String,
  meterPhoto: String,
  family: [new Schema({ name: String, relation: String, age: String }, { _id: false })],
  entryDate: { type: Date, required: true },
  monthlyRent: { type: Number, default: 0 },
  waterAmount: { type: Number, default: 0 },
  garbageAmount: { type: Number, default: 0 },
  electricityRate: { type: Number, default: 0 },
  currentReading: { type: Number, default: 0 },
}, { timestamps: true }));

const Bill = mongoose.model('Bill', new Schema({
  tenantId: { type: OID, index: true, required: true },
  billDate: { type: Date, required: true },
  month: { type: String, index: true }, // yyyy-MM
  prevReading: Number,
  newReading: Number,
  units: Number,
  rate: Number,
  electricity: Number,
  rent: Number,
  water: Number,
  garbage: Number,
  total: Number,
  meterPhoto: String,
}, { timestamps: true }));

const Payment = mongoose.model('Payment', new Schema({
  tenantId: { type: OID, index: true, required: true },
  amount: { type: Number, required: true },
  date: { type: Date, required: true },
  mode: { type: String, default: 'Cash' },
  note: { type: String, default: '' },
}, { timestamps: true }));

/* ===================== HELPERS ===================== */
const wrap = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
const num = (v, d = 0) => { const n = Number(v); return Number.isFinite(n) && v !== '' && v !== null && v !== undefined ? n : d; };
const round2 = (n) => Math.round(n * 100) / 100;
const httpErr = (status, message) => Object.assign(new Error(message), { status });
const parseDate = (s) => { const d = new Date(s); if (isNaN(d.getTime())) throw httpErr(400, 'Date galat hai'); return d; };

let imagekit;
function getImageKit() {
  const { IMAGEKIT_PUBLIC_KEY, IMAGEKIT_PRIVATE_KEY, IMAGEKIT_URL_ENDPOINT } = process.env;
  if (!IMAGEKIT_PUBLIC_KEY || !IMAGEKIT_PRIVATE_KEY || !IMAGEKIT_URL_ENDPOINT) {
    throw httpErr(503, 'ImageKit credentials .env me configure karein');
  }
  if (!imagekit) {
    imagekit = new ImageKit({
      publicKey: IMAGEKIT_PUBLIC_KEY,
      privateKey: IMAGEKIT_PRIVATE_KEY,
      urlEndpoint: IMAGEKIT_URL_ENDPOINT,
    });
  }
  return imagekit;
}

async function savePhoto(file) {
  if (!file) return undefined;
  if (!file.mimetype || !file.mimetype.startsWith('image/')) throw httpErr(400, 'Sirf image file upload karein');
  const uploaded = await getImageKit().upload({
    file: file.buffer,
    fileName: file.originalname,
    folder: process.env.IMAGEKIT_FOLDER || '/estate-sathi',
  });
  return uploaded.url;
}
async function removePhoto(p) {
  if (p && p.startsWith('/files/')) await Photo.findByIdAndDelete(p.slice(7)).catch(() => {});
}

// Har tenant ka billed / paid / balance
async function totals(tenantIds) {
  const match = tenantIds ? { tenantId: { $in: tenantIds } } : {};
  const [b, p] = await Promise.all([
    Bill.aggregate([{ $match: match }, { $group: { _id: '$tenantId', sum: { $sum: '$total' } } }]),
    Payment.aggregate([{ $match: match }, { $group: { _id: '$tenantId', sum: { $sum: '$amount' } } }]),
  ]);
  const map = {};
  const get = (id) => (map[String(id)] = map[String(id)] || { billed: 0, paid: 0, balance: 0 });
  b.forEach((x) => { get(x._id).billed = x.sum; });
  p.forEach((x) => { get(x._id).paid = x.sum; });
  Object.values(map).forEach((t) => { t.billed = round2(t.billed); t.paid = round2(t.paid); t.balance = round2(t.billed - t.paid); });
  return map;
}
// Payments ko purane bills par pehle adjust karke har bill ka status nikalta hai
function withStatus(bills, totalPaid) {
  const sorted = [...bills].sort((a, b) => (a.billDate - b.billDate) || (a.createdAt - b.createdAt));
  let rem = totalPaid;
  const out = {};
  for (const b of sorted) {
    const p = Math.max(0, Math.min(b.total, rem));
    rem -= p;
    out[String(b._id)] = { paidAmount: round2(p), status: p >= b.total - 0.005 ? 'paid' : (p > 0 ? 'partial' : 'pending') };
  }
  return out;
}
const tot = (map, id) => map[String(id)] || { billed: 0, paid: 0, balance: 0 };

async function deleteTenantCascade(tenantId) {
  const t = await Tenant.findById(tenantId);
  if (!t) return;
  const bills = await Bill.find({ tenantId });
  for (const b of bills) await removePhoto(b.meterPhoto);
  await Bill.deleteMany({ tenantId });
  await Payment.deleteMany({ tenantId });
  await removePhoto(t.photo);
  await removePhoto(t.meterPhoto);
  await Tenant.findByIdAndDelete(tenantId);
}
async function deleteRoomCascade(roomId) {
  const tenants = await Tenant.find({ roomId });
  for (const t of tenants) await deleteTenantCascade(t._id);
  await Room.findByIdAndDelete(roomId);
}

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 12 * 1024 * 1024 } });
const tenantUpload = upload.fields([{ name: 'photo', maxCount: 1 }, { name: 'meterPhoto', maxCount: 1 }]);

const auth = (req, res, next) => {
  const token = (req.headers.authorization || '').replace('Bearer ', '');
  try { jwt.verify(token, JWT_SECRET); next(); } catch (e) { res.status(401).json({ error: 'Pehle login karein' }); }
};

function tenantFields(body) {
  let family = [];
  try { family = JSON.parse(body.family || '[]'); } catch (e) { family = []; }
  return {
    name: String(body.name || '').trim(),
    phone: String(body.phone || '').trim(),
    address: body.address || '',
    aadhar: body.aadhar || '',
    family,
    entryDate: parseDate(body.entryDate),
    monthlyRent: num(body.monthlyRent),
    waterAmount: num(body.waterAmount),
    garbageAmount: num(body.garbageAmount),
    electricityRate: num(body.electricityRate),
    currentReading: num(body.currentReading),
  };
}

/* ===================== APP ===================== */
const app = express();
app.use(cors());
app.use(express.json());

app.get('/api/health', (req, res) => res.json({ ok: true }));

app.get('/files/:id', wrap(async (req, res) => {
  const p = await Photo.findById(req.params.id).catch(() => null);
  if (!p) return res.status(404).end();
  res.set('Content-Type', p.contentType || 'image/jpeg');
  res.set('Cache-Control', 'public, max-age=31536000, immutable');
  res.send(p.data);
}));

/* ---------- Login ---------- */
app.post('/api/login', wrap(async (req, res) => {
  const { userId, password } = req.body || {};
  const u = await User.findOne({ userId: String(userId || '').trim() });
  if (!u || !(await bcrypt.compare(String(password || ''), u.password))) throw httpErr(401, 'User ID ya password galat hai');
  res.json({ token: jwt.sign({ id: u._id }, JWT_SECRET, { expiresIn: '365d' }) });
}));

/* ---------- Dashboard ---------- */
const istNow = () => {
  const ist = new Date(Date.now() + 5.5 * 3600 * 1000); // India time
  return { y: ist.getUTCFullYear(), m: ist.getUTCMonth(), d: ist.getUTCDate() };
};

app.get('/api/dashboard', auth, wrap(async (req, res) => {
  const { y, m, d: today } = istNow();
  const start = new Date(Date.UTC(y, m, 1));
  const end = new Date(Date.UTC(y, m + 1, 1));
  const todayMs = Date.UTC(y, m, today);
  const daysInMonth = new Date(Date.UTC(y, m + 1, 0)).getUTCDate();
  const daysNext = new Date(Date.UTC(y, m + 2, 0)).getUTCDate();
  const month = `${y}-${String(m + 1).padStart(2, '0')}`;

  const [props, rooms, tenants, monthPay, monthBills, billsThisMonth] = await Promise.all([
    Property.find(), Room.find(), Tenant.find(),
    Payment.aggregate([{ $match: { date: { $gte: start, $lt: end } } }, { $group: { _id: null, sum: { $sum: '$amount' } } }]),
    Bill.aggregate([{ $match: { month } }, { $group: { _id: null, sum: { $sum: '$total' } } }]),
    Bill.find({ month }, 'tenantId'),
  ]);
  const tm = await totals(tenants.map((t) => t._id));
  const propName = {}; props.forEach((p) => { propName[String(p._id)] = p.name; });
  const roomName = {}; rooms.forEach((r) => { roomName[String(r._id)] = r.name; });
  const billed = new Set(billsThisMonth.map((x) => String(x.tenantId)));

  const brief = (t) => ({
    tenantId: t._id, name: t.name, phone: t.phone, photo: t.photo,
    property: propName[String(t.propertyId)] || '', room: roomName[String(t.roomId)] || '',
    balance: tot(tm, t._id).balance, dueDay: t.entryDate.getUTCDate(),
  });

  const pendingTenants = tenants.filter((t) => tot(tm, t._id).balance > 0);
  const lastBills = await Bill.find({ tenantId: { $in: pendingTenants.map((t) => t._id) } }, 'tenantId billDate').sort({ billDate: -1 });
  const lastBill = {};
  lastBills.forEach((x) => { if (!lastBill[String(x.tenantId)]) lastBill[String(x.tenantId)] = x.billDate; });
  const overdueDays = (t) => {
    const bd = lastBill[String(t._id)];
    return bd ? Math.max(0, Math.floor((todayMs - bd.getTime()) / 86400000)) : 0;
  };

  const pending = pendingTenants.map((t) => ({ ...brief(t), overdueDays: overdueDays(t) })).sort((a, b) => b.balance - a.balance);
  const toBill = tenants.filter((t) => {
    if (billed.has(String(t._id))) return false;
    if (t.entryDate >= start) return false; // is mahine aaya hai, bill agle mahine
    return today >= Math.min(t.entryDate.getUTCDate(), daysInMonth);
  }).map(brief);

  const dueIn = (t) => {
    const dd = t.entryDate.getUTCDate();
    let due = Date.UTC(y, m, Math.min(dd, daysInMonth));
    if (due < todayMs) due = Date.UTC(y, m + 1, Math.min(dd, daysNext));
    return Math.round((due - todayMs) / 86400000);
  };
  const dueThisWeek = tenants.filter((t) => t.entryDate < start && dueIn(t) <= 7).length;

  res.json({
    month,
    collectedThisMonth: round2(monthPay[0] ? monthPay[0].sum : 0),
    billedThisMonth: round2(monthBills[0] ? monthBills[0].sum : 0),
    totalPending: round2(pending.reduce((sum, p) => sum + p.balance, 0)),
    propertiesCount: props.length,
    roomsCount: rooms.length,
    occupied: tenants.length,
    totalTenants: tenants.length,
    vacant: Math.max(0, rooms.length - tenants.length),
    dueThisWeek,
    pending, toBill,
  });
}));

app.get('/api/collection', auth, wrap(async (req, res) => {
  const y = num(req.query.year, istNow().y);
  const rows = await Payment.aggregate([
    { $match: { date: { $gte: new Date(Date.UTC(y, 0, 1)), $lt: new Date(Date.UTC(y + 1, 0, 1)) } } },
    { $group: { _id: { $month: '$date' }, sum: { $sum: '$amount' } } },
  ]);
  const months = Array(12).fill(0);
  rows.forEach((r) => { months[r._id - 1] = round2(r.sum); });
  res.json({ year: y, months });
}));

/* ---------- Properties ---------- */
const propFields = (b) => ({
  name: String(b.name || '').trim(),
  location: b.location || '',
  type: b.type || 'Residential Building',
  floors: num(b.floors, 0),
  description: b.description || '',
});

app.get('/api/properties', auth, wrap(async (req, res) => {
  const [props, rooms, tenants] = await Promise.all([
    Property.find().sort({ createdAt: -1 }), Room.find({}, 'propertyId'), Tenant.find({}, 'propertyId'),
  ]);
  res.json(props.map((p) => {
    const r = rooms.filter((x) => String(x.propertyId) === String(p._id)).length;
    const t = tenants.filter((x) => String(x.propertyId) === String(p._id)).length;
    return { ...p.toObject(), roomCount: r, occupied: t, vacant: r - t };
  }));
}));

app.post('/api/properties', auth, upload.single('photo'), wrap(async (req, res) => {
  const f = propFields(req.body);
  if (!f.name) throw httpErr(400, 'Property ka naam likhein');
  res.json(await Property.create({ ...f, photo: await savePhoto(req.file) }));
}));

app.put('/api/properties/:id', auth, upload.single('photo'), wrap(async (req, res) => {
  const p = await Property.findById(req.params.id);
  if (!p) throw httpErr(404, 'Property nahi mili');
  const f = propFields(req.body);
  if (!f.name) throw httpErr(400, 'Property ka naam likhein');
  Object.assign(p, f);
  if (req.file) { await removePhoto(p.photo); p.photo = await savePhoto(req.file); }
  await p.save();
  res.json(p);
}));

app.post('/api/properties/:id/archive', auth, wrap(async (req, res) => {
  const p = await Property.findByIdAndUpdate(req.params.id, { archived: !!req.body.archived }, { new: true });
  if (!p) throw httpErr(404, 'Property nahi mili');
  res.json(p);
}));

app.delete('/api/properties/:id', auth, wrap(async (req, res) => {
  const rooms = await Room.find({ propertyId: req.params.id });
  for (const r of rooms) await deleteRoomCascade(r._id);
  const p = await Property.findByIdAndDelete(req.params.id);
  if (p) await removePhoto(p.photo);
  res.json({ ok: true });
}));

/* ---------- Rooms ---------- */
app.get('/api/properties/:id/rooms', auth, wrap(async (req, res) => {
  const property = await Property.findById(req.params.id);
  if (!property) throw httpErr(404, 'Property nahi mili');
  const [rooms, tenants] = await Promise.all([
    Room.find({ propertyId: property._id }).sort({ createdAt: 1 }), Tenant.find({ propertyId: property._id }),
  ]);
  const tm = await totals(tenants.map((t) => t._id));
  res.json({
    property,
    rooms: rooms.map((r) => {
      const t = tenants.find((x) => String(x.roomId) === String(r._id));
      return {
        _id: r._id, name: r.name, floor: r.floor || '',
        tenant: t ? {
          _id: t._id, name: t.name, phone: t.phone, photo: t.photo,
          monthlyRent: t.monthlyRent, balance: tot(tm, t._id).balance,
        } : null,
      };
    }),
  });
}));

app.post('/api/properties/:id/rooms', auth, wrap(async (req, res) => {
  const name = String(req.body.name || '').trim();
  if (!name) throw httpErr(400, 'Room ka naam likhein');
  res.json(await Room.create({ propertyId: req.params.id, name, floor: req.body.floor || '' }));
}));

app.delete('/api/rooms/:id', auth, wrap(async (req, res) => {
  await deleteRoomCascade(req.params.id);
  res.json({ ok: true });
}));

/* ---------- Tenants ---------- */
app.post('/api/rooms/:roomId/tenant', auth, tenantUpload, wrap(async (req, res) => {
  const room = await Room.findById(req.params.roomId);
  if (!room) throw httpErr(404, 'Room nahi mila');
  if (await Tenant.findOne({ roomId: room._id })) throw httpErr(400, 'Is room me pehle se tenant hai');
  const f = tenantFields(req.body);
  if (!f.name || !f.phone) throw httpErr(400, 'Naam aur phone number zaroori hai');
  const files = req.files || {};
  const tenant = await Tenant.create({
    ...f, propertyId: room.propertyId, roomId: room._id,
    photo: await savePhoto(files.photo && files.photo[0]),
    meterPhoto: await savePhoto(files.meterPhoto && files.meterPhoto[0]),
  });
  res.json(tenant);
}));

app.get('/api/tenants', auth, wrap(async (req, res) => {
  const [tenants, props, rooms] = await Promise.all([Tenant.find().sort({ name: 1 }), Property.find({}, 'name'), Room.find({}, 'name floor')]);
  const tm = await totals(tenants.map((t) => t._id));
  const pn = {}; props.forEach((p) => { pn[String(p._id)] = p.name; });
  const rn = {}; rooms.forEach((r) => { rn[String(r._id)] = r; });
  res.json(tenants.map((t) => ({
    _id: t._id, name: t.name, phone: t.phone, photo: t.photo, monthlyRent: t.monthlyRent,
    property: pn[String(t.propertyId)] || '',
    room: rn[String(t.roomId)] ? rn[String(t.roomId)].name : '',
    floor: rn[String(t.roomId)] ? rn[String(t.roomId)].floor : '',
    balance: tot(tm, t._id).balance,
  })));
}));

app.get('/api/bills', auth, wrap(async (req, res) => {
  const [bills, tenants, props, rooms] = await Promise.all([
    Bill.find().sort({ billDate: -1, createdAt: -1 }), Tenant.find(), Property.find({}, 'name'), Room.find({}, 'name'),
  ]);
  const tm = await totals(tenants.map((t) => t._id));
  const pn = {}; props.forEach((p) => { pn[String(p._id)] = p.name; });
  const rn = {}; rooms.forEach((r) => { rn[String(r._id)] = r.name; });
  const tById = {}; tenants.forEach((t) => { tById[String(t._id)] = t; });
  const byTenant = {};
  bills.forEach((b) => { (byTenant[String(b.tenantId)] = byTenant[String(b.tenantId)] || []).push(b); });
  const st = {};
  Object.keys(byTenant).forEach((id) => Object.assign(st, withStatus(byTenant[id], tot(tm, id).paid)));
  res.json(bills.map((b) => {
    const t = tById[String(b.tenantId)];
    if (!t) return null;
    return {
      ...b.toObject(), ...st[String(b._id)],
      tenantName: t.name, phone: t.phone,
      property: pn[String(t.propertyId)] || '', room: rn[String(t.roomId)] || '',
      balance: tot(tm, t._id).balance,
    };
  }).filter(Boolean));
}));

app.get('/api/tenants/:id', auth, wrap(async (req, res) => {
  const tenant = await Tenant.findById(req.params.id);
  if (!tenant) throw httpErr(404, 'Tenant nahi mila');
  const [room, property, bills, payments, tm] = await Promise.all([
    Room.findById(tenant.roomId), Property.findById(tenant.propertyId),
    Bill.find({ tenantId: tenant._id }).sort({ billDate: -1, createdAt: -1 }),
    Payment.find({ tenantId: tenant._id }).sort({ date: -1, createdAt: -1 }),
    totals([tenant._id]),
  ]);
  const t = tot(tm, tenant._id);
  const st = withStatus(bills, t.paid);
  res.json({ tenant, room, property, ...t, bills: bills.map((x) => ({ ...x.toObject(), ...st[String(x._id)] })), payments });
}));

app.put('/api/tenants/:id', auth, tenantUpload, wrap(async (req, res) => {
  const tenant = await Tenant.findById(req.params.id);
  if (!tenant) throw httpErr(404, 'Tenant nahi mila');
  const f = tenantFields(req.body);
  if (!f.name || !f.phone) throw httpErr(400, 'Naam aur phone number zaroori hai');
  const files = req.files || {};
  Object.assign(tenant, f);
  if (files.photo && files.photo[0]) { await removePhoto(tenant.photo); tenant.photo = await savePhoto(files.photo[0]); }
  if (files.meterPhoto && files.meterPhoto[0]) { await removePhoto(tenant.meterPhoto); tenant.meterPhoto = await savePhoto(files.meterPhoto[0]); }
  await tenant.save();
  res.json(tenant);
}));

app.delete('/api/tenants/:id', auth, wrap(async (req, res) => {
  await deleteTenantCascade(req.params.id);
  res.json({ ok: true });
}));

/* ---------- Bills ---------- */
app.post('/api/tenants/:id/bills', auth, upload.single('meterPhoto'), wrap(async (req, res) => {
  const tenant = await Tenant.findById(req.params.id);
  if (!tenant) throw httpErr(404, 'Tenant nahi mila');
  const billDate = parseDate(req.body.billDate);
  const newReading = num(req.body.newReading, NaN);
  if (!Number.isFinite(newReading)) throw httpErr(400, 'Nayi meter reading daalein');
  if (newReading < tenant.currentReading) {
    throw httpErr(400, `Nayi reading (${newReading}) purani reading (${tenant.currentReading}) se kam nahi ho sakti`);
  }
  const before = tot(await totals([tenant._id]), tenant._id).balance;
  const units = round2(newReading - tenant.currentReading);
  const electricity = round2(units * tenant.electricityRate);
  const total = round2(tenant.monthlyRent + electricity + tenant.waterAmount + tenant.garbageAmount);
  const bill = await Bill.create({
    tenantId: tenant._id, billDate, month: String(req.body.billDate).slice(0, 7),
    prevReading: tenant.currentReading, newReading, units, rate: tenant.electricityRate, electricity,
    rent: tenant.monthlyRent, water: tenant.waterAmount, garbage: tenant.garbageAmount, total,
    meterPhoto: await savePhoto(req.file),
  });
  tenant.currentReading = newReading;
  await tenant.save();
  res.json({ bill, previousDues: before, balance: round2(before + total) });
}));

app.delete('/api/bills/:id', auth, wrap(async (req, res) => {
  const bill = await Bill.findById(req.params.id);
  if (!bill) throw httpErr(404, 'Bill nahi mila');
  const latest = await Bill.findOne({ tenantId: bill.tenantId }).sort({ createdAt: -1 });
  if (latest && String(latest._id) === String(bill._id)) {
    await Tenant.findByIdAndUpdate(bill.tenantId, { currentReading: bill.prevReading });
  }
  await removePhoto(bill.meterPhoto);
  await Bill.findByIdAndDelete(bill._id);
  res.json({ ok: true });
}));

/* ---------- Payments ---------- */
app.post('/api/tenants/:id/payments', auth, wrap(async (req, res) => {
  const amount = num(req.body.amount, NaN);
  if (!(amount > 0)) throw httpErr(400, 'Sahi amount daalein');
  if (!(await Tenant.exists({ _id: req.params.id }))) throw httpErr(404, 'Tenant nahi mila');
  res.json(await Payment.create({
    tenantId: req.params.id, amount, date: parseDate(req.body.date), mode: req.body.mode || 'Cash', note: req.body.note || '',
  }));
}));

app.delete('/api/payments/:id', auth, wrap(async (req, res) => {
  await Payment.findByIdAndDelete(req.params.id);
  res.json({ ok: true });
}));

/* ---------- Errors ---------- */
app.use((err, req, res, next) => { // eslint-disable-line no-unused-vars
  console.error(err);
  res.status(err.status || 500).json({ error: err.message || 'Server error' });
});

/* ---------- Start ---------- */
async function ensureAdmin() {
  const { ADMIN_USER, ADMIN_PASS } = process.env;
  if (!ADMIN_USER || !ADMIN_PASS) return;
  const hash = await bcrypt.hash(ADMIN_PASS, 10);
  const u = await User.findOne({ userId: ADMIN_USER });
  if (!u) { await User.create({ userId: ADMIN_USER, password: hash }); console.log('Login user bana diya:', ADMIN_USER); }
  else if (!(await bcrypt.compare(ADMIN_PASS, u.password))) { u.password = hash; await u.save(); console.log('Password update ho gaya'); }
}

if (!process.env.MONGODB_URI) { console.error('MONGODB_URI .env me set karein'); process.exit(1); }
mongoose.connect(process.env.MONGODB_URI)
  .then(ensureAdmin)
  .then(() => {
    const port = process.env.PORT || 5000;
    app.listen(port, '0.0.0.0', () => console.log(`EstateSathi server chal raha hai: port ${port}`));
  })
  .catch((e) => { console.error('MongoDB connect nahi hua:', e.message); process.exit(1); });
