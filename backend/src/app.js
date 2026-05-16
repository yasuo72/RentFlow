require('dotenv').config();

const http = require('http');

const compression = require('compression');
const cors = require('cors');
const express = require('express');
const helmet = require('helmet');
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
const { startRentReminderJobs } = require('./services/notification.service');
const { initSocket } = require('./services/socket.service');
const { sendError, sendSuccess } = require('./utils/response');

const app = express();
const server = http.createServer(app);

app.use(helmet());
app.use(compression());
app.use(cors({
  origin: process.env.CLIENT_URL || '*',
  credentials: true,
}));
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
  configureCloudinary();
  initSocket(server);
  startRentReminderJobs();

  const port = Number(process.env.PORT || 5000);
  server.listen(port, () => {
    console.log(`RentFlow backend running on port ${port}`);
  });
}

start().catch((error) => {
  console.error('Failed to start RentFlow backend:', error);
  process.exit(1);
});

module.exports = {
  app,
  server,
};
