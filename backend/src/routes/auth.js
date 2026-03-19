const express = require('express');
const router = express.Router();
const { register, login, getProfile, updateProfile, updateAvatar, changePassword } = require('../controllers/authController');
const { auth } = require('../middleware/auth');
const { validate, registerValidation, loginValidation } = require('../middleware/validation');
const upload = require('../middleware/upload');

router.post('/register', registerValidation, validate, register);
router.post('/login', loginValidation, validate, login);
router.get('/profile', auth, getProfile);
router.put('/profile', auth, updateProfile);
router.put('/profile/avatar', auth, upload.single('avatar'), updateAvatar);
router.put('/change-password', auth, changePassword);

module.exports = router;
