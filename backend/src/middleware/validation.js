const { validationResult, body, param, query } = require('express-validator');

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }
  next();
};

const registerValidation = [
  body('email').isEmail().normalizeEmail().withMessage('Valid email is required'),
  body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
  body('first_name').trim().notEmpty().withMessage('First name is required'),
  body('last_name').trim().notEmpty().withMessage('Last name is required'),
  body('phone').optional().isMobilePhone().withMessage('Valid phone number is required'),
  body('role').optional().isIn(['buyer', 'seller', 'supplier']).withMessage('Invalid role'),
];

const loginValidation = [
  body('email').isEmail().normalizeEmail().withMessage('Valid email is required'),
  body('password').notEmpty().withMessage('Password is required'),
];

const productValidation = [
  body('name').trim().notEmpty().withMessage('Product name is required'),
  body('price').isFloat({ min: 0 }).withMessage('Valid price is required'),
  body('category_id').optional().isUUID().withMessage('Valid category ID is required'),
  body('description').optional().trim(),
  body('quantity').optional().isInt({ min: 0 }).withMessage('Quantity must be a positive number'),
  body('condition').optional().isIn(['new', 'used', 'refurbished']).withMessage('Invalid condition'),
];

const orderValidation = [
  body('items').isArray({ min: 1 }).withMessage('Order must have at least one item'),
  body('items.*.product_id').isUUID().withMessage('Valid product ID is required'),
  body('items.*.quantity').isInt({ min: 1 }).withMessage('Quantity must be at least 1'),
  body('shipping_wilaya').trim().notEmpty().withMessage('Shipping wilaya is required'),
  body('shipping_address').trim().notEmpty().withMessage('Shipping address is required'),
  body('shipping_phone').trim().notEmpty().withMessage('Shipping phone is required'),
  body('shipping_name').trim().notEmpty().withMessage('Shipping name is required'),
];

const reviewValidation = [
  body('rating').isInt({ min: 1, max: 5 }).withMessage('Rating must be between 1 and 5'),
  body('comment').optional().trim(),
];

const storeValidation = [
  body('name').trim().notEmpty().withMessage('Store name is required'),
  body('description').optional().trim(),
  body('address').trim().notEmpty().withMessage('Address is required'),
  body('wilaya').trim().notEmpty().withMessage('Wilaya is required'),
  body('phone').trim().notEmpty().withMessage('Phone is required'),
  body('activity_type').optional().isIn(['car_parts', 'truck_parts', 'motorcycle_parts', 'all_parts']).withMessage('Invalid activity type'),
];

const uuidParam = [
  param('id').isUUID().withMessage('Valid ID is required'),
];

const searchValidation = [
  query('q').optional().trim(),
  query('page').optional().isInt({ min: 1 }).withMessage('Page must be a positive number'),
  query('limit').optional().isInt({ min: 1, max: 100 }).withMessage('Limit must be between 1 and 100'),
];

module.exports = {
  validate,
  registerValidation,
  loginValidation,
  productValidation,
  orderValidation,
  reviewValidation,
  storeValidation,
  uuidParam,
  searchValidation,
};
