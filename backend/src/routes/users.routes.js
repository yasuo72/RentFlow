const express = require('express');

const {
  createUser,
  deleteUser,
  listUsers,
  updateUser,
} = require('../controllers/users.controller');
const authMiddleware = require('../middleware/auth.middleware');
const loggerMiddleware = require('../middleware/logger.middleware');
const allowRoles = require('../middleware/role.middleware');
const asyncHandler = require('../utils/asyncHandler');
const {
  body,
  handleValidationErrors,
  mongoIdParam,
} = require('../utils/validators');

const router = express.Router();

router.use(authMiddleware, loggerMiddleware);

router.get('/', asyncHandler(listUsers));
router.post(
  '/',
  [
    body('name').notEmpty().withMessage('Name is required.'),
    body('phone').notEmpty().withMessage('Phone is required.'),
    body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters.'),
    handleValidationErrors,
  ],
  asyncHandler(createUser),
);
router.put(
  '/:id',
  [
    mongoIdParam(),
    body('email').optional().isEmail().withMessage('Email must be valid.'),
    handleValidationErrors,
  ],
  asyncHandler(updateUser),
);
router.delete(
  '/:id',
  allowRoles('super_admin'),
  [mongoIdParam(), handleValidationErrors],
  asyncHandler(deleteUser),
);

module.exports = router;
