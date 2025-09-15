const { db, admin } = require('./firebase');

const ACTIVE = 'active';
const PAST = 'past';

function userAlertsCol(uid) {
  return db.collection('users').doc(uid).collection('alerts');
}

function activeAlertsCol(uid) {
  return userAlertsCol(uid).doc(ACTIVE).collection('items');
}

function pastAlertsCol(uid) {
  return userAlertsCol(uid).doc(PAST).collection('items');
}

async function createAlert(uid, type, location, extra = {}) {
  const now = admin.firestore.FieldValue.serverTimestamp();
  const docRef = await activeAlertsCol(uid).add({
    type,
    triggeredAt: now,
    resolvedAt: null,
    location: {
      latitude: location.latitude,
      longitude: location.longitude,
    },
    extra,
  });
  return { id: docRef.id };
}

async function resolveAlert(uid, alertId) {
  const activeRef = activeAlertsCol(uid).doc(alertId);
  const snap = await activeRef.get();
  if (!snap.exists) return { success: false, reason: 'not_found' };
  const data = snap.data();
  const resolvedAt = admin.firestore.FieldValue.serverTimestamp();
  await db.runTransaction(async (tx) => {
    tx.delete(activeRef);
    const pastRef = pastAlertsCol(uid).doc(alertId);
    tx.set(pastRef, { ...data, resolvedAt }, { merge: true });
  });
  return { success: true };
}

function listenActiveAlerts(uid, callback) {
  return activeAlertsCol(uid)
    .orderBy('triggeredAt', 'desc')
    .onSnapshot((qs) => {
      const alerts = [];
      qs.forEach((d) => alerts.push({ id: d.id, ...d.data() }));
      callback(alerts);
    });
}

async function fetchAllActiveAlerts() {
  const results = [];
  // Collection group search under alerts/active/items pattern
  const qs = await db.collectionGroup('items')
    .where('resolvedAt', '==', null)
    .get();
  qs.forEach((d) => {
    // parent path: users/{uid}/alerts/active/items/{doc}
    const segments = d.ref.path.split('/');
    const uidIndex = segments.indexOf('users') + 1;
    const uid = segments[uidIndex];
    results.push({ uid, id: d.id, ...d.data() });
  });
  return results;
}

module.exports = {
  createAlert,
  resolveAlert,
  listenActiveAlerts,
  fetchAllActiveAlerts,
};
