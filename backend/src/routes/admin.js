const express = require('express');
const router = express.Router();
const {
  getAdminStats, getAdminUsers, updateUserStatus,
  getAdminProducts, getAdminStores, updateStoreStatus,
  getAdminOrders, getReports, updateReport,
  getCategories, getVehicleBrands,
} = require('../controllers/generalController');
const {
  getAdminUserById, deleteAdminProduct, getAdminStoreById,
  deleteAdminStore, getAdminOrderById, updateAdminOrderStatus,
  getAdminReportById, updateAdminCategory, deleteAdminCategory,
  createAdminBrand, deleteAdminBrand, getAdminSettings, updateAdminSettings,
  getAdminDashboardStats, getAdminActivity,
  getAdminAnnouncements, createAnnouncement, deleteAnnouncement,
  getNotifications, sendNotification, deleteNotification,
  getStaffMembers, createStaffMember, updateStaffMember, deleteStaffMember,
} = require('../controllers/adminController');
const { auth, authorize } = require('../middleware/auth');

// All admin routes require admin, founder, or employee role
router.use(auth, authorize('admin', 'founder', 'employee'));

// Dashboard
router.get('/stats', getAdminDashboardStats);
router.get('/activity', getAdminActivity);

// Users
router.get('/users', getAdminUsers);
router.get('/users/:id', getAdminUserById);
router.put('/users/:id', updateUserStatus);
router.put('/users/:id/status', updateUserStatus);

// Products
router.get('/products', getAdminProducts);
router.delete('/products/:id', deleteAdminProduct);

// Stores
router.get('/stores', getAdminStores);
router.get('/stores/:id', getAdminStoreById);
router.put('/stores/:id', updateStoreStatus);
router.put('/stores/:id/status', updateStoreStatus);
router.delete('/stores/:id', deleteAdminStore);

// Orders
router.get('/orders', getAdminOrders);
router.get('/orders/:id', getAdminOrderById);
router.put('/orders/:id/status', updateAdminOrderStatus);

// Reports
router.get('/reports', getReports);
router.get('/reports/:id', getAdminReportById);
router.put('/reports/:id', updateReport);

// Categories
router.post('/categories', (req, res, next) => {
  const { createCategory } = require('../controllers/generalController');
  return createCategory(req, res, next);
});
router.put('/categories/:id', updateAdminCategory);
router.delete('/categories/:id', deleteAdminCategory);

// Brands
router.post('/brands', createAdminBrand);
router.delete('/brands/:id', deleteAdminBrand);

// Settings
router.get('/settings', getAdminSettings);
router.put('/settings', updateAdminSettings);

// Announcements
router.get('/announcements', getAdminAnnouncements);
router.post('/announcements', createAnnouncement);
router.delete('/announcements/:id', deleteAnnouncement);

// Notifications
router.get('/notifications', getNotifications);
router.post('/notifications', sendNotification);
router.delete('/notifications/:id', deleteNotification);

// Staff management (founder only)
router.get('/staff', authorize('founder'), getStaffMembers);
router.post('/staff', authorize('founder'), createStaffMember);
router.put('/staff/:id', authorize('founder'), updateStaffMember);
router.delete('/staff/:id', authorize('founder'), deleteStaffMember);

module.exports = router;
