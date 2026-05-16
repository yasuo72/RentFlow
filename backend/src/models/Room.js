const mongoose = require('mongoose');

const roomSchema = new mongoose.Schema({
  roomNumber: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    index: true,
  },
  floor: {
    type: String,
    trim: true,
  },
  building: {
    type: String,
    default: 'Main',
    trim: true,
  },
  monthlyRent: {
    type: Number,
    required: true,
    min: 0,
  },
  depositAmount: {
    type: Number,
    default: 0,
    min: 0,
  },
  status: {
    type: String,
    enum: ['occupied', 'vacant'],
    default: 'vacant',
    index: true,
  },
  currentTenant: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Tenant',
  },
  electricityMeterNumber: {
    type: String,
    trim: true,
  },
  notes: {
    type: String,
    trim: true,
  },
  photos: [
    {
      type: String,
    },
  ],
  createdAt: {
    type: Date,
    default: Date.now,
  },
  updatedAt: {
    type: Date,
    default: Date.now,
  },
});

roomSchema.pre('save', function onSave() {
  this.updatedAt = new Date();
});

module.exports = mongoose.model('Room', roomSchema);
