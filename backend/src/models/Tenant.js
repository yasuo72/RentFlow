const mongoose = require('mongoose');

const documentSchema = new mongoose.Schema({
  type: {
    type: String,
    trim: true,
  },
  url: {
    type: String,
    trim: true,
  },
  name: {
    type: String,
    trim: true,
  },
  uploadedAt: {
    type: Date,
    default: Date.now,
  },
}, { _id: false });

const emergencyContactSchema = new mongoose.Schema({
  name: {
    type: String,
    trim: true,
  },
  phone: {
    type: String,
    trim: true,
  },
  relation: {
    type: String,
    trim: true,
  },
}, { _id: false });

const tenantSchema = new mongoose.Schema({
  fullName: {
    type: String,
    required: true,
    trim: true,
    index: true,
  },
  phone: {
    type: String,
    required: true,
    trim: true,
    index: true,
  },
  alternatePhone: {
    type: String,
    trim: true,
  },
  idNumber: {
    type: String,
    trim: true,
  },
  occupation: {
    type: String,
    trim: true,
  },
  familyMembers: {
    type: Number,
    default: 1,
    min: 1,
  },
  permanentAddress: {
    type: String,
    trim: true,
  },
  profilePhoto: {
    type: String,
  },
  joiningDate: {
    type: Date,
    required: true,
  },
  leavingDate: {
    type: Date,
  },
  room: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Room',
    required: true,
    index: true,
  },
  isActive: {
    type: Boolean,
    default: true,
    index: true,
  },
  documents: [documentSchema],
  emergencyContact: emergencyContactSchema,
  notes: {
    type: String,
    trim: true,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

module.exports = mongoose.model('Tenant', tenantSchema);
