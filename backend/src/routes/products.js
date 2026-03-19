const express = require('express');
const router = express.Router();
const { createProduct, getProduct, updateProduct, deleteProduct, listProducts, searchProducts, getMyProducts } = require('../controllers/productController');
const { auth, authorize, optionalAuth } = require('../middleware/auth');
const { validate, productValidation } = require('../middleware/validation');
const upload = require('../middleware/upload');

router.get('/', optionalAuth, listProducts);
router.get('/search', searchProducts);
router.get('/my-products', auth, authorize('seller', 'admin'), getMyProducts);
router.post('/', auth, authorize('seller', 'admin'), upload.array('images', 10), createProduct);
router.get('/:id', optionalAuth, getProduct);
router.put('/:id', auth, authorize('seller', 'admin'), upload.array('images', 10), updateProduct);
router.delete('/:id', auth, authorize('seller', 'admin'), deleteProduct);

module.exports = router;
