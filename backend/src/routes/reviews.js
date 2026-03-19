const express = require('express');
const router = express.Router();
const { addProductReview, getProductReviews, addStoreReview, getStoreReviews } = require('../controllers/reviewController');
const { auth } = require('../middleware/auth');
const { validate, reviewValidation } = require('../middleware/validation');

router.post('/products/:id', auth, reviewValidation, validate, addProductReview);
router.get('/products/:id', getProductReviews);
router.post('/stores/:id', auth, reviewValidation, validate, addStoreReview);
router.get('/stores/:id', getStoreReviews);

module.exports = router;
