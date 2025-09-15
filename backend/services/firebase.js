const admin = require('firebase-admin');

if (!admin.apps.length) {
  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (serviceAccountJson) {
    const creds = JSON.parse(serviceAccountJson);
    admin.initializeApp({
      credential: admin.credential.cert(creds),
      projectId: creds.project_id,
    });
  } else {
    admin.initializeApp();
  }
}

const db = admin.firestore();

module.exports = { admin, db };
