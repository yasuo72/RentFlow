const ActivityLog = require('../models/ActivityLog');
const Expense = require('../models/Expense');
const { uploadBuffer } = require('../config/cloudinary');
const { emitEvent } = require('../services/socket.service');
const { sendError, sendSuccess } = require('../utils/response');

async function listExpenses(req, res) {
  const filters = {};

  if (req.query.category) {
    filters.category = req.query.category;
  }
  if (req.query.room) {
    filters.room = req.query.room;
  }
  if (req.query.dateFrom || req.query.dateTo) {
    filters.date = {};
    if (req.query.dateFrom) {
      filters.date.$gte = new Date(req.query.dateFrom);
    }
    if (req.query.dateTo) {
      filters.date.$lte = new Date(req.query.dateTo);
    }
  }

  const expenses = await Expense.find(filters)
    .populate('room', 'roomNumber')
    .populate('recordedBy', 'name')
    .sort({ date: -1 });

  return sendSuccess(res, {
    data: expenses,
  });
}

async function createExpense(req, res) {
  let billPhoto;

  if (req.file) {
    const upload = await uploadBuffer(req.file.buffer, 'rentflow/expenses', 'image');
    billPhoto = upload.secure_url;
  }

  const expense = await Expense.create({
    ...req.body,
    billPhoto,
    recordedBy: req.user._id,
  });

  await req.logActivity({
    action: 'EXPENSE_ADDED',
    details: `Added ${expense.category} expense of ₹${expense.amount}.`,
    entityType: 'expense',
    entityId: expense._id,
  });

  const populatedExpense = await Expense.findById(expense._id)
    .populate('room', 'roomNumber')
    .populate('recordedBy', 'name');

  emitEvent('expense:added', { expense: populatedExpense });

  return sendSuccess(res, {
    statusCode: 201,
    message: 'Expense added successfully.',
    data: populatedExpense,
  });
}

async function updateExpense(req, res) {
  const expense = await Expense.findById(req.params.id);

  if (!expense) {
    return sendError(res, {
      statusCode: 404,
      message: 'Expense not found.',
    });
  }

  if (req.file) {
    const upload = await uploadBuffer(req.file.buffer, 'rentflow/expenses', 'image');
    req.body.billPhoto = upload.secure_url;
  }

  Object.assign(expense, req.body);
  await expense.save();

  await req.logActivity({
    action: 'EXPENSE_UPDATED',
    details: `Updated expense ${expense._id}.`,
    entityType: 'expense',
    entityId: expense._id,
  });

  return sendSuccess(res, {
    message: 'Expense updated successfully.',
    data: expense,
  });
}

async function deleteExpense(req, res) {
  const expense = await Expense.findById(req.params.id);

  if (!expense) {
    return sendError(res, {
      statusCode: 404,
      message: 'Expense not found.',
    });
  }

  await ActivityLog.deleteMany({
    entityType: 'expense',
    entityId: expense._id,
  });

  await expense.deleteOne();

  emitEvent('expense:added', {
    expense: {
      _id: expense._id,
      deleted: true,
    },
  });

  return sendSuccess(res, {
    message: 'Expense deleted successfully.',
  });
}

async function getExpenseSummary(req, res) {
  const matchStage = {};

  if (req.query.month) {
    const date = new Date(req.query.month);
    const monthStart = new Date(date.getFullYear(), date.getMonth(), 1);
    const monthEnd = new Date(date.getFullYear(), date.getMonth() + 1, 1);
    matchStage.date = { $gte: monthStart, $lt: monthEnd };
  }

  const summary = await Expense.aggregate([
    { $match: matchStage },
    {
      $group: {
        _id: '$category',
        totalAmount: { $sum: '$amount' },
        count: { $sum: 1 },
      },
    },
    { $sort: { totalAmount: -1 } },
  ]);

  return sendSuccess(res, {
    data: summary,
  });
}

module.exports = {
  listExpenses,
  createExpense,
  updateExpense,
  deleteExpense,
  getExpenseSummary,
};
