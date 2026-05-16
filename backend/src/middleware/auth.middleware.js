const jwt = require('jsonwebtoken');

const User = require('../models/User');
const { sendError } = require('../utils/response');

async function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return sendError(res, {
      statusCode: 401,
      message: 'Authorization token is required.',
    });
  }

  const token = authHeader.split(' ')[1];

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    const user = await User.findById(payload.userId);

    if (!user || !user.isActive) {
      return sendError(res, {
        statusCode: 401,
        message: 'User is no longer active.',
      });
    }

    req.user = user;
    req.token = token;
    return next();
  } catch (error) {
    return sendError(res, {
      statusCode: 401,
      message: 'Invalid or expired token.',
    });
  }
}

module.exports = authMiddleware;
