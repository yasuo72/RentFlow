const dayjs = require('dayjs');
const { v4: uuidv4 } = require('uuid');

const ActivityLog = require('../models/ActivityLog');
const Payment = require('../models/Payment');
const Room = require('../models/Room');
const Tenant = require('../models/Tenant');
const { emitEvent } = require('../services/socket.service');
const { sendToAllUsers } = require('../services/notification.service');
const {
  buildCurrentMonthSnapshot,
  buildInstallmentEntry,
  getMonthContext,
  getMonthLabel,
  getPreviousPayment,
  normalizePaymentEntries,
} = require('../services/payment-state.service');
const { generatePaymentReceipt } = require('../services/pdf.service');
const { sendError, sendSuccess } = require('../utils/response');

function getReceiptNumber(dateValue) {
  return `RF-${dayjs(dateValue).format('YYYYMM')}-${uuidv4().slice(0, 4).toUpperCase()}`;
}

function toMoney(value, fallback = 0) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function getFlexiblePaymentState({
  monthlyRentDue = 0,
  carriedForwardAmount = 0,
  manualDueAmount = 0,
  amountPaid = 0,
}) {
  const totalDue =
    Number(monthlyRentDue || 0) +
    Number(carriedForwardAmount || 0) +
    Number(manualDueAmount || 0);
  const paid = Number(amountPaid || 0);

  return {
    totalDue,
    remainingAmount: Math.max(totalDue - paid, 0),
    advanceAmount: Math.max(paid - totalDue, 0),
  };
}

async function populatePayment(paymentId) {
  return Payment.findById(paymentId)
    .populate('room', 'roomNumber monthlyRent')
    .populate('tenant', 'fullName phone whatsappNumber')
    .populate('recordedBy', 'name role')
    .populate('entries.recordedBy', 'name role');
}

async function listPayments(req, res) {
  const filters = {};

  if (req.query.month) {
    filters.month = req.query.month;
  }
  if (req.query.year) {
    filters.year = Number(req.query.year);
  }
  if (req.query.room) {
    filters.room = req.query.room;
  }
  if (req.query.tenant) {
    filters.tenant = req.query.tenant;
  }
  if (req.query.status === 'paid') {
    filters.remainingAmount = 0;
  }
  if (req.query.status === 'partial') {
    filters.remainingAmount = { $gt: 0 };
    filters.amountPaid = { $gt: 0 };
  }

  const payments = await Payment.find(filters)
    .populate('room', 'roomNumber')
    .populate('tenant', 'fullName phone whatsappNumber')
    .populate('recordedBy', 'name')
    .populate('entries.recordedBy', 'name')
    .sort({ year: -1, paymentDate: -1, createdAt: -1 });

  return sendSuccess(res, {
    data: payments,
  });
}

async function getPayment(req, res) {
  const payment = await populatePayment(req.params.id);

  if (!payment) {
    return sendError(res, {
      statusCode: 404,
      message: 'Payment not found.',
    });
  }

  return sendSuccess(res, {
    data: payment,
  });
}

