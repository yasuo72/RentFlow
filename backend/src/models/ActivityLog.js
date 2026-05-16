const mongoose = require('mongoose');

const activityLogSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    index: true,
  },
  userName: {
    type: String,
    trim: true,
  },
  action: {
    type: String,
    required: true,
    trim: true,
    index: true,
  },
  details: {
    type: String,
    trim: true,
  },
  entityType: {
    type: String,
    trim: true,
    index: true,
  },
  entityId: {
    type: mongoose.Schema.Types.ObjectId,
    index: true,
  },
  createdAt: {
    type: Date,
    default: Date.now,
    index: true,
  },
});

module.exports = mongoose.model('ActivityLog', activityLogSchema);
