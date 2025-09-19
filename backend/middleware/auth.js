const logger = require('../utils/logger');

module.exports = function apiKeyAuth(req, res, next) {
	const headerKey = req.headers['x-api-key'];
	const expected = process.env.API_KEY;
	if (!expected) {
		logger.warn('API_KEY not configured in environment');
		return res.status(500).json({ error: 'Server configuration error' });
	}
	if (!headerKey || headerKey !== expected) {
		return res.status(401).json({ error: 'Unauthorized' });
	}
	next();
};
