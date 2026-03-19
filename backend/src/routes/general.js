const express = require('express');
const router = express.Router();
const {
  getCategories, createCategory,
  getVehicleBrands, getVehicleModels, getVehicleYears,
  createReport, getWilayas, getPublicAnnouncements,
  getUserNotifications, markNotificationRead, getAppSettings,
  searchPublicUsers, getPublicUserProfile,
  followUser, unfollowUser,
} = require('../controllers/generalController');
const { auth, authorize, optionalAuth } = require('../middleware/auth');

// Public routes
router.get('/categories', getCategories);
router.get('/brands', getVehicleBrands);
router.get('/vehicle-brands', getVehicleBrands);
router.get('/vehicle-brands/:brand_id/models', getVehicleModels);
router.get('/vehicle-models/:model_id/years', getVehicleYears);
router.get('/wilayas', getWilayas);
router.get('/announcements', getPublicAnnouncements);
router.get('/app-settings', getAppSettings);
router.get('/users/search', optionalAuth, searchPublicUsers);
router.get('/users/:id/public-profile', optionalAuth, getPublicUserProfile);

// User notifications (authenticated)
router.get('/notifications', auth, getUserNotifications);
router.put('/notifications/:id/read', auth, markNotificationRead);
router.post('/users/:id/follow', auth, followUser);
router.delete('/users/:id/follow', auth, unfollowUser);

// Protected routes
router.post('/categories', auth, authorize('admin', 'founder'), createCategory);
router.post('/reports', auth, createReport);

module.exports = router;
