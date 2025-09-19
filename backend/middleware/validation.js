const { body, validationResult } = require('express-validator');

// Validation rules for minting a Tourist ID
const mintTouristIdRules = [
	body('touristIdHash')
		.optional()
		.isString().withMessage('touristIdHash must be a string if provided'),
	body('rawTouristId')
		.optional()
		.isString().withMessage('rawTouristId must be a string'),
	body('validUntil')
		.exists().withMessage('validUntil is required')
		.isInt({ min: 1 }).withMessage('validUntil must be a positive integer')
		.custom(v => Number(v) > Math.floor(Date.now() / 1000)).withMessage('validUntil must be in the future'),
	body('metadataCID')
		.exists().withMessage('metadataCID is required')
		.isString().withMessage('metadataCID must be string')
		.matches(/^[A-Za-z0-9]+$/).withMessage('metadataCID looks invalid (expecting base CID)'),
	body('issuerInfo')
		.exists().withMessage('issuerInfo is required')
		.isString().withMessage('issuerInfo must be string')
		.isLength({ min: 3, max: 200 }).withMessage('issuerInfo length 3-200')
];

function handleValidation(req, res, next) {
	const errors = validationResult(req);
	if (!errors.isEmpty()) {
		return res.status(400).json({ errors: errors.array() });
	}
	next();
}

module.exports = {
	mintTouristIdRules,
	handleValidation
};
