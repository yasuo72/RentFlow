const dayjs = require('dayjs');
const { v4: uuidv4 } = require('uuid');

const ActivityLog = require('../models/ActivityLog');
const Room = require('../models/Room');
const Tenant = require('../models/Tenant');
const Payment = require('../models/Payment');
const { uploadBuffer } = require('../config/cloudinary');
const { emitEvent } = require('../services/socket.service');
const { sendToAllUsers } = require('../services/notification.service');
const {
  buildCurrentMonthSnapshot,
  buildRoomPaymentContextMap,
  getMonthContext,
} = require('../services/payment-state.service');
const { sendError, sendSuccess } = require('../utils/response');

function toMoney(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
}

function getReceiptNumber(dateValue) {
  return `RF-${dayjs(dateValue).format('YYYYMM')}-${uuidv4().slice(0, 4).toUpperCase()}`;
}

function ensureArray(value) {
  if (Array.isArray(value)) {
    return value;
  }

  if (value === undefined || value === null || value === '') {
    return [];
  }

  return [value];
}

function buildEmergencyContact(body) {
  const name = body.emergencyContactName || body['emergencyContact.name'] || body['emergencyContact[name]'];
  const phone = body.emergencyContactPhone || body['emergencyContact.phone'] || body['emergencyContact[phone]'];
  const relation = body.emergencyContactRelation || body['emergencyContact.relation'] || body['emergencyContact[relation]'];

  if (!name && !phone && !relation) {
    return undefined;
  }

  return {
    name,
    phone,
    relation,
  };
}

function buildTenantPayload(body) {
  const payload = {};
  const fields = [
    'fullName',
    'phone',
    'whatsappNumber',
    'alternatePhone',
    'idNumber',
    'occupation',
    'permanentAddress',
    'notes',
    'room',
    'openingDueRemark',
  ];

  fields.forEach((field) => {
    if (body[field] !== undefined) {
      payload[field] = body[field];
    }
  });

  if (body.joiningDate) {
    payload.joiningDate = new Date(body.joiningDate);
  }

  if (body.leavingDate) {
    payload.leavingDate = new Date(body.leavingDate);
  }

  if (body.familyMembers !== undefined && body.familyMembers !== '') {
    payload.familyMembers = Number(body.familyMembers);
  }

  if (body.openingDueAmount !== undefined && body.openingDueAmount !== '') {
    payload.openingDueAmount = toMoney(body.openingDueAmount);
  }

  const emergencyContact = buildEmergencyContact(body);
  if (emergencyContact) {
    payload.emergencyContact = emergencyContact;
  }

  return payload;
}

async function createOpeningDuePayment({ tenant, room, req }) {
  const openingDueAmount = toMoney(tenant.openingDueAmount);

  if (openingDueAmount <= 0) {
    return null;
  }

  const paymentDate = new Date();
  const { month, year } = getMonthContext(paymentDate);
  const remark =
    tenant.openingDueRemark ||
    'Opening pending balance added during tenant registration.';
  const monthlyRentDue = Number(room.monthlyRent || 0);
  let payment = await Payment.findOne({ room: room._id, month, year });
  const isExistingPayment = Boolean(payment);
  let shouldLogActivity = !isExistingPayment;

  if (payment) {
    const previousManualDue = Number(payment.manualDueAmount || 0);
    const previousTenant = String(payment.tenant || '');
    const paid = Number(payment.amountPaid || 0);
    const carriedForward = Number(payment.carriedForwardAmount || 0);
    const totalDue = monthlyRentDue + carriedForward + openingDueAmount;

    shouldLogActivity =
      previousManualDue !== openingDueAmount ||
      previousTenant !== String(tenant._id) ||
      Number(payment.monthlyRentDue || 0) !== monthlyRentDue;

    payment.tenant = tenant._id;
    payment.monthlyRentDue = monthlyRentDue;
    payment.manualDueAmount = openingDueAmount;
    payment.manualDueRemark = remark;
    payment.remainingAmount = Math.max(totalDue - paid, 0);
    payment.isPartialPayment = payment.remainingAmount > 0;
    payment.remark = payment.remark || remark;
    await payment.save();
  } else {
    payment = await Payment.create({
      tenant: tenant._id,
      room: room._id,
      month,
      year,
      monthlyRentDue,
      carriedForwardAmount: 0,
      manualDueAmount: openingDueAmount,
      manualDueRemark: remark,
      amountPaid: 0,
      remainingAmount: monthlyRentDue + openingDueAmount,
      advanceAmount: 0,
      paymentMethod: 'cash',
      paymentDate,
      remark,
      receiptNumber: getReceiptNumber(paymentDate),
      isPartialPayment: true,
      recordedBy: req.user._id,
      entries: [],
    });
  }

  if (shouldLogActivity) {
    await req.logActivity({
      action: isExistingPayment ? 'OPENING_DUE_UPDATED' : 'OPENING_DUE_ADDED',
      details: `Saved opening due ${openingDueAmount} for ${tenant.fullName} in room ${room.roomNumber}.`,
      entityType: 'payment',
      entityId: payment._id,
    });
  }

  return payment.populate([
    { path: 'room', select: 'roomNumber monthlyRent' },
    { path: 'tenant', select: 'fullName phone' },
    { path: 'recordedBy', select: 'name role' },
  ]);
}

async function uploadTenantAssets(req, tenant) {
  const profilePhotoFile = req.files?.profilePhoto?.[0];
  const documentFiles = req.files?.documents || [];

  if (profilePhotoFile) {
    const upload = await uploadBuffer(
      profilePhotoFile.buffer,
      'rentflow/tenants/profile-photos',
      'image',
    );
    tenant.profilePhoto = upload.secure_url;
  }

  if (!documentFiles.length) {
    return;
  }

  const docTypes = ensureArray(req.body.documentTypes || req.body.types);
  const uploads = await Promise.all(
    documentFiles.map((file) =>
      uploadBuffer(file.buffer, 'rentflow/tenants/documents', 'auto'),
    ),
  );

  uploads.forEach((upload, index) => {
    tenant.documents.push({
      type: docTypes[index] || 'other',
      url: upload.secure_url,
      name: documentFiles[index].originalname,
    });
  });
}

async function listTenants(req, res) {
  const { month, year } = getMonthContext();
  const tenants = await Tenant.find({ isActive: true }).populate('room').sort({ fullName: 1 });
  const roomIds = tenants.map((tenant) => tenant.room?._id).filter(Boolean);
  const paymentContextMap = await buildRoomPaymentContextMap(roomIds, month, year);

  const data = tenants.map((tenant) => ({
    ...tenant.toObject(),
    currentMonthPayment: tenant.room
      ? buildCurrentMonthSnapshot({
          roomMonthlyRent: tenant.room.monthlyRent,
          currentPayment:
            paymentContextMap.get(String(tenant.room._id))?.currentPayment || null,
          previousRemaining:
            paymentContextMap.get(String(tenant.room._id))?.previousRemaining || 0,
        })
      : null,
  }));

  return sendSuccess(res, {
    data,
  });
}

async function listInactiveTenants(req, res) {
  const tenants = await Tenant.find({ isActive: false }).populate('room').sort({ leavingDate: -1 });

  return sendSuccess(res, {
    data: tenants,
  });
}

async function getTenant(req, res) {
  const tenant = await Tenant.findById(req.params.id).populate('room');

  if (!tenant) {
    return sendError(res, {
      statusCode: 404,
      message: 'Tenant not found.',
    });
  }

  const paymentHistory = await Payment.find({ tenant: tenant._id })
    .populate('recordedBy', 'name')
    .sort({ year: -1, paymentDate: -1 });
  const { month, year } = getMonthContext();
  const paymentContextMap = tenant.room
    ? await buildRoomPaymentContextMap([tenant.room._id], month, year)
    : new Map();
  const paymentContext = tenant.room
    ? paymentContextMap.get(String(tenant.room._id)) || {}
    : {};

  return sendSuccess(res, {
    data: {
      ...tenant.toObject(),
      currentMonthPayment: tenant.room
        ? buildCurrentMonthSnapshot({
            roomMonthlyRent: tenant.room.monthlyRent,
            currentPayment: paymentContext.currentPayment || null,
            previousRemaining: paymentContext.previousRemaining || 0,
          })
        : null,
      paymentHistory,
    },
  });
}

async function createTenant(req, res) {
  const room = await Room.findById(req.body.room);

  if (!room) {
    return sendError(res, {
      statusCode: 404,
      message: 'Assigned room not found.',
    });
  }

  if (room.status === 'occupied') {
    return sendError(res, {
      statusCode: 400,
      message: 'This room is already occupied.',
    });
  }

  const tenant = new Tenant(buildTenantPayload(req.body));
  await uploadTenantAssets(req, tenant);
  await tenant.save();

  room.status = 'occupied';
  room.currentTenant = tenant._id;
  await room.save();

  const openingPayment = await createOpeningDuePayment({ tenant, room, req });

  await req.logActivity({
    action: 'TENANT_ADDED',
    details: `Added tenant ${tenant.fullName} to room ${room.roomNumber}${
      tenant.openingDueAmount > 0
        ? ` with opening due ${tenant.openingDueAmount}`
        : ''
    }.`,
    entityType: 'tenant',
    entityId: tenant._id,
  });

  emitEvent('tenant:added', {
    tenant,
    roomNumber: room.roomNumber,
  });
  emitEvent('room:updated', { room });
  if (openingPayment) {
    emitEvent('payment:new', {
      payment: openingPayment,
      roomNumber: room.roomNumber,
      tenantName: tenant.fullName,
      recordedBy: req.user.name,
    });
  }

  await sendToAllUsers({
    title: 'New Tenant Added',
    body: `${tenant.fullName} moved into Room ${room.roomNumber}${
      tenant.openingDueAmount > 0
        ? ` with opening due Rs ${tenant.openingDueAmount}.`
        : '.'
    }`,
    data: {
      type: 'tenant_added',
      tenantId: String(tenant._id),
      roomId: String(room._id),
    },
  });

  return sendSuccess(res, {
    statusCode: 201,
    message: 'Tenant added successfully.',
    data: {
      ...tenant.toObject(),
      room,
      currentMonthPayment: buildCurrentMonthSnapshot({
        roomMonthlyRent: room.monthlyRent,
        currentPayment: openingPayment || null,
        previousRemaining: 0,
      }),
    },
  });
}

async function updateTenant(req, res) {
  const tenant = await Tenant.findById(req.params.id);

  if (!tenant) {
    return sendError(res, {
      statusCode: 404,
      message: 'Tenant not found.',
    });
  }

  const oldRoomId = String(tenant.room);
  const newRoomId = req.body.room ? String(req.body.room) : oldRoomId;

  if (newRoomId !== oldRoomId) {
    const oldRoom = await Room.findById(oldRoomId);
    const newRoom = await Room.findById(newRoomId);

    if (!newRoom) {
      return sendError(res, {
        statusCode: 404,
        message: 'New room not found.',
      });
    }

    if (newRoom.status === 'occupied') {
      return sendError(res, {
        statusCode: 400,
        message: 'The selected room is already occupied.',
      });
    }

    oldRoom.status = 'vacant';
    oldRoom.currentTenant = null;
    await oldRoom.save();

    newRoom.status = 'occupied';
    newRoom.currentTenant = tenant._id;
    await newRoom.save();
  }

  Object.assign(tenant, buildTenantPayload(req.body));
  await uploadTenantAssets(req, tenant);
  await tenant.save();

  const currentRoom = await Room.findById(tenant.room);
  const openingPayment =
    currentRoom && req.body.openingDueAmount !== undefined
      ? await createOpeningDuePayment({ tenant, room: currentRoom, req })
      : null;
  const { month, year } = getMonthContext();
  const paymentContextMap = currentRoom
    ? await buildRoomPaymentContextMap([currentRoom._id], month, year)
    : new Map();
  const paymentContext = currentRoom
    ? paymentContextMap.get(String(currentRoom._id)) || {}
    : {};

  await req.logActivity({
    action: 'TENANT_UPDATED',
    details: `Updated tenant ${tenant.fullName}.`,
    entityType: 'tenant',
    entityId: tenant._id,
  });

  return sendSuccess(res, {
    message: 'Tenant updated successfully.',
    data: {
      ...tenant.toObject(),
      room: currentRoom || tenant.room,
      currentMonthPayment: currentRoom
        ? buildCurrentMonthSnapshot({
            roomMonthlyRent: currentRoom.monthlyRent,
            currentPayment: openingPayment || paymentContext.currentPayment || null,
            previousRemaining: paymentContext.previousRemaining || 0,
          })
        : null,
    },
  });
}

async function deleteTenant(req, res) {
  const tenant = await Tenant.findById(req.params.id);

  if (!tenant) {
    return sendError(res, {
      statusCode: 404,
      message: 'Tenant not found.',
    });
  }

  const room = await Room.findById(tenant.room);

  tenant.isActive = false;
  tenant.leavingDate = req.body.leavingDate || new Date();
  await tenant.save();

  if (room) {
    room.status = 'vacant';
    room.currentTenant = null;
    await room.save();
    emitEvent('room:updated', { room });
  }

  await req.logActivity({
    action: 'TENANT_MARKED_LEFT',
    details: `Marked tenant ${tenant.fullName} as inactive.`,
    entityType: 'tenant',
    entityId: tenant._id,
  });

  return sendSuccess(res, {
    message: 'Tenant marked as left successfully.',
  });
}

async function purgeTenant(req, res) {
  const tenant = await Tenant.findById(req.params.id);

  if (!tenant) {
    return sendError(res, {
      statusCode: 404,
      message: 'Tenant not found.',
    });
  }

  const [room, payments] = await Promise.all([
    Room.findById(tenant.room),
    Payment.find({ tenant: tenant._id }).select('_id'),
  ]);

  const paymentIds = payments.map((payment) => payment._id);
  const activityFilters = [
    { entityType: 'tenant', entityId: tenant._id },
  ];

  if (paymentIds.length > 0) {
    activityFilters.push({
      entityType: 'payment',
      entityId: { $in: paymentIds },
    });
  }

  await ActivityLog.deleteMany({ $or: activityFilters });

  if (paymentIds.length > 0) {
    await Payment.deleteMany({ _id: { $in: paymentIds } });
  }

  if (room && String(room.currentTenant) === String(tenant._id)) {
    room.status = 'vacant';
    room.currentTenant = null;
    await room.save();
    emitEvent('room:updated', { room });
  }

  await tenant.deleteOne();

  emitEvent('payment:new', {
    payment: {
      deleted: true,
      tenantId: String(tenant._id),
    },
    roomNumber: room?.roomNumber,
  });

  return sendSuccess(res, {
    message: 'Tenant, payments, and related timeline records deleted permanently.',
  });
}

async function uploadTenantDocuments(req, res) {
  const tenant = await Tenant.findById(req.params.id);

  if (!tenant) {
    return sendError(res, {
      statusCode: 404,
      message: 'Tenant not found.',
    });
  }

  if (!req.files?.length) {
    return sendError(res, {
      statusCode: 400,
      message: 'At least one document is required.',
    });
  }

  const uploads = await Promise.all(
    req.files.map((file) =>
      uploadBuffer(file.buffer, 'rentflow/tenants/documents', 'auto'),
    ),
  );

  const docTypes = Array.isArray(req.body.types)
    ? req.body.types
    : req.body.types
      ? [req.body.types]
      : [];

  uploads.forEach((upload, index) => {
    tenant.documents.push({
      type: docTypes[index] || 'other',
      url: upload.secure_url,
      name: req.files[index].originalname,
    });
  });

  await tenant.save();

  await req.logActivity({
    action: 'TENANT_DOCUMENTS_UPLOADED',
    details: `Uploaded ${uploads.length} document(s) for ${tenant.fullName}.`,
    entityType: 'tenant',
    entityId: tenant._id,
  });

  return sendSuccess(res, {
    message: 'Tenant documents uploaded successfully.',
    data: tenant,
  });
}

module.exports = {
  listTenants,
  listInactiveTenants,
  getTenant,
  createTenant,
  updateTenant,
  deleteTenant,
  purgeTenant,
  uploadTenantDocuments,
};
