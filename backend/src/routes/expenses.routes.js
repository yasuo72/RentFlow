const express = require('express');

const {
  createExpense,
  deleteExpense,
  getExpenseSummary,
  listExpenses,
  updateExpense,
} = require('../controllers/expenses.controller');
const authMiddleware = require('../middleware/auth.middleware');
const loggerMiddleware = require('../middleware/logger.middleware');
const allowRoles = require('../middleware/role.middleware');
const { upload } = require('../middleware/upload.middleware');
const asyncHandler = require('../utils/asyncHandler');
const {
  body,
  handleValidationErrors,
  mongoIdParam,
  positiveNumberBody,
} = require('../utils/validators');

const router = express.Router();

router.use(authMiddleware, loggerMiddleware);

router.get('/', asyncHandler(listExpenses));
router.get('/summary', asyncHandler(getExpenseSummary));
router.post(
  '/',
  upload.single('billPhoto'),
  [
    body('category').optional().isIn(['electricity', 'water', 'repair', 'cleaning', 'internet', 'maintenance', 'other']),
    positiveNumberBody('amount'),
    body('date').notEmpty().withMessage('Date is required.'),
    body('room').optional().isMongoId().withMessage('Room must be valid.'),
    handleValidationErrors,
  ],
  asyncHandler(createExpense),
);
router.put(
  '/:id',
  upload.single('billPhoto'),
  [
    mongoIdParam(),
    positiveNumberBody('amount').optional(),
    handleValidationErrors,
  ],
  asyncHandler(updateExpense),
);
router.delete(
  '/:id',
  allowRoles('super_admin'),
  [mongoIdParam(), handleValidationErrors],
  asyncHandler(deleteExpense),
);

module.exports = router;
