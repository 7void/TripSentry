// backend\middleware\auth.js
const jwt = require('jsonwebtoken');
const logger = require('../utils/logger');

// JWT secret from environment variables
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-this';

// Middleware to authenticate JWT tokens
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

  if (!token) {
    logger.warn('Access attempted without token', {
      ip: req.ip,
      path: req.path,
      method: req.method
    });
    
    return res.status(401).json({
      success: false,
      message: 'Access token required'
    });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      logger.warn('Invalid token used', {
        ip: req.ip,
        path: req.path,
        method: req.method,
        error: err.message
      });
      
      return res.status(403).json({
        success: false,
        message: 'Invalid or expired token'
      });
    }

    req.user = user;
    next();
  });
};

// Middleware to check if user is government admin
const requireGovernmentAdmin = (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({
      success: false,
      message: 'Authentication required'
    });
  }

  if (req.user.role !== 'government_admin') {
    logger.warn('Unauthorized access attempt', {
      userId: req.user.id,
      role: req.user.role,
      path: req.path,
      method: req.method
    });
    
    return res.status(403).json({
      success: false,
      message: 'Government admin access required'
    });
  }

  next();
};

// Middleware to check if user can access tourist records
const requireTouristAccess = (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({
      success: false,
      message: 'Authentication required'
    });
  }

  // Allow government admins and tourists to access records
  const allowedRoles = ['government_admin', 'tourist', 'verifier'];
  
  if (!allowedRoles.includes(req.user.role)) {
    logger.warn('Unauthorized access attempt to tourist records', {
      userId: req.user.id,
      role: req.user.role,
      path: req.path,
      method: req.method
    });
    
    return res.status(403).json({
      success: false,
      message: 'Insufficient permissions to access tourist records'
    });
  }

  next();
};

// Middleware for API rate limiting based on user
const rateLimitByUser = (maxRequests = 100, windowMs = 15 * 60 * 1000) => {
  const requests = new Map();

  return (req, res, next) => {
    const userId = req.user ? req.user.id : req.ip;
    const now = Date.now();
    const windowStart = now - windowMs;

    // Clean old requests
    if (requests.has(userId)) {
      const userRequests = requests.get(userId).filter(time => time > windowStart);
      requests.set(userId, userRequests);
    }

    const currentRequests = requests.get(userId) || [];

    if (currentRequests.length >= maxRequests) {
      logger.warn('Rate limit exceeded', {
        userId,
        requestCount: currentRequests.length,
        path: req.path,
        method: req.method
      });

      return res.status(429).json({
        success: false,
        message: 'Too many requests. Please try again later.',
        retryAfter: Math.ceil(windowMs / 1000)
      });
    }

    // Add current request
    currentRequests.push(now);
    requests.set(userId, currentRequests);

    next();
  };
};

// Middleware to check if request is from authorized government address
const requireGovernmentAddress = (req, res, next) => {
  const { address } = req.body;
  const governmentAddress = process.env.GOVERNMENT_ADDRESS;

  if (!governmentAddress) {
    logger.error('Government address not configured');
    return res.status(500).json({
      success: false,
      message: 'Server configuration error'
    });
  }

  if (!address || address.toLowerCase() !== governmentAddress.toLowerCase()) {
    logger.warn('Unauthorized address attempted government action', {
      providedAddress: address,
      expectedAddress: governmentAddress,
      ip: req.ip,
      path: req.path
    });

    return res.status(403).json({
      success: false,
      message: 'Unauthorized: Invalid government address'
    });
  }

  next();
};

// Generate JWT token for authentication
const generateToken = (user) => {
  const payload = {
    id: user.id,
    role: user.role,
    address: user.address
  };

  return jwt.sign(payload, JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '24h'
  });
};

// Verify JWT token
const verifyToken = (token) => {
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch (error) {
    logger.error('Token verification failed', { error: error.message });
    return null;
  }
};

// Optional authentication - doesn't fail if no token provided
const optionalAuth = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (token) {
    jwt.verify(token, JWT_SECRET, (err, user) => {
      if (!err) {
        req.user = user;
      }
    });
  }

  next();
};

// Middleware to authenticate using API key
const authenticateApiKey = (req, res, next) => {
  const apiKey = req.headers['x-api-key'] || req.headers['authorization']?.replace('Bearer ', '');
  
  if (!apiKey) {
    logger.warn('API request without API key', {
      ip: req.ip,
      path: req.path,
      method: req.method
    });
    
    return res.status(401).json({
      success: false,
      message: 'API key required'
    });
  }

  if (apiKey !== process.env.API_KEY) {
    logger.warn('Invalid API key used', {
      ip: req.ip,
      path: req.path,
      method: req.method,
      providedKey: apiKey.substring(0, 8) + '...' // Log only first 8 chars for security
    });
    
    return res.status(403).json({
      success: false,
      message: 'Invalid API key'
    });
  }

  next();
};

module.exports = {
  authenticateToken,
  authenticateApiKey, // Added this function
  requireGovernmentAdmin,
  requireTouristAccess,
  requireGovernmentAddress,
  rateLimitByUser,
  optionalAuth,
  generateToken,
  verifyToken
};