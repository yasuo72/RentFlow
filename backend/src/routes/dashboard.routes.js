const express = require('express');

const {
  deleteActivitiesByUser,
  deleteActivity,
  getMonthlyChart,
  getPaymentCalendar,
  getRecentActivity,
  getStats,
  getUpcomingDues,
} = require('../controllers/dashboard.controller');
const authMiddleware = require('../middleware/auth.middleware');
const allowRoles = require('../middleware/role.middleware');
const asyncHandler = require('../utils/asyncHandler');
const { handleValidationErrors, mongoIdParam } = require('../utils/validators');

const router = express.Router();

router.use(authMiddleware);

router.get('/stats', asyncHandler(getStats));
router.get('/monthly-chart', asyncHandler(getMonthlyChart));
router.get('/payment-calendar', asyncHandler(getPaymentCalendar));
router.get('/recent-activity', asyncHandler(getRecentActivity));
router.delete(
  '/recent-activity/by-user/:userId',
  allowRoles('super_admin'),
  [mongoIdParam('userId'), handleValidationErrors],
  asyncHandler(deleteActivitiesByUser),
);
router.delete(
  '/recent-activity/:id',
  allowRoles('super_admin'),
  [mongoIdParam(), handleValidationErrors],
  asyncHandler(deleteActivity),
);
router.get('/upcoming-dues', asyncHandler(getUpcomingDues));

module.exports = router;
