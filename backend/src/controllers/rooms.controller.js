const dayjs = require('dayjs');

const ActivityLog = require('../models/ActivityLog');
const Room = require('../models/Room');
const Payment = require('../models/Payment');
const Tenant = require('../models/Tenant');
const { uploadBuffer } = require('../config/cloudinary');
const {
  buildCurrentMonthSnapshot,
  buildRoomPaymentContextMap,
  getMonthContext,
} = require('../services/payment-state.service');
const { emitEvent } = require('../services/socket.service');
const { sendError, sendSuccess } = require('../utils/response');

async function attachCurrentMonthStatus(rooms) {
  const { month, year } = getMonthContext();
  const roomIds = rooms.map((room) => room._id);
  const paymentContextMap = await buildRoomPaymentContextMap(roomIds, month, year);

  return rooms.map((room) => {
    const paymentContext = paymentContextMap.get(String(room._id)) || {};
    const payment = paymentContext.currentPayment || null;
    const isOccupied = room.status === 'occupied';

    let paymentStatus = 'vacant';
    if (isOccupied && payment) {
      paymentStatus = payment.remainingAmount > 0
        ? Number(payment.amountPaid || 0) > 0
          ? 'partial'
          : 'pending'
        : 'paid';
    } else if (isOccupied) {
      paymentStatus = 'pending';
    }

    return {
      ...room.toObject(),
      currentMonthPayment: isOccupied
        ? buildCurrentMonthSnapshot({
            roomMonthlyRent: room.monthlyRent,
            currentPayment: payment,
            previousRemaining: paymentContext.previousRemaining || 0,
          })
        : null,
      currentMonthStatus: paymentStatus,
    };
  });
}

async function listRooms(req, res) {
  const rooms = await Room.find()
    .populate('currentTenant', 'fullName phone whatsappNumber joiningDate profilePhoto documents')
    .sort({ roomNumber: 1 });

  return sendSuccess(res, {
    data: await attachCurrentMonthStatus(rooms),
  });
}

async function getRoom(req, res) {
  const room = await Room.findById(req.params.id).populate('currentTenant');

  if (!room) {
    return sendError(res, {
      statusCode: 404,
      message: 'Room not found.',
    });
  }

  const payments = await Payment.find({ room: room._id })
    .populate('recordedBy', 'name')
    .populate('tenant', 'fullName')
    .sort({ year: -1, paymentDate: -1 })
    .limit(6);

  const [roomWithStatus] = await attachCurrentMonthStatus([room]);

  return sendSuccess(res, {
    data: {
      ...roomWithStatus,
      paymentHistory: payments,
    },
  });
}

async function createRoom(req, res) {
  const existingRoom = await Room.findOne({ roomNumber: req.body.roomNumber });

  if (existingRoom) {
    return sendError(res, {
      statusCode: 409,
      message: 'A room with this number already exists.',
    });
  }

  const room = await Room.create(req.body);

  await req.logActivity({
    action: 'ROOM_CREATED',
    details: `Created room ${room.roomNumber}.`,
    entityType: 'room',
    entityId: room._id,
  });

  emitEvent('room:updated', { room });

  return sendSuccess(res, {
    statusCode: 201,
    message: 'Room created successfully.',
    data: room,
  });
}

async function updateRoom(req, res) {
  const room = await Room.findById(req.params.id);

  if (!room) {
    return sendError(res, {
      statusCode: 404,
      message: 'Room not found.',
    });
  }

  Object.assign(room, req.body);
  room.updatedAt = new Date();
  await room.save();

  await req.logActivity({
    action: 'ROOM_UPDATED',
    details: `Updated room ${room.roomNumber}.`,
    entityType: 'room',
    entityId: room._id,
  });

  emitEvent('room:updated', { room });

  return sendSuccess(res, {
    message: 'Room updated successfully.',
    data: room,
  });
}

async function deleteRoom(req, res) {
  const room = await Room.findById(req.params.id);

  if (!room) {
    return sendError(res, {
      statusCode: 404,
      message: 'Room not found.',
    });
  }

  if (room.status === 'occupied') {
    return sendError(res, {
      statusCode: 400,
      message: 'Occupied rooms cannot be deleted.',
    });
  }

  const [payments, tenants] = await Promise.all([
    Payment.find({ room: room._id }).select('_id'),
    Tenant.find({ room: room._id }).select('_id'),
  ]);

  const paymentIds = payments.map((payment) => payment._id);
  const tenantIds = tenants.map((tenant) => tenant._id);
  const activityFilters = [
    { entityType: 'room', entityId: room._id },
  ];

  if (paymentIds.length > 0) {
    activityFilters.push({
      entityType: 'payment',
      entityId: { $in: paymentIds },
    });
  }

  if (tenantIds.length > 0) {
    activityFilters.push({
      entityType: 'tenant',
      entityId: { $in: tenantIds },
    });
  }

  await ActivityLog.deleteMany({ $or: activityFilters });
  await Payment.deleteMany({ room: room._id });
  await Tenant.deleteMany({ room: room._id });

  await room.deleteOne();

  emitEvent('room:updated', { room: { _id: room._id, deleted: true } });
  emitEvent('payment:new', {
    payment: { deleted: true, roomId: String(room._id) },
    roomNumber: room.roomNumber,
  });

  return sendSuccess(res, {
    message: 'Room deleted successfully.',
  });
}

async function uploadRoomPhotos(req, res) {
  const room = await Room.findById(req.params.id);

  if (!room) {
    return sendError(res, {
      statusCode: 404,
      message: 'Room not found.',
    });
  }

  if (!req.files?.length) {
    return sendError(res, {
      statusCode: 400,
      message: 'At least one photo is required.',
    });
  }

  const uploads = await Promise.all(
    req.files.map((file) => uploadBuffer(file.buffer, 'rentflow/rooms', 'image')),
  );

  room.photos = [...room.photos, ...uploads.map((upload) => upload.secure_url)];
  await room.save();

  await req.logActivity({
    action: 'ROOM_PHOTOS_UPLOADED',
    details: `Uploaded ${uploads.length} photo(s) for room ${room.roomNumber}.`,
    entityType: 'room',
    entityId: room._id,
  });

  emitEvent('room:updated', { room });

  return sendSuccess(res, {
    message: 'Room photos uploaded successfully.',
    data: room,
  });
}

module.exports = {
  listRooms,
  getRoom,
  createRoom,
  updateRoom,
  deleteRoom,
  uploadRoomPhotos,
};