async function recordPayment(req, res) {
  const paymentDate = req.body.paymentDate || new Date();
  const month = req.body.month || getMonthLabel(paymentDate);
  const year = Number(req.body.year || dayjs(paymentDate).year());
  const amountReceivedToday = toMoney(req.body.amountPaid);
  const manualDueToAdd = toMoney(req.body.manualDueAmount);
  const manualDueRemark = req.body.manualDueRemark || req.body.remark;

  const [tenant, room] = await Promise.all([
    Tenant.findById(req.body.tenant),
    Room.findById(req.body.room),
  ]);

  if (!tenant || !tenant.isActive) {
    return sendError(res, {
      statusCode: 404,
      message: 'Tenant not found.',
    });
  }

  if (!room) {
    return sendError(res, {
      statusCode: 404,
      message: 'Room not found.',
    });
  }

  if (
    String(tenant.room) !== String(room._id) &&
    String(room.currentTenant) === String(tenant._id)
  ) {
    tenant.room = room._id;
    await tenant.save();
  }

  if (String(tenant.room) !== String(room._id)) {
    return sendError(res, {
      statusCode: 400,
      message:
        'This tenant is not linked to the selected room. Please open the tenant profile and reassign the room once.',
    });
  }

  let payment = await Payment.findOne({ room: room._id, month, year });

  if (payment) {
    const totalManualDue =
      Number(payment.manualDueAmount || 0) + manualDueToAdd;
    const newAmountPaid = Number(payment.amountPaid || 0) + amountReceivedToday;
    const nextState = getFlexiblePaymentState({
      monthlyRentDue: payment.monthlyRentDue,
      carriedForwardAmount: payment.carriedForwardAmount,
      manualDueAmount: totalManualDue,
      amountPaid: newAmountPaid,
    });

    payment.entries = [
      ...normalizePaymentEntries(payment),
      buildInstallmentEntry({
        amountPaid: amountReceivedToday,
        paymentMethod: req.body.paymentMethod || payment.paymentMethod,
        paymentDate,
        remark: req.body.remark,
        recordedBy: req.user._id,
      }),
    ];
    payment.manualDueAmount = totalManualDue;
    payment.manualDueRemark = manualDueToAdd > 0
      ? manualDueRemark
      : payment.manualDueRemark;
    payment.amountPaid = newAmountPaid;
    payment.remainingAmount = nextState.remainingAmount;
    payment.advanceAmount = nextState.advanceAmount;
    payment.isPartialPayment = payment.remainingAmount > 0;
    payment.paymentMethod = req.body.paymentMethod || payment.paymentMethod;
    payment.paymentDate = paymentDate;
    payment.remark = req.body.remark || payment.remark;
    payment.recordedBy = req.user._id;
    await payment.save();
  } else {
    const previousPayment = await getPreviousPayment(room._id, month, year);
    const previousRemaining = Number(previousPayment?.remainingAmount || 0);
    const nextState = getFlexiblePaymentState({
      monthlyRentDue: room.monthlyRent,
      carriedForwardAmount: previousRemaining,
      manualDueAmount: manualDueToAdd,
      amountPaid: amountReceivedToday,
    });

    payment = await Payment.create({
      tenant: tenant._id,
      room: room._id,
      month,
      year,
      monthlyRentDue: room.monthlyRent,
      carriedForwardAmount: previousRemaining,
      manualDueAmount: manualDueToAdd,
      manualDueRemark,
      amountPaid: amountReceivedToday,
      remainingAmount: nextState.remainingAmount,
      advanceAmount: nextState.advanceAmount,
      paymentMethod: req.body.paymentMethod || 'cash',
      paymentDate,
      remark: req.body.remark,
      receiptNumber: getReceiptNumber(paymentDate),
      isPartialPayment: nextState.remainingAmount > 0,
      recordedBy: req.user._id,
      entries: [
        buildInstallmentEntry({
          amountPaid: amountReceivedToday,
          paymentMethod: req.body.paymentMethod || 'cash',
          paymentDate,
          remark: req.body.remark,
          recordedBy: req.user._id,
        }),
      ],
    });
  }

  const populatedPayment = await populatePayment(payment._id);

  await req.logActivity({
    action: amountReceivedToday > 0 ? 'PAYMENT_ADDED' : 'DUE_ADDED',
    details: amountReceivedToday > 0
      ? `${req.user.name} recorded ${amountReceivedToday} for room ${room.roomNumber}.`
      : `${req.user.name} added due ${manualDueToAdd} for room ${room.roomNumber}.`,
    entityType: 'payment',
    entityId: payment._id,
  });

  emitEvent('payment:new', {
    payment: populatedPayment,
    roomNumber: room.roomNumber,
    tenantName: tenant.fullName,
    recordedBy: req.user.name,
  });
  emitEvent('room:updated', {
    room: {
      _id: room._id,
      roomNumber: room.roomNumber,
    },
  });

  await sendToAllUsers({
    title: amountReceivedToday > 0
      ? `Room ${room.roomNumber} payment recorded`
      : `Room ${room.roomNumber} due added`,
    body: amountReceivedToday > 0
      ? `Rs ${amountReceivedToday} paid by ${req.user.name}${payment.remainingAmount > 0 ? ` (Rs ${payment.remainingAmount} remaining)` : payment.advanceAmount > 0 ? ` (Rs ${payment.advanceAmount} advance)` : ''}`
      : `Rs ${manualDueToAdd} due added by ${req.user.name} (Rs ${payment.remainingAmount} remaining)`,
    data: {
      type: amountReceivedToday > 0 ? 'payment_recorded' : 'due_added',
      paymentId: String(payment._id),
      roomId: String(room._id),
    },
  });

  return sendSuccess(res, {
    statusCode: 201,
    message: 'Payment recorded successfully.',
    data: populatedPayment,
    meta: {
      totalDue:
        Number(populatedPayment.monthlyRentDue || 0) +
        Number(populatedPayment.carriedForwardAmount || 0) +
        Number(populatedPayment.manualDueAmount || 0),
    },
  });
}

async function editPayment(req, res) {
  const payment = await Payment.findById(req.params.id);

  if (!payment) {
    return sendError(res, {
      statusCode: 404,
      message: 'Payment not found.',
    });
  }

  const existingAmountPaid = Number(payment.amountPaid || 0);
  const manualDueAmount =
    req.body.manualDueAmount !== undefined
      ? toMoney(req.body.manualDueAmount)
      : Number(payment.manualDueAmount || 0);
  const updatedAmountPaid =
    req.body.amountPaid !== undefined ? Number(req.body.amountPaid) : existingAmountPaid;
  const nextState = getFlexiblePaymentState({
    monthlyRentDue: payment.monthlyRentDue,
    carriedForwardAmount: payment.carriedForwardAmount,
    manualDueAmount,
    amountPaid: updatedAmountPaid,
  });
  const normalizedEntries = normalizePaymentEntries(payment);

  payment.manualDueAmount = manualDueAmount;
  payment.manualDueRemark =
    req.body.manualDueRemark !== undefined
      ? req.body.manualDueRemark
      : payment.manualDueRemark;
  payment.amountPaid = updatedAmountPaid;
  payment.remainingAmount = nextState.remainingAmount;
  payment.advanceAmount = nextState.advanceAmount;
  payment.isPartialPayment = nextState.remainingAmount > 0;
  payment.paymentMethod = req.body.paymentMethod || payment.paymentMethod;
  payment.paymentDate = req.body.paymentDate || payment.paymentDate;
  payment.remark = req.body.remark !== undefined ? req.body.remark : payment.remark;
  payment.recordedBy = req.user._id;

  if (normalizedEntries.length > 0) {
    const delta = updatedAmountPaid - existingAmountPaid;
    const lastIndex = normalizedEntries.length - 1;
    normalizedEntries[lastIndex] = {
      ...normalizedEntries[lastIndex],
      amountPaid: Math.max(
        0,
        Number(normalizedEntries[lastIndex].amountPaid || 0) + delta,
      ),
      paymentMethod: req.body.paymentMethod || normalizedEntries[lastIndex].paymentMethod,
      paymentDate: req.body.paymentDate || normalizedEntries[lastIndex].paymentDate,
      remark:
        req.body.remark !== undefined
          ? req.body.remark
          : normalizedEntries[lastIndex].remark,
      recordedBy: req.user._id,
    };
    payment.entries = normalizedEntries;
  }

  await payment.save();

  await req.logActivity({
    action: 'PAYMENT_UPDATED',
    details: `Updated payment ${payment.receiptNumber}.`,
    entityType: 'payment',
    entityId: payment._id,
  });

  emitEvent('payment:new', {
    payment: await populatePayment(payment._id),
  });

  return sendSuccess(res, {
    message: 'Payment updated successfully.',
    data: await populatePayment(payment._id),
  });
}

