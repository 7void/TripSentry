const admin = require('firebase-admin');
const logger = require('../utils/logger');

let initialized = false;

function initFirebase() {
	if (initialized) return admin;

	const {
		FIREBASE_PROJECT_ID,
		FIREBASE_CLIENT_EMAIL,
		FIREBASE_PRIVATE_KEY,
		GOOGLE_APPLICATION_CREDENTIALS
	} = process.env;

	try {
		if (FIREBASE_PROJECT_ID && FIREBASE_CLIENT_EMAIL && FIREBASE_PRIVATE_KEY) {
			// Private key may contain escaped newlines
			const privateKey = FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n');
			admin.initializeApp({
				credential: admin.credential.cert({
					projectId: FIREBASE_PROJECT_ID,
					clientEmail: FIREBASE_CLIENT_EMAIL,
					privateKey
				})
			});
			initialized = true;
			logger.info('Firebase initialized via explicit credentials');
		} else if (GOOGLE_APPLICATION_CREDENTIALS) {
			admin.initializeApp({
				credential: admin.credential.applicationDefault()
			});
			initialized = true;
			logger.info('Firebase initialized via application default credentials');
		} else {
			logger.warn('Firebase credentials not provided - Firebase features disabled');
		}
	} catch (err) {
		logger.error('Failed to initialize Firebase: ' + err.message);
	}
	return admin;
}

module.exports = { initFirebase };
