const express = require('express');

const {
  createTenant,
  deleteTenant,
  getTenant,
  listInactiveTenants,
  listTenants,
  purgeTenant,
  updateTenant,
  uploadTenantDocuments,
} = require('../controllers/tenants.controller');
const authMiddleware = require('../middleware/auth.middleware');
const loggerMiddleware = require('../middleware/logger.middleware');
const allowRoles = require('../middleware/role.middleware');
const { upload } = require('../middleware/upload.middleware');
const asyncHandler = require('../utils/asyncHandler');
const {
  body,
  handleValidationErrors,
  mongoIdParam,
} = require('../utils/validators');

const router = express.Router();

router.use(authMiddleware, loggerMiddleware);

router.get('/', asyncHandler(listTenants));
router.get('/inactive', asyncHandler(listInactiveTenants));
router.get('/:id', [mongoIdParam(), handleValidationErrors], asyncHandler(getTenant));
router.post(
  '/',
  upload.fields([
    { name: 'profilePhoto', maxCount: 1 },
    { name: 'documents', maxCount: 10 },
  ]),
  [
    body('fullName').notEmpty().withMessage('Full name is required.'),
    body('phone').notEmpty().withMessage('Phone is required.'),
    body('joiningDate').notEmpty().withMessage('Joining date is required.'),
    body('room').isMongoId().withMessage('Room is required.'),
    handleValidationErrors,
  ],
  asyncHandler(createTenant),
);
router.put(
  '/:id',
  upload.fields([
    { name: 'profilePhoto', maxCount: 1 },
    { name: 'documents', maxCount: 10 },
  ]),
  [
    mongoIdParam(),
    body('room').optional().isMongoId().withMessage('Room must be valid.'),
    handleValidationErrors,
  ],
  asyncHandler(updateTenant),
);
router.delete(
  '/:id/permanent',
  allowRoles('super_admin'),
  [mongoIdParam(), handleValidationErrors],
  asyncHandler(purgeTenant),
);
router.delete(
  '/:id',
  [mongoIdParam(), handleValidationErrors],
  asyncHandler(deleteTenant),
);
router.post(
  '/:id/documents',
  upload.array('documents', 10),
  [mongoIdParam(), handleValidationErrors],
  asyncHandler(uploadTenantDocuments),
);

module.exports = router;
