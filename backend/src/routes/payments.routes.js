const express = require('express');

const {
  deletePayment,
  editPayment,
  getMonthlySummary,
  getPayment,
  getPaymentReceipt,
  getPendingPayments,
  listPayments,
  recordPayment,
} = require('../controllers/payments.controller');
const authMiddleware = require('../middleware/auth.middleware');
const loggerMiddleware = require('../middleware/logger.middleware');
const allowRoles = require('../middleware/role.middleware');
const asyncHandler = require('../utils/asyncHandler');
const {
  body,
  handleValidationErrors,
  mongoIdParam,
  optionalMongoIdQuery,
  positiveNumberBody,
  query,
} = require('../utils/validators');

const router = express.Router();

router.use(authMiddleware, loggerMiddleware);

router.get(
  '/',
  [
    optionalMongoIdQuery('room'),
    optionalMongoIdQuery('tenant'),
    query('status').optional().isIn(['paid', 'partial', 'pending']).withMessage('Invalid status filter.'),
    handleValidationErrors,
  ],
  asyncHandler(listPayments),
);
router.get('/summary/month', asyncHandler(getMonthlySummary));
router.get('/pending', asyncHandler(getPendingPayments));
router.get('/:id/receipt', [mongoIdParam(), handleValidationErrors], asyncHandler(getPaymentReceipt));
router.get('/:id', [mongoIdParam(), handleValidationErrors], asyncHandler(getPayment));
router.post(
  '/',
  [
    body('tenant').isMongoId().withMessage('Tenant is required.'),
    body('room').isMongoId().withMessage('Room is required.'),
    positiveNumberBody('amountPaid'),
    positiveNumberBody('manualDueAmount').optional(),
    body('paymentMethod').optional().isIn(['cash', 'upi', 'bank_transfer', 'card', 'other']),
    handleValidationErrors,
  ],
  asyncHandler(recordPayment),
);
router.put(
  '/:id',
  [
    mongoIdParam(),
    positiveNumberBody('amountPaid').optional(),
    positiveNumberBody('manualDueAmount').optional(),
    handleValidationErrors,
  ],
  asyncHandler(editPayment),
);
router.delete(
  '/:id',
  allowRoles('super_admin'),
  [mongoIdParam(), handleValidationErrors],
  asyncHandler(deletePayment),
);

module.exports = router;
