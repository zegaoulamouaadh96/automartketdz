const express = require('express');
const router = express.Router();
const { createStore, getStore, updateStore, getMyStore, listStores, getStoreStats } = require('../controllers/storeController');
const { auth } = require('../middleware/auth');
const { validate, storeValidation } = require('../middleware/validation');
const upload = require('../middleware/upload');

router.get('/', listStores);
router.get('/my-store', auth, getMyStore);
router.get('/my-store/stats', auth, getStoreStats);
router.post('/', auth, upload.single('logo'), storeValidation, validate, createStore);
router.put('/my-store', auth, upload.fields([
  { name: 'logo', maxCount: 1 },
  { name: 'banner', maxCount: 1 },
]), updateStore);
router.get('/:id', getStore);

module.exports = router;
