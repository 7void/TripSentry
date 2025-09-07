// backend\middleware\validation.js

const { body, param, query, validationResult } = require('express-validator');
const logger = require('../utils/logger');

// Middleware to handle validation errors
const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    logger.warn('Validation failed', {
      errors: errors.array(),
      path: req.path,
      method: req.method
    });
    
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array()
    });
  }
  next();
};

// Validation rules for minting tourist ID
const validateMintTouristID = [
  body('touristAddress')
    .notEmpty()
    .withMessage('Tourist address is required')
    .isEthereumAddress()
    .withMessage('Invalid Ethereum address'),
  
  body('touristIdHash')
    .notEmpty()
    .withMessage('Tourist ID hash is required')
    .isLength({ min: 66, max: 66 })
    .withMessage('Tourist ID hash must be 66 characters long (including 0x prefix)')
    .matches(/^0x[a-fA-F0-9]{64}$/)
    .withMessage('Invalid tourist ID hash format'),
  
  body('validUntil')
    .notEmpty()
    .withMessage('Valid until date is required')
    .isISO8601()
    .withMessage('Valid until must be a valid ISO 8601 date')
    .custom((value) => {
      const date = new Date(value);
      const now = new Date();
      if (date <= now) {
        throw new Error('Valid until date must be in the future');
      }
      return true;
    }),
  
  body('metadataCID')
    .notEmpty()
    .withMessage('Metadata CID is required')
    .isLength({ min: 46, max: 64 })
    .withMessage('Invalid IPFS CID length'),
  
  body('issuerInfo')
    .optional()
    .isLength({ min: 1, max: 100 })
    .withMessage('Issuer info must be between 1 and 100 characters'),
  
  handleValidationErrors
];

// Validation rules for getting tourist record
const validateGetTouristRecord = [
  param('tokenId')
    .notEmpty()
    .withMessage('Token ID is required')
    .isNumeric()
    .withMessage('Token ID must be a number')
    .custom((value) => {
      const tokenId = parseInt(value);
      if (tokenId < 0) {
        throw new Error('Token ID must be a positive number');
      }
      return true;
    }),
  
  handleValidationErrors
];

// Validation rules for checking tourist ID validity
const validateCheckTouristID = [
  param('tokenId')
    .notEmpty()
    .withMessage('Token ID is required')
    .isNumeric()
    .withMessage('Token ID must be a number')
    .custom((value) => {
      const tokenId = parseInt(value);
      if (tokenId < 0) {
        throw new Error('Token ID must be a positive number');
      }
      return true;
    }),
  
  handleValidationErrors
];

// Validation rules for pagination
const validatePagination = [
  query('page')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Page must be a positive integer')
    .toInt(),
  
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Limit must be between 1 and 100')
    .toInt(),
  
  handleValidationErrors
];

// Validation for Ethereum address
const validateEthereumAddress = [
  param('address')
    .notEmpty()
    .withMessage('Address is required')
    .isEthereumAddress()
    .withMessage('Invalid Ethereum address'),
  
  handleValidationErrors
];

// Validation for tourist ID hash
const validateTouristIdHash = [
  param('hash')
    .notEmpty()
    .withMessage('Tourist ID hash is required')
    .isLength({ min: 66, max: 66 })
    .withMessage('Tourist ID hash must be 66 characters long')
    .matches(/^0x[a-fA-F0-9]{64}$/)
    .withMessage('Invalid tourist ID hash format'),
  
  handleValidationErrors
];

module.exports = {
  handleValidationErrors,
  validateMintTouristID,
  validateMintRequest: validateMintTouristID, // Alias for server.js compatibility
  validateGetTouristRecord,
  validateCheckTouristID,
  validatePagination,
  validateEthereumAddress,
  validateTouristIdHash
};