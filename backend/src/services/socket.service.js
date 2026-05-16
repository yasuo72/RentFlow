const jwt = require('jsonwebtoken');
const { Server } = require('socket.io');

const User = require('../models/User');

let io;

function initSocket(server, options = {}) {
  io = new Server(server, {
    cors: {
      origin: options.origin || process.env.CLIENT_URL || '*',
      credentials: true,
    },
  });

  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth?.token;

      if (!token) {
        return next(new Error('Authentication token is required.'));
      }

      const payload = jwt.verify(token, process.env.JWT_SECRET);
      const user = await User.findById(payload.userId);

      if (!user || !user.isActive) {
        return next(new Error('User is not active.'));
      }

      socket.user = user;
      return next();
    } catch (error) {
      return next(new Error('Unauthorized socket connection.'));
    }
  });

  io.on('connection', (socket) => {
    socket.join('rentflow-family');

    socket.on('disconnect', () => {
      socket.leave('rentflow-family');
    });
  });

  return io;
}

function getIO() {
  return io;
}

function emitEvent(event, payload) {
  if (!io) {
    return;
  }

  io.to('rentflow-family').emit(event, payload);
}

module.exports = {
  initSocket,
  getIO,
  emitEvent,
};
