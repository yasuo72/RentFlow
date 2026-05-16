const User = require('../models/User');
const { sendError, sendSuccess } = require('../utils/response');

async function listUsers(req, res) {
  const users = await User.find().select('-password').sort({ role: 1, name: 1 });

  return sendSuccess(res, {
    data: users,
  });
}

async function createUser(req, res) {
  const { name, phone, email, password } = req.body;

  if (req.body.role !== undefined) {
    return sendError(res, {
      statusCode: 403,
      message: 'Role assignment is disabled. New users are created as family members only.',
    });
  }

  const existingUser = await User.findOne({ phone });

  if (existingUser) {
    return sendError(res, {
      statusCode: 409,
      message: 'A user with this phone number already exists.',
    });
  }

  const user = await User.create({
    name,
    phone,
    email,
    password,
    role: 'family_member',
  });

  await req.logActivity({
    action: 'USER_CREATED',
    details: `Created family member ${user.name}.`,
    entityType: 'user',
    entityId: user._id,
  });

  return sendSuccess(res, {
    statusCode: 201,
    message: 'Family member created successfully.',
    data: user.toSafeObject(),
  });
}

async function updateUser(req, res) {
  const user = await User.findById(req.params.id);

  if (!user) {
    return sendError(res, {
      statusCode: 404,
      message: 'User not found.',
    });
  }

  if (req.body.role !== undefined) {
    return sendError(res, {
      statusCode: 403,
      message: 'Role assignment is disabled for all users.',
    });
  }

  if (req.body.isActive !== undefined && req.user.role !== 'super_admin') {
    return sendError(res, {
      statusCode: 403,
      message: 'Only the super admin can change account access status.',
    });
  }

  if (
    req.body.isActive === false &&
    String(user._id) === String(req.user._id)
  ) {
    return sendError(res, {
      statusCode: 400,
      message: 'You cannot deactivate your own account.',
    });
  }

  if (req.body.isActive === false && user.role === 'super_admin') {
    return sendError(res, {
      statusCode: 400,
      message: 'The super admin account cannot be deactivated.',
    });
  }

  const fields = ['name', 'phone', 'email', 'profilePhoto', 'isActive'];
  fields.forEach((field) => {
    if (req.body[field] !== undefined) {
      user[field] = req.body[field];
    }
  });

  if (req.body.password) {
    user.password = req.body.password;
  }

  await user.save();

  await req.logActivity({
    action: 'USER_UPDATED',
    details: `Updated user ${user.name}.`,
    entityType: 'user',
    entityId: user._id,
  });

  return sendSuccess(res, {
    message: 'User updated successfully.',
    data: user.toSafeObject(),
  });
}

async function deleteUser(req, res) {
  const user = await User.findById(req.params.id);

  if (!user) {
    return sendError(res, {
      statusCode: 404,
      message: 'User not found.',
    });
  }

  if (String(user._id) === String(req.user._id)) {
    return sendError(res, {
      statusCode: 400,
      message: 'You cannot deactivate your own account.',
    });
  }

  if (user.role === 'super_admin') {
    return sendError(res, {
      statusCode: 400,
      message: 'The super admin account cannot be removed.',
    });
  }

  user.isActive = false;
  await user.save();

  await req.logActivity({
    action: 'USER_DEACTIVATED',
    details: `Deactivated user ${user.name}.`,
    entityType: 'user',
    entityId: user._id,
  });

  return sendSuccess(res, {
    message: 'User deactivated successfully.',
  });
}

module.exports = {
  listUsers,
  createUser,
  updateUser,
  deleteUser,
};