async function deletePayment(req, res) {
  const payment = await Payment.findById(req.params.id).populate('room', 'roomNumber');

  if (!payment) {
    return sendError(res, {
      statusCode: 404,
      message: 'Payment not found.',
    });
  }

  await ActivityLog.deleteMany({
    entityType: 'payment',
    entityId: payment._id,
  });

  await payment.deleteOne();

  emitEvent('payment:new', {
    payment: { _id: payment._id, deleted: true },
    roomNumber: payment.room?.roomNumber,
  });

  return sendSuccess(res, {
    message: 'Payment deleted successfully.',
  });
}

async function getMonthlySummary(req, res) {
  const date = req.query.month ? dayjs(req.query.month) : dayjs();
  const month = req.query.label || getMonthLabel(date);
  const year = Number(req.query.year || date.year());

  const payments = await Payment.find({ month, year });
  const totalCollected = payments.reduce(
    (sum, payment) => sum + Number(payment.amountPaid || 0),
    0,
  );
  const totalPending = payments.reduce(
    (sum, payment) => sum + Number(payment.remainingAmount || 0),
    0,
  );

  return sendSuccess(res, {
    data: {
      month,
      year,
      totalCollected,
      totalPending,
      partialPayments: payments.filter((payment) => payment.remainingAmount > 0).length,
      fullyPaidRooms: payments.filter((payment) => payment.remainingAmount === 0).length,
    },
  });
}

async function getPendingPayments(req, res) {
  const { month, year } = getMonthContext();
  const rooms = await Room.find({ status: 'occupied' }).populate('currentTenant', 'fullName phone');
  const payments = await Payment.find({ month, year }).select(
    'room amountPaid remainingAmount monthlyRentDue carriedForwardAmount manualDueAmount manualDueRemark advanceAmount',
  );
  const paymentMap = new Map(payments.map((payment) => [String(payment.room), payment]));

  const pendingRooms = await Promise.all(
    rooms.map(async (room) => {
      const payment = paymentMap.get(String(room._id));

      if (payment && payment.remainingAmount === 0) {
        return null;
      }

      const previousPayment = await getPreviousPayment(room._id, month, year);
      const previousRemaining = Number(previousPayment?.remainingAmount || 0);
      const snapshot = buildCurrentMonthSnapshot({
        roomMonthlyRent: room.monthlyRent,
        currentPayment: payment || null,
        previousRemaining,
      });

      return {
        roomId: room._id,
        roomNumber: room.roomNumber,
        tenantName: room.currentTenant?.fullName || 'Unknown',
        monthlyRent: room.monthlyRent,
        amountPaid: snapshot.amountPaid,
        totalDue: snapshot.totalDue,
        remainingAmount: snapshot.remainingAmount,
        carriedForwardAmount: snapshot.carriedForwardAmount,
        manualDueAmount: snapshot.manualDueAmount,
        manualDueRemark: snapshot.manualDueRemark,
        advanceAmount: snapshot.advanceAmount,
        status: snapshot.amountPaid > 0 ? 'partial' : 'pending',
      };
    }),
  );

  return sendSuccess(res, {
    data: pendingRooms.filter(Boolean).sort((a, b) => b.remainingAmount - a.remainingAmount),
  });
}

async function getPaymentReceipt(req, res) {
  const payment = await populatePayment(req.params.id);

  if (!payment) {
    return sendError(res, {
      statusCode: 404,
      message: 'Payment not found.',
    });
  }

  const pdfBuffer = await generatePaymentReceipt(payment);

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader(
    'Content-Disposition',
    `attachment; filename="${payment.receiptNumber}.pdf"`,
  );

  return res.send(pdfBuffer);
}

module.exports = {
  listPayments,
  getPayment,
  recordPayment,
  editPayment,
  deletePayment,
  getMonthlySummary,
  getPendingPayments,
  getPaymentReceipt,
};
