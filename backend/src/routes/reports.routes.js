const express = require('express');

const {
  dueReport,
  monthlyCollectionReport,
  tenantHistory,
  yearlyIncome,
} = require('../controllers/reports.controller');
const authMiddleware = require('../middleware/auth.middleware');
const asyncHandler = require('../utils/asyncHandler');
const {
  handleValidationErrors,
  mongoIdParam,
} = require('../utils/validators');

const router = express.Router();

router.use(authMiddleware);

router.get('/monthly-collection', asyncHandler(monthlyCollectionReport));
router.get('/yearly-income', asyncHandler(yearlyIncome));
router.get('/tenant-history/:id', [mongoIdParam(), handleValidationErrors], asyncHandler(tenantHistory));
router.get('/due-report', asyncHandler(dueReport));

module.exports = router;
