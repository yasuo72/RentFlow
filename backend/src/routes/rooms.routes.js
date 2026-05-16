const express = require('express');

const {
  createRoom,
  deleteRoom,
  getRoom,
  listRooms,
  updateRoom,
  uploadRoomPhotos,
} = require('../controllers/rooms.controller');
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

router.get('/', asyncHandler(listRooms));
router.get('/:id', [mongoIdParam(), handleValidationErrors], asyncHandler(getRoom));
router.post(
  '/',
  [
    body('roomNumber').notEmpty().withMessage('Room number is required.'),
    positiveNumberBody('monthlyRent'),
    positiveNumberBody('depositAmount').optional(),
    handleValidationErrors,
  ],
  asyncHandler(createRoom),
);
router.put(
  '/:id',
  [
    mongoIdParam(),
    positiveNumberBody('monthlyRent').optional(),
    positiveNumberBody('depositAmount').optional(),
    handleValidationErrors,
  ],
  asyncHandler(updateRoom),
);
router.delete(
  '/:id',
  allowRoles('super_admin'),
  [mongoIdParam(), handleValidationErrors],
  asyncHandler(deleteRoom),
);
router.post(
  '/:id/photos',
  upload.array('photos', 6),
  [mongoIdParam(), handleValidationErrors],
  asyncHandler(uploadRoomPhotos),
);

module.exports = router;
