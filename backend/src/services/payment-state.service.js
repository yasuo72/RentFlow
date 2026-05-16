const dayjs = require('dayjs');

const Payment = require('../models/Payment');

function getMonthLabel(dateValue) {
  return dayjs(dateValue).format('MMMM YYYY');
}

function getMonthContext(dateValue = new Date()) {
  return {
    month: getMonthLabel(dateValue),
    year: dayjs(dateValue).year(),
  };
}

function getPaymentTotalDue(payment, fallbackMonthlyRent = 0) {
  if (!payment) {
    return Number(fallbackMonthlyRent) || 0;
  }

  return Number(payment.amountPaid || 0) + Number(payment.remainingAmount || 0);
}

function getCarriedForwardAmount(payment, fallbackMonthlyRent = 0) {
  if (!payment) {
    return 0;
  }

  if (payment.carriedForwardAmount !== undefined && payment.carriedForwardAmount !== null) {
    return Number(payment.carriedForwardAmount) || 0;
  }

  const totalDue = getPaymentTotalDue(payment, fallbackMonthlyRent);
  const monthlyRentDue = Number(payment.monthlyRentDue || fallbackMonthlyRent || 0);
  return Math.max(totalDue - monthlyRentDue, 0);
}

function buildInstallmentEntry({
  amountPaid,
  paymentMethod = 'cash',
  paymentDate = new Date(),
  remark,
  recordedBy,
}) {
  return {
    amountPaid: Number(amountPaid) || 0,
    paymentMethod,
    paymentDate,
    remark,
    recordedBy,
  };
}

function normalizePaymentEntries(payment) {
  if (Array.isArray(payment.entries) && payment.entries.length > 0) {
    return payment.entries.map((entry) => ({
      amountPaid: Number(entry.amountPaid || 0),
      paymentMethod: entry.paymentMethod || 'cash',
      paymentDate: entry.paymentDate || payment.paymentDate || payment.createdAt || new Date(),
      remark: entry.remark,
      recordedBy: entry.recordedBy || payment.recordedBy || null,
      createdAt: entry.createdAt || payment.createdAt || payment.paymentDate || new Date(),
    }));
  }

  return [
    {
      amountPaid: Number(payment.amountPaid || 0),
      paymentMethod: payment.paymentMethod || 'cash',
      paymentDate: payment.paymentDate || payment.createdAt || new Date(),
      remark: payment.remark,
      recordedBy: payment.recordedBy || null,
      createdAt: payment.createdAt || payment.paymentDate || new Date(),
    },
  ];
}

async function getPreviousPayment(roomId, currentMonth, currentYear) {
  const payments = await Payment.find({ room: roomId }).sort({
    year: -1,
    paymentDate: -1,
    createdAt: -1,
  });

  return (
    payments.find(
      (payment) => !(payment.month === currentMonth && payment.year === currentYear),
    ) || null
  );
}

async function buildRoomPaymentContextMap(roomIds, month, year) {
  const ids = (roomIds || []).map((roomId) => String(roomId));

  if (!ids.length) {
    return new Map();
  }

  const payments = await Payment.find({ room: { $in: ids } }).sort({
    room: 1,
    year: -1,
    paymentDate: -1,
    createdAt: -1,
  });

  const contexts = new Map(
    ids.map((id) => [
      id,
      { currentPayment: null, previousPayment: null, previousRemaining: 0 },
    ]),
  );

  for (const payment of payments) {
    const roomId = String(payment.room);
    const context = contexts.get(roomId);

    if (!context) {
      continue;
    }

    const isCurrentMonth = payment.month === month && payment.year === year;

    if (isCurrentMonth && !context.currentPayment) {
      context.currentPayment = payment;
      continue;
    }

    if (!isCurrentMonth && !context.previousPayment) {
      context.previousPayment = payment;
      context.previousRemaining = Number(payment.remainingAmount || 0);
    }
  }

  return contexts;
}

function buildCurrentMonthSnapshot({
  roomMonthlyRent = 0,
  currentPayment = null,
  previousRemaining = 0,
}) {
  const monthlyRentDue = Number(currentPayment?.monthlyRentDue || roomMonthlyRent || 0);

  if (currentPayment) {
    const amountPaid = Number(currentPayment.amountPaid || 0);
    const remainingAmount = Number(currentPayment.remainingAmount || 0);
    const carriedForwardAmount = getCarriedForwardAmount(currentPayment, roomMonthlyRent);

    return {
      amountPaid,
      remainingAmount,
      monthlyRentDue,
      carriedForwardAmount,
      totalDue: amountPaid + remainingAmount,
      paymentDate: currentPayment.paymentDate || null,
      paymentMethod: currentPayment.paymentMethod || 'cash',
      remark: currentPayment.remark || '',
    };
  }

  const carriedForwardAmount = Number(previousRemaining || 0);
  const totalDue = monthlyRentDue + carriedForwardAmount;

  return {
    amountPaid: 0,
    remainingAmount: totalDue,
    monthlyRentDue,
    carriedForwardAmount,
    totalDue,
    paymentDate: null,
    paymentMethod: 'cash',
    remark: '',
  };
}

module.exports = {
  buildCurrentMonthSnapshot,
  buildInstallmentEntry,
  buildRoomPaymentContextMap,
  getCarriedForwardAmount,
  getMonthContext,
  getMonthLabel,
  getPaymentTotalDue,
  getPreviousPayment,
  normalizePaymentEntries,
};
