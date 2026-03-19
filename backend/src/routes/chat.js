const express = require('express');
const router = express.Router();
const {
	getConversations,
	getMessages,
	sendMessage,
	startConversation,
	uploadChatImage,
	uploadChatMedia,
} = require('../controllers/chatController');
const { auth } = require('../middleware/auth');
const upload = require('../middleware/upload');

router.get('/conversations', auth, getConversations);
router.get('/conversations/:conversationId/messages', auth, getMessages);
router.post('/messages', auth, sendMessage);
router.post('/conversations', auth, startConversation);
router.post('/upload-image', auth, upload.single('image'), uploadChatImage);
router.post('/upload-media', auth, upload.chatMediaUpload.single('media'), uploadChatMedia);

module.exports = router;
