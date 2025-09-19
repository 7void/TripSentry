const logger = require('../utils/logger');

/**
 * Placeholder: send an alert when a new Tourist ID is minted.
 */
async function notifyNewTouristID(record) {
	logger.info('[ALERT] New Tourist ID minted', { tokenId: record.tokenId });
	// Future: push notification, email, etc.
	return true;
}

/**
 * Placeholder: generic incident alert.
 */
async function raiseIncidentAlert(details) {
	logger.warn('[ALERT] Incident', details);
	return true;
}

module.exports = { notifyNewTouristID, raiseIncidentAlert };
