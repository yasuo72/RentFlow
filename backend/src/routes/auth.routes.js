const express = require('express');
const rateLimit = require('express-rate-limit');

const asyncHandler = require('../utils/asyncHandler');
const authMiddleware = require('../middleware/auth.middleware');
const {
  body,
  handleValidationErrors,
} = require('../utils/validators');
const {
  changePassword,
  getMe,
  login,
  logout,
  updateFcmToken,
} = require('../controllers/auth.controller');

const router = express.Router();

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
});

router.post(
  '/login',
  loginLimiter,
  [
    body('phone').notEmpty().withMessage('Phone is required.'),
    body('password').notEmpty().withMessage('Password is required.'),
    handleValidationErrors,
  ],
  asyncHandler(login),
);

router.post('/logout', authMiddleware, asyncHandler(logout));
router.get('/me', authMiddleware, asyncHandler(getMe));
router.put(
  '/me/fcm-token',
  authMiddleware,
  [
    body('fcmToken').optional().isString().withMessage('FCM token must be a string.'),
    handleValidationErrors,
  ],
  asyncHandler(updateFcmToken),
);
router.put(
  '/me/password',
  authMiddleware,
  [
    body('currentPassword').notEmpty().withMessage('Current password is required.'),
    body('newPassword').isLength({ min: 6 }).withMessage('New password must be at least 6 characters.'),
    handleValidationErrors,
  ],
  asyncHandler(changePassword),
);

module.exports = router;
