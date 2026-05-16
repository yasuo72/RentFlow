const User = require('../models/User');

async function ensureSuperAdmin() {
  const existingAdmin = await User.findOne({ role: 'super_admin' });

  if (existingAdmin) {
    return existingAdmin;
  }

  const user = await User.create({
    name: process.env.SUPER_ADMIN_NAME || 'Owner',
    phone: process.env.SUPER_ADMIN_PHONE || '9999999999',
    email: process.env.SUPER_ADMIN_EMAIL || undefined,
    password: process.env.SUPER_ADMIN_PASSWORD || 'change_me',
    role: 'super_admin',
  });

  console.log(`Super admin created for ${user.phone}`);
  return user;
}

module.exports = {
  ensureSuperAdmin,
};
