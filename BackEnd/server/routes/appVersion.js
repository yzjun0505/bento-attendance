/**
 * App 版本与更新配置
 */
const express = require('express');
const router = express.Router();
const { successResponse } = require('../utils/helpers');

function toInt(value, fallback = 0) {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function boolFromEnv(value, fallback = false) {
  if (value === undefined) return fallback;
  return ['1', 'true', 'yes', 'on'].includes(String(value).toLowerCase());
}

function getPlatformConfig(platform) {
  const normalized = String(platform || 'android').toLowerCase();
  const prefix = normalized === 'ios' ? 'IOS' : 'ANDROID';

  return {
    platform: normalized === 'ios' ? 'ios' : 'android',
    latestVersionName: process.env[`APP_${prefix}_VERSION_NAME`] || '1.0.0',
    latestVersionCode: toInt(process.env[`APP_${prefix}_VERSION_CODE`], 1),
    minSupportedVersionCode: toInt(
      process.env[`APP_${prefix}_MIN_VERSION_CODE`],
      1,
    ),
    forceUpdate: boolFromEnv(process.env[`APP_${prefix}_FORCE_UPDATE`]),
    downloadUrl: process.env[`APP_${prefix}_DOWNLOAD_URL`] || '',
    releaseNotes: process.env[`APP_${prefix}_RELEASE_NOTES`] || '',
  };
}

router.get('/version', (req, res) => {
  const config = getPlatformConfig(req.query.platform);
  const currentVersionCode = toInt(req.query.versionCode, 0);
  const hasUpdate = currentVersionCode > 0
    ? config.latestVersionCode > currentVersionCode
    : false;
  const mustUpdate = currentVersionCode > 0
    ? config.forceUpdate || currentVersionCode < config.minSupportedVersionCode
    : config.forceUpdate;

  res.json(successResponse({
    ...config,
    hasUpdate,
    forceUpdate: mustUpdate,
  }));
});

module.exports = router;
