require('dotenv').config();

const http = require('http');

const compression = require('compression');
const cors = require('cors');
const express = require('express');
const helmet = require('helmet');
const mongoose = require('mongoose');
const morgan = require('morgan');

const { configureCloudinary } = require('./config/cloudinary');
const { connectDB } = require('./config/db');
const authRoutes = require('./routes/auth.routes');
const dashboardRoutes = require('./routes/dashboard.routes');
const expensesRoutes = require('./routes/expenses.routes');
const paymentsRoutes = require('./routes/payments.routes');
const reportsRoutes = require('./routes/reports.routes');
const roomsRoutes = require('./routes/rooms.routes');
const tenantsRoutes = require('./routes/tenants.routes');
const usersRoutes = require('./routes/users.routes');
const { ensureSuperAdmin } = require('./services/bootstrap.service');
const { startRentReminderJobs } = require('./services/notification.service');
const { initSocket } = require('./services/socket.service');
const { sendError, sendSuccess } = require('./utils/response');

const app = express();
const server = http.createServer(app);

function getAllowedOrigins() {
  const raw = (process.env.CLIENT_URL || '*').trim();

  if (!raw || raw === '*') {
    return '*';
  }

  return raw
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
}

function buildCorsOriginChecker(allowedOrigins) {
  return (origin, callback) => {
    if (!origin) {
      return callback(null, true);
    }

    if (allowedOrigins === '*') {
      return callback(null, true);
    }

    if (allowedOrigins.includes(origin)) {
      return callback(null, true);
    }

    return callback(new Error('Origin not allowed by CORS.'));
  };
}

function shouldRunScheduledJobs() {
  return process.env.ENABLE_SCHEDULED_JOBS !== 'false';
}

const allowedOrigins = getAllowedOrigins();
const corsOriginChecker = buildCorsOriginChecker(allowedOrigins);

app.set('trust proxy', 1);
app.use(helmet());
app.use(compression());
app.use(
  cors({
    origin: corsOriginChecker,
    credentials: true,
  }),
);
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(morgan('dev'));

app.get('/health', (req, res) => {
  sendSuccess(res, {
    data: {
      status: 'ok',
      timestamp: new Date().toISOString(),
    },
  });
});

app.use('/api/auth', authRoutes);
app.use('/api/users', usersRoutes);
app.use('/api/rooms', roomsRoutes);
app.use('/api/tenants', tenantsRoutes);
app.use('/api/payments', paymentsRoutes);
app.use('/api/expenses', expensesRoutes);
app.use('/api/reports', reportsRoutes);
app.use('/api/dashboard', dashboardRoutes);

app.use((req, res) => {
  return sendError(res, {
    statusCode: 404,
    message: 'Route not found.',
  });
});

app.use((error, req, res, next) => {
  console.error(error);

  if (error.code === 11000) {
    return sendError(res, {
      statusCode: 409,
      message: `Duplicate value for ${Object.keys(error.keyPattern).join(', ')}.`,
    });
  }

  return sendError(res, {
    statusCode: error.statusCode || 500,
    message: error.message || 'Internal server error.',
  });
});

async function start() {
  await connectDB();
  await ensureSuperAdmin();
  configureCloudinary();
  initSocket(server, {
    origin: corsOriginChecker,
  });

  if (shouldRunScheduledJobs()) {
    startRentReminderJobs();
  }

  const port = Number(process.env.PORT || 5000);
  server.listen(port, '0.0.0.0', () => {
    console.log(`RentFlow backend running on port ${port}`);
  });
}

let isShuttingDown = false;

async function shutdown(signal) {
  if (isShuttingDown) {
    return;
  }

  isShuttingDown = true;
  console.log(`${signal} received. Shutting down RentFlow backend...`);

  server.close(async () => {
    try {
      await mongoose.connection.close();
      process.exit(0);
    } catch (error) {
      console.error('Failed to close MongoDB connection cleanly:', error);
      process.exit(1);
    }
  });

  setTimeout(() => {
    console.error('Forced shutdown after timeout.');
    process.exit(1);
  }, 10000).unref();
}

start().catch((error) => {
  console.error('Failed to start RentFlow backend:', error);
  process.exit(1);
});

process.on('SIGTERM', () => {
  shutdown('SIGTERM');
});

process.on('SIGINT', () => {
  shutdown('SIGINT');
});

module.exports = {
  app,
  server,
};
