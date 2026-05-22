/**
 * 文件上传路由
 */
const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { authMiddleware } = require('../middleware/auth');
const { successResponse, errorResponse } = require('../utils/helpers');

const uploadDir = path.join(__dirname, '../uploads/photos');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '.jpg';
    const filename = `checkin_${Date.now()}_${Math.random().toString(36).substr(2, 9)}${ext}`;
    cb(null, filename);
  }
});

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 10 * 1024 * 1024
  },
  fileFilter: (req, file, cb) => {
    const allowedTypes = ['image/jpeg', 'image/png', 'image/jpg', 'image/gif'];
    if (allowedTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('不支持的文件类型'));
    }
  }
});

function getPublicBaseUrl(req) {
  const configured = process.env.PUBLIC_BASE_URL || process.env.APP_PUBLIC_URL || '';
  if (configured) return configured.replace(/\/+$/, '');
  return `${req.protocol}://${req.get('host')}`;
}

router.use(authMiddleware);

router.post('/photo', upload.single('photo'), (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json(errorResponse('未收到照片文件', 400));
    }

    const filePath = `/uploads/photos/${req.file.filename}`;
    const fileUrl = `${getPublicBaseUrl(req)}${filePath}`;
    
    res.json(successResponse({
      url: fileUrl,
      path: filePath,
      filename: req.file.filename,
      size: req.file.size
    }, '照片上传成功'));
  } catch (err) {
    console.error('上传照片失败:', err);
    res.status(500).json(errorResponse('上传失败'));
  }
});

router.use((err, req, res, next) => {
  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json(errorResponse('文件大小不能超过10MB', 400));
    }
    return res.status(400).json(errorResponse(err.message, 400));
  }
  res.status(500).json(errorResponse(err.message || '上传失败'));
});

module.exports = router;
