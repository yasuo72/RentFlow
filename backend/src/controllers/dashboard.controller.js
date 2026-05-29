const dayjs = require('dayjs');

const ActivityLog = require('../models/ActivityLog');
const Expense = require('../models/Expense');
const Payment = require('../models/Payment');
const Room = require('../models/Room');
const Tenant = require('../models/Tenant');
const {
  buildCurrentMonthSnapshot,
  buildRoomPaymentContextMap,
  getMonthContext,
  normalizePaymentEntries,
} = require('../services/payment-state.service');
const { sendError, sendSuccess } = require('../utils/response');

async function getStats(req, res) {
  const now = dayjs();
  const { month, year } = getMonthContext(now);

  const [rooms, payments, tenantCount, expenseTotal] = await Promise.all([
    Room.find(),
    Payment.find({ month, year }),
    Tenant.countDocuments({ isActive: true }),
    Expense.aggregate([
      {
        $match: {
          date: {
            $gte: now.startOf('month').toDate(),
            $lt: now.endOf('month').toDate(),
          },
        },
      },
      {
        $group: {
          _id: null,
          total: { $sum: '$amount' },
        },
      },
    ]),
  ]);
  const paymentContextMap = await buildRoomPaymentContextMap(
    rooms.map((room) => room._id),
    month,
    year,
  );

  const totalCollected = payments.reduce(
    (sum, payment) => sum + Number(payment.amountPaid || 0),
    0,
  );
  const totalPending = rooms
    .filter((room) => room.status === 'occupied')
    .reduce((sum, room) => {
      const context = paymentContextMap.get(String(room._id)) || {};
      const snapshot = buildCurrentMonthSnapshot({
        roomMonthlyRent: room.monthlyRent,
        currentPayment: context.currentPayment || null,
        previousRemaining: context.previousRemaining || 0,
      });

      return sum + Number(snapshot.remainingAmount || 0);
    }, 0);

  return sendSuccess(res, {
    data: {
      totalRooms: rooms.length,
      occupied: rooms.filter((room) => room.status === 'occupied').length,
      vacant: rooms.filter((room) => room.status === 'vacant').length,
      totalCollected,
      totalPending,
      totalExpenses: expenseTotal[0]?.total || 0,
      tenantCount,
    },
  });
}

async function getMonthlyChart(req, res) {
  const months = Array.from({ length: 12 }).map((_, index) =>
    dayjs().subtract(11 - index, 'month'),
  );
  const keys = months.map((monthDate) => ({
    label: monthDate.format('MMM'),
    fullLabel: monthDate.format('MMMM YYYY'),
    year: monthDate.year(),
  }));

  const payments = await Payment.find({
    year: { $in: [...new Set(keys.map((item) => item.year))] },
  });

  const data = keys.map((key) => {
    const monthPayments = payments.filter(
      (payment) => payment.month === key.fullLabel && payment.year === key.year,
    );

    return {
      month: key.label,
      fullMonth: key.fullLabel,
      collected: monthPayments.reduce(
        (sum, payment) => sum + Number(payment.amountPaid || 0),
        0,
      ),
      pending: monthPayments.reduce(
        (sum, payment) => sum + Number(payment.remainingAmount || 0),
        0,
      ),
    };
  });

  return sendSuccess(res, {
    data,
  });
}

async function getRecentActivity(req, res) {
  const filters = {};
  const limit = Math.min(Number(req.query.limit || 20), 200);

  if (req.query.user) {
    filters.user = req.query.user;
  }

  if (req.query.action) {
    filters.action = req.query.action;
  }

  const activities = await ActivityLog.find(filters).sort({ createdAt: -1 }).limit(limit);

  return sendSuccess(res, {
    data: activities,
  });
}

async function getUpcomingDues(req, res) {
  const today = dayjs();
  const dueDate = today.date(5);
  const daysUntilDue = dueDate.diff(today, 'day');
  const { month, year } = getMonthContext(today);

  const rooms = await Room.find({ status: 'occupied' }).populate(
    'currentTenant',
    'fullName phone',
  );
  const paymentContextMap = await buildRoomPaymentContextMap(
    rooms.map((room) => room._id),
    month,
    year,
  );

  const dues = rooms
    .map((room) => {
      const context = paymentContextMap.get(String(room._id)) || {};
      const snapshot = buildCurrentMonthSnapshot({
        roomMonthlyRent: room.monthlyRent,
        currentPayment: context.currentPayment || null,
        previousRemaining: context.previousRemaining || 0,
      });

      if (snapshot.remainingAmount <= 0) {
        return null;
      }

      return {
        roomId: room._id,
        roomNumber: room.roomNumber,
        tenantName: room.currentTenant?.fullName || 'Unknown',
        dueDate: dueDate.toISOString(),
        daysUntilDue,
        pendingAmount: snapshot.remainingAmount,
      };
    })
    .filter(Boolean);

  return sendSuccess(res, {
    data: dues,
  });
}

async function getPaymentCalendar(req, res) {
  const baseDate = req.query.month ? dayjs(req.query.month) : dayjs();
  const { month, year } = getMonthContext(baseDate);

  const payments = await Payment.find({ month, year })
    .populate('room', 'roomNumber')
    .populate('tenant', 'fullName')
    .populate('entries.recordedBy', 'name')
    .populate('recordedBy', 'name')
    .sort({ paymentDate: 1, createdAt: 1 });

  const events = payments.flatMap((payment) => {
    const entries = normalizePaymentEntries(payment);
    const totalDue =
      Number(payment.monthlyRentDue || 0) +
      Number(payment.carriedForwardAmount || 0) +
      Number(payment.manualDueAmount || 0);
    let cumulativePaid = 0;

    return entries.map((entry, index) => {
      cumulativePaid += Number(entry.amountPaid || 0);

      return {
        id: `${payment._id}-${index}`,
        paymentId: String(payment._id),
        date: dayjs(entry.paymentDate || payment.paymentDate).format('YYYY-MM-DD'),
        roomNumber: payment.room?.roomNumber || '-',
        tenantName: payment.tenant?.fullName || 'Unknown',
        amountPaid: Number(entry.amountPaid || 0),
        paymentMethod: entry.paymentMethod || payment.paymentMethod || 'cash',
        remark: entry.remark || '',
        remainingAmount: Math.max(totalDue - cumulativePaid, 0),
        recordedByName:
          entry.recordedBy?.name || payment.recordedBy?.name || 'Family',
      };
    });
  });

  return sendSuccess(res, {
    data: events,
  });
}

async function deleteActivity(req, res) {
  const activity = await ActivityLog.findById(req.params.id);

  if (!activity) {
    return sendError(res, {
      statusCode: 404,
      message: 'Activity entry not found.',
    });
  }

  await activity.deleteOne();

  return sendSuccess(res, {
    message: 'Timeline entry deleted successfully.',
  });
}

async function deleteActivitiesByUser(req, res) {
  const result = await ActivityLog.deleteMany({ user: req.params.userId });

  return sendSuccess(res, {
    message: 'Selected user timeline deleted successfully.',
    data: {
      deletedCount: result.deletedCount || 0,
    },
  });
}

module.exports = {
  getStats,
  getMonthlyChart,
  getRecentActivity,
  getUpcomingDues,
  getPaymentCalendar,
  deleteActivity,
  deleteActivitiesByUser,
};
