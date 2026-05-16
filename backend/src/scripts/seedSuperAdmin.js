require('dotenv').config();

const { connectDB } = require('../config/db');
const User = require('../models/User');

async function seed() {
  await connectDB();

  const existingAdmin = await User.findOne({ role: 'super_admin' });

  if (existingAdmin) {
    console.log('Super admin already exists.');
    process.exit(0);
  }

  const user = await User.create({
    name: process.env.SUPER_ADMIN_NAME || 'Owner',
    phone: process.env.SUPER_ADMIN_PHONE || '9999999999',
    email: process.env.SUPER_ADMIN_EMAIL || undefined,
    password: process.env.SUPER_ADMIN_PASSWORD || 'change_me',
    role: 'super_admin',
  });

  console.log(`Super admin created for ${user.phone}`);
  process.exit(0);
}

seed().catch((error) => {
  console.error('Failed to seed super admin:', error);
  process.exit(1);
});
