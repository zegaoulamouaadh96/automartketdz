const express = require('express');
const router = express.Router();
const { createOrder, getOrders, getOrder, getStoreOrders, updateOrderStatus } = require('../controllers/orderController');
const { auth, authorize } = require('../middleware/auth');
const { validate, orderValidation } = require('../middleware/validation');

router.post('/', auth, orderValidation, validate, createOrder);
router.get('/', auth, getOrders);
router.get('/store-orders', auth, authorize('seller', 'admin'), getStoreOrders);
router.get('/:id', auth, getOrder);
router.put('/:id/status', auth, updateOrderStatus);
router.patch('/:id/status', auth, updateOrderStatus);

module.exports = router;
