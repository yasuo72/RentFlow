const jwt = require('jsonwebtoken');

const User = require('../models/User');
const { sendError, sendSuccess } = require('../utils/response');

function signToken(user) {
  return jwt.sign(
    {
      userId: user._id,
      role: user.role,
    },
    process.env.JWT_SECRET,
    {
      expiresIn: process.env.JWT_EXPIRES_IN || '30d',
    },
  );
}

async function login(req, res) {
  const { phone, password } = req.body;

  const user = await User.findOne({ phone });

  if (!user || !user.isActive) {
    return sendError(res, {
      statusCode: 401,
      message: 'Invalid phone or password.',
    });
  }

  const isPasswordValid = await user.comparePassword(password);

  if (!isPasswordValid) {
    return sendError(res, {
      statusCode: 401,
      message: 'Invalid phone or password.',
    });
  }

  user.lastLogin = new Date();
  await user.save();

  return sendSuccess(res, {
    message: 'Login successful.',
    data: {
      token: signToken(user),
      user: user.toSafeObject(),
    },
  });
}

async function logout(req, res) {
  return sendSuccess(res, {
    message: 'Logout successful.',
  });
}

async function getMe(req, res) {
  return sendSuccess(res, {
    data: req.user.toSafeObject(),
  });
}

async function updateFcmToken(req, res) {
  req.user.fcmToken = req.body.fcmToken || null;
  await req.user.save();

  return sendSuccess(res, {
    message: 'FCM token updated.',
    data: req.user.toSafeObject(),
  });
}

async function changePassword(req, res) {
  const { currentPassword, newPassword } = req.body;

  const isPasswordValid = await req.user.comparePassword(currentPassword);

  if (!isPasswordValid) {
    return sendError(res, {
      statusCode: 400,
      message: 'Current password is incorrect.',
    });
  }

  req.user.password = newPassword;
  await req.user.save();

  return sendSuccess(res, {
    message: 'Password changed successfully.',
  });
}

module.exports = {
  login,
  logout,
  getMe,
  updateFcmToken,
  changePassword,
};
