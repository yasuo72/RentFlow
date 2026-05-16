const cron = require('node-cron');

const { initializeFirebase } = require('../config/firebase');
const Room = require('../models/Room');
const User = require('../models/User');
const {
  buildCurrentMonthSnapshot,
  buildRoomPaymentContextMap,
  getMonthLabel,
} = require('./payment-state.service');

const firebaseAdmin = initializeFirebase();

function stringifyData(data) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, value == null ? '' : String(value)]),
  );
}

async function sendToAllUsers({ title, body, data = {} }) {
  if (!firebaseAdmin) {
    return { sent: false, reason: 'firebase_not_configured' };
  }

  const users = await User.find({
    isActive: true,
    fcmToken: { $exists: true, $ne: null, $ne: '' },
  }).select('fcmToken');

  const dedupedUsers = [];
  const seen = new Set();

  users.forEach((user) => {
    if (!user.fcmToken || seen.has(user.fcmToken)) {
      return;
    }

    seen.add(user.fcmToken);
    dedupedUsers.push(user);
  });

  const tokens = dedupedUsers.map((user) => user.fcmToken);

  if (!tokens.length) {
    return { sent: false, reason: 'no_tokens' };
  }

  const response = await firebaseAdmin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: stringifyData(data),
    android: {
      priority: 'high',
      notification: {
        channelId: 'rentflow_live_updates',
        sound: 'default',
      },
    },
  });

  const invalidTokens = [];

  response.responses.forEach((result, index) => {
    const errorCode = result.error?.code;
    if (
      errorCode === 'messaging/registration-token-not-registered' ||
      errorCode === 'messaging/invalid-registration-token'
    ) {
      invalidTokens.push(tokens[index]);
    }
  });

  if (invalidTokens.length) {
    await User.updateMany(
      { fcmToken: { $in: invalidTokens } },
      { $unset: { fcmToken: '' } },
    );
  }

  return {
    sent: true,
    successCount: response.successCount,
    failureCount: response.failureCount,
    invalidTokenCount: invalidTokens.length,
  };
}

function getIstDateParts(date = new Date()) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: 'numeric',
    day: 'numeric',
  }).formatToParts(date);

  const values = Object.fromEntries(
    parts
      .filter((part) => part.type !== 'literal')
      .map((part) => [part.type, part.value]),
  );

  return {
    year: Number(values.year),
    month: Number(values.month),
    day: Number(values.day),
  };
}

function createIstDate(year, month, day = 1) {
  const paddedYear = String(year).padStart(4, '0');
  const paddedMonth = String(month).padStart(2, '0');
  const paddedDay = String(day).padStart(2, '0');
  return new Date(`${paddedYear}-${paddedMonth}-${paddedDay}T00:00:00+05:30`);
}

function getLastDayOfMonth(year, month) {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

function formatCurrency(amount) {
  return `Rs ${Number(amount || 0).toLocaleString('en-IN')}`;
}

function buildRoomPreview(items) {
  const roomLabels = items.slice(0, 3).map(({ room }) => `Room ${room.roomNumber}`);

  if (items.length <= 3) {
    return roomLabels.join(', ');
  }

  return `${roomLabels.join(', ')} +${items.length - 3} more`;
}

async function getReminderRoomStates({ month, year }) {
  const rooms = await Room.find({ status: 'occupied' }).populate(
    'currentTenant',
    'fullName',
  );
  const contextMap = await buildRoomPaymentContextMap(
    rooms.map((room) => room._id),
    month,
    year,
  );

  return rooms.map((room) => {
    const context = contextMap.get(String(room._id));
    const snapshot = buildCurrentMonthSnapshot({
      roomMonthlyRent: room.monthlyRent,
      currentPayment: context?.currentPayment || null,
      previousRemaining: context?.previousRemaining || 0,
    });

    return { room, snapshot };
  });
}

async function sendFifthDayReminder() {
  const parts = getIstDateParts();
  const month = getMonthLabel(createIstDate(parts.year, parts.month, 1));
  const roomStates = await getReminderRoomStates({ month, year: parts.year });
  const dueRooms = roomStates.filter(
    ({ snapshot }) => Number(snapshot.remainingAmount || 0) > 0,
  );

  if (!dueRooms.length) {
    return;
  }

  const totalPending = dueRooms.reduce(
    (sum, { snapshot }) => sum + Number(snapshot.remainingAmount || 0),
    0,
  );

  await sendToAllUsers({
    title: `Rent due reminder for ${month}`,
    body: `${buildRoomPreview(dueRooms)} still need rent updates. Pending ${formatCurrency(totalPending)}.`,
    data: {
      type: 'rent_due_day_5',
      month,
      roomCount: dueRooms.length,
      totalPending,
    },
  });
}

async function sendMonthEndReminder() {
  const parts = getIstDateParts();
  const month = getMonthLabel(createIstDate(parts.year, parts.month, 1));
  const roomStates = await getReminderRoomStates({ month, year: parts.year });
  const dueRooms = roomStates.filter(
    ({ snapshot }) => Number(snapshot.remainingAmount || 0) > 0,
  );

  if (!dueRooms.length) {
    return;
  }

  await sendToAllUsers({
    title: `Month closing today for ${month}`,
    body: `${buildRoomPreview(dueRooms)} still have pending rent before the month closes.`,
    data: {
      type: 'rent_month_end_reminder',
      month,
      roomCount: dueRooms.length,
    },
  });
}

async function sendOverdueCarryForwardReminder() {
  const parts = getIstDateParts();
  const month = getMonthLabel(createIstDate(parts.year, parts.month, 1));
  const roomStates = await getReminderRoomStates({ month, year: parts.year });
  const overdueRooms = roomStates.filter(
    ({ snapshot }) =>
      Number(snapshot.carriedForwardAmount || 0) > 0 &&
      Number(snapshot.remainingAmount || 0) > 0,
  );

  if (!overdueRooms.length) {
    return;
  }

  const carriedForwardTotal = overdueRooms.reduce(
    (sum, { snapshot }) => sum + Number(snapshot.carriedForwardAmount || 0),
    0,
  );

  await sendToAllUsers({
    title: `Overdue rent carried into ${month}`,
    body: `${buildRoomPreview(overdueRooms)} still have unpaid rent from last month. Carry forward ${formatCurrency(carriedForwardTotal)}.`,
    data: {
      type: 'rent_overdue_reminder',
      month,
      roomCount: overdueRooms.length,
      carriedForwardTotal,
    },
  });
}

function scheduleReminder(expression, jobName, task) {
  cron.schedule(
    expression,
    () => {
      task().catch((error) => {
        console.error(`RentFlow reminder job failed (${jobName}):`, error);
      });
    },
    {
      timezone: 'Asia/Kolkata',
    },
  );
}

function startRentReminderJobs() {
  scheduleReminder('0 9 5 * *', 'fifth-day-due', sendFifthDayReminder);
  scheduleReminder('0 9 * * *', 'carried-forward-overdue', sendOverdueCarryForwardReminder);
  scheduleReminder('0 19 28-31 * *', 'month-end-final', async () => {
    const parts = getIstDateParts();
    const isLastDay = parts.day === getLastDayOfMonth(parts.year, parts.month);

    if (!isLastDay) {
      return;
    }

    await sendMonthEndReminder();
  });
}

module.exports = {
  sendToAllUsers,
  startRentReminderJobs,
  startOverdueReminderJob: startRentReminderJobs,
};
