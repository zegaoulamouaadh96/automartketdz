const demoUsers = [
  {
    id: '00000000-0000-0000-0000-000000000001',
    email: 'admin@automarket.dz',
    password: 'admin123',
    first_name: 'Admin',
    last_name: 'AutoMarket',
    phone: '0555000000',
    role: 'admin',
    wilaya: 'Alger',
    avatar: null,
    is_active: true,
  },
  {
    id: '00000000-0000-0000-0000-000000000002',
    email: 'seller@automarket.dz',
    password: 'seller123',
    first_name: 'Ahmed',
    last_name: 'Bensalem',
    phone: '0555111111',
    role: 'seller',
    wilaya: 'Alger',
    avatar: null,
    is_active: true,
  },
  {
    id: '00000000-0000-0000-0000-000000000003',
    email: 'buyer@automarket.dz',
    password: 'buyer123',
    first_name: 'Mohamed',
    last_name: 'Khelifi',
    phone: '0555222222',
    role: 'buyer',
    wilaya: 'Oran',
    avatar: null,
    is_active: true,
  },
  {
    id: '00000000-0000-0000-0000-000000000004',
    email: 'supplier@automarket.dz',
    password: 'supplier123',
    first_name: 'Karim',
    last_name: 'Hadji',
    phone: '0555333333',
    role: 'supplier',
    wilaya: 'Blida',
    avatar: null,
    is_active: true,
  },
];

const sanitizeDemoUser = (user) => {
  if (!user) return null;
  const { password, ...safeUser } = user;
  return { ...safeUser, demo_mode: true };
};

const findDemoUserByCredentials = (email, password) => {
  const user = demoUsers.find((candidate) => candidate.email === email && candidate.password === password);
  return sanitizeDemoUser(user);
};

const findDemoUserById = (id) => {
  const user = demoUsers.find((candidate) => candidate.id === id);
  return sanitizeDemoUser(user);
};

module.exports = {
  demoUsers,
  findDemoUserByCredentials,
  findDemoUserById,
};
