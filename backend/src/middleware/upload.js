const multer = require('multer');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const config = require('../config');

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, config.upload.dir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `${uuidv4()}${ext}`);
  },
});

const fileFilter = (req, file, cb) => {
  const allowedMimeTypes = [
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/x-png',
    'image/pjpeg',
    'image/webp',
    'image/heic',
    'image/heif',
    'image/heic-sequence',
    'image/heif-sequence',
  ];

  const allowedExtensions = ['.jpg', '.jpeg', '.jfif', '.png', '.webp', '.heic', '.heif', '.heics', '.heifs'];

  const mimeType = (file.mimetype || '').toLowerCase();
  const extension = path.extname(file.originalname || '').toLowerCase();

  const isAllowedMime = allowedMimeTypes.includes(mimeType);
  const isAllowedExtension = allowedExtensions.includes(extension);
  const isGenericBinaryMime = mimeType === '' || mimeType === 'application/octet-stream' || mimeType === 'binary/octet-stream';

  // Some mobile providers send HEIC/JPEG files as octet-stream, so allow known extensions in that case.
  if (isAllowedMime || (mimeType.startsWith('image/') && isAllowedExtension) || (isGenericBinaryMime && isAllowedExtension)) {
    cb(null, true);
  } else {
    const err = new Error('Only JPEG, PNG, WebP, HEIC, and HEIF images are allowed');
    err.status = 400;
    cb(err, false);
  }
};

const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: config.upload.maxFileSize,
  },
});

const chatMediaFileFilter = (req, file, cb) => {
  const imageMimeTypes = [
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/x-png',
    'image/pjpeg',
    'image/webp',
    'image/heic',
    'image/heif',
    'image/heic-sequence',
    'image/heif-sequence',
  ];

  const audioMimeTypes = [
    'audio/mpeg',
    'audio/mp3',
    'audio/aac',
    'audio/x-aac',
    'audio/wav',
    'audio/x-wav',
    'audio/wave',
    'audio/ogg',
    'audio/webm',
    'audio/mp4',
    'audio/x-m4a',
    'audio/3gpp',
    'audio/amr',
  ];

  const imageExtensions = ['.jpg', '.jpeg', '.jfif', '.png', '.webp', '.heic', '.heif', '.heics', '.heifs'];
  const audioExtensions = ['.m4a', '.mp3', '.aac', '.wav', '.ogg', '.webm', '.amr', '.3gp'];

  const mimeType = (file.mimetype || '').toLowerCase();
  const extension = path.extname(file.originalname || '').toLowerCase();
  const isGenericBinaryMime = mimeType === '' || mimeType === 'application/octet-stream' || mimeType === 'binary/octet-stream';

  const isImage =
    imageMimeTypes.includes(mimeType) ||
    (mimeType.startsWith('image/') && imageExtensions.includes(extension)) ||
    (isGenericBinaryMime && imageExtensions.includes(extension));

  const isAudio =
    audioMimeTypes.includes(mimeType) ||
    (mimeType.startsWith('audio/') && audioExtensions.includes(extension)) ||
    (isGenericBinaryMime && audioExtensions.includes(extension));

  if (isImage || isAudio) {
    cb(null, true);
  } else {
    const err = new Error('Only image and audio files are allowed for chat media');
    err.status = 400;
    cb(err, false);
  }
};

const chatMediaUpload = multer({
  storage,
  fileFilter: chatMediaFileFilter,
  limits: {
    fileSize: Math.max(config.upload.maxFileSize, 10 * 1024 * 1024),
  },
});

module.exports = upload;
module.exports.chatMediaUpload = chatMediaUpload;
