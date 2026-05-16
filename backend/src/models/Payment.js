const mongoose = require('mongoose');

const paymentSchema = new mongoose.Schema({
  tenant: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Tenant',
    required: true,
    index: true,
  },
  room: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Room',
    required: true,
    index: true,
  },
  month: {
    type: String,
    required: true,
    trim: true,
    index: true,
  },
  year: {
    type: Number,
    required: true,
    index: true,
  },
  monthlyRentDue: {
    type: Number,
    required: true,
    min: 0,
  },
  carriedForwardAmount: {
    type: Number,
    default: 0,
    min: 0,
  },
  amountPaid: {
    type: Number,
    required: true,
    min: 0,
  },
  remainingAmount: {
    type: Number,
    required: true,
    min: 0,
  },
  paymentMethod: {
    type: String,
    enum: ['cash', 'upi', 'bank_transfer', 'card', 'other'],
    default: 'cash',
  },
  paymentDate: {
    type: Date,
    default: Date.now,
    index: true,
  },
  remark: {
    type: String,
    trim: true,
  },
  receiptNumber: {
    type: String,
    unique: true,
    required: true,
  },
  isPartialPayment: {
    type: Boolean,
    default: false,
    index: true,
  },
  recordedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  entries: [
    {
      amountPaid: {
        type: Number,
        required: true,
        min: 0,
      },
      paymentMethod: {
        type: String,
        enum: ['cash', 'upi', 'bank_transfer', 'card', 'other'],
        default: 'cash',
      },
      paymentDate: {
        type: Date,
        default: Date.now,
      },
      remark: {
        type: String,
        trim: true,
      },
      recordedBy: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
      },
      createdAt: {
        type: Date,
        default: Date.now,
      },
    },
  ],
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

paymentSchema.index({ room: 1, month: 1, year: 1 }, { unique: true });

module.exports = mongoose.model('Payment', paymentSchema);
