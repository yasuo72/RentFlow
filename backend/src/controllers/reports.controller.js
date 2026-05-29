const dayjs = require('dayjs');

const Payment = require('../models/Payment');
const Room = require('../models/Room');
const Tenant = require('../models/Tenant');
const { generateMonthlyCollectionReport } = require('../services/pdf.service');
const { sendError, sendSuccess } = require('../utils/response');

function getPaymentTotalDue(payment, fallbackMonthlyRent = 0) {
  if (!payment) {
    return Number(fallbackMonthlyRent || 0);
  }

  return (
    Number(payment.monthlyRentDue || fallbackMonthlyRent || 0) +
    Number(payment.carriedForwardAmount || 0) +
    Number(payment.manualDueAmount || 0)
  );
}

async function monthlyCollectionReport(req, res) {
  const date = req.query.month ? dayjs(req.query.month) : dayjs();
  const month = req.query.label || date.format('MMMM YYYY');
  const year = Number(req.query.year || date.year());

  const payments = await Payment.find({ month, year })
    .populate('room', 'roomNumber')
    .populate('tenant', 'fullName');

  const totals = {
    collected: payments.reduce((sum, payment) => sum + payment.amountPaid, 0),
    pending: payments.reduce((sum, payment) => sum + payment.remainingAmount, 0),
  };

  const pdfBuffer = await generateMonthlyCollectionReport({
    month,
    year,
    payments,
    totals,
  });

  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename="rentflow-${month}.pdf"`);
  return res.send(pdfBuffer);
}

async function yearlyIncome(req, res) {
  const year = Number(req.query.year || dayjs().year());
  const payments = await Payment.find({ year });

  const months = Array.from({ length: 12 }).map((_, index) =>
    dayjs().year(year).month(index).format('MMMM YYYY'),
  );

  const data = months.map((monthLabel, index) => {
    const monthPayments = payments.filter((payment) => payment.month === monthLabel);
    return {
      month: dayjs().year(year).month(index).format('MMM'),
      fullMonth: monthLabel,
      collected: monthPayments.reduce((sum, payment) => sum + payment.amountPaid, 0),
      pending: monthPayments.reduce((sum, payment) => sum + payment.remainingAmount, 0),
    };
  });

  return sendSuccess(res, {
    data,
  });
}

async function tenantHistory(req, res) {
  const tenant = await Tenant.findById(req.params.id);

  if (!tenant) {
    return sendError(res, {
      statusCode: 404,
      message: 'Tenant not found.',
    });
  }

  const payments = await Payment.find({ tenant: tenant._id })
    .populate('room', 'roomNumber')
    .populate('recordedBy', 'name')
    .sort({ year: -1, paymentDate: -1 });

  return sendSuccess(res, {
    data: {
      tenant,
      payments,
    },
  });
}

async function dueReport(req, res) {
  const month = dayjs().format('MMMM YYYY');
  const year = dayjs().year();
  const rooms = await Room.find({ status: 'occupied' }).populate('currentTenant', 'fullName phone');
  const payments = await Payment.find({ month, year }).select(
    'room remainingAmount amountPaid monthlyRentDue carriedForwardAmount manualDueAmount advanceAmount',
  );
  const paymentMap = new Map(payments.map((payment) => [String(payment.room), payment]));

  const dues = rooms
    .filter((room) => {
      const payment = paymentMap.get(String(room._id));
      return !payment || payment.remainingAmount > 0;
    })
    .map((room) => ({
      roomId: room._id,
      roomNumber: room.roomNumber,
      tenantName: room.currentTenant?.fullName || 'Unknown',
      totalDue: getPaymentTotalDue(paymentMap.get(String(room._id)), room.monthlyRent),
      remainingAmount: paymentMap.get(String(room._id))?.remainingAmount || room.monthlyRent,
    }))
    .sort((a, b) => b.remainingAmount - a.remainingAmount);

  return sendSuccess(res, {
    data: {
      month,
      year,
      dues,
    },
  });
}

module.exports = {
  monthlyCollectionReport,
  yearlyIncome,
  tenantHistory,
  dueReport,
};
