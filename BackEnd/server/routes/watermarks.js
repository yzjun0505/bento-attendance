/**
 * 水印模板动态拉取路由
 */
const express = require('express');
const router = express.Router();
const { getPool } = require('../models/db');
const { authMiddleware } = require('../middleware/auth');
const { successResponse, errorResponse } = require('../utils/helpers');

const watermarkBindingOptions = [
  { value: 'userName', label: '打卡人', category: '基础信息', slotTypes: ['文本'], example: '张三' },
  { value: 'projectName', label: '项目名称', category: '基础信息', slotTypes: ['文本'], example: '示例项目' },
  { value: 'position', label: '岗位/工种', category: '基础信息', slotTypes: ['文本'], example: '施工员' },
  { value: 'checkinTime', label: '完整时间', category: '时间信息', slotTypes: ['时间', '文本'], example: '2026-04-23 12:00:00' },
  { value: 'timeDate', label: '日期', category: '时间信息', slotTypes: ['时间', '文本'], example: '2026-04-23 星期四' },
  { value: 'timeOnly', label: '时分秒', category: '时间信息', slotTypes: ['时间', '文本'], example: '12:00:00' },
  { value: 'location', label: '详细地址', category: '位置信息', slotTypes: ['地理位置', '文本'], example: 'xx省xx市xx区' },
  { value: 'gps', label: '经纬度', category: '位置信息', slotTypes: ['地理位置', '文本'], example: '116.397, 39.908' },
  { value: 'gpsLat', label: '纬度', category: '位置信息', slotTypes: ['地理位置', '文本'], example: '纬度: 39.908000' },
  { value: 'gpsLng', label: '经度', category: '位置信息', slotTypes: ['地理位置', '文本'], example: '经度: 116.397000' },
  { value: 'altitude', label: '海拔', category: '位置信息', slotTypes: ['地理位置', '文本'], example: '120m' },
  { value: 'weather', label: '天气', category: '环境信息', slotTypes: ['文本'], example: '晴' },
  { value: 'temperature', label: '温度', category: '环境信息', slotTypes: ['文本'], example: '25℃' },
  { value: 'humidity', label: '湿度', category: '环境信息', slotTypes: ['文本'], example: '60%' },
  { value: 'device', label: '设备型号', category: '设备信息', slotTypes: ['文本'], example: 'iPhone 15 Pro' },
  { value: 'deviceNo', label: '设备编号', category: '设备信息', slotTypes: ['文本'], example: 'DEV-001' },
  { value: 'remark', label: '备注', category: '补充信息', slotTypes: ['文本'], example: '现场正常' },
  { value: 'antiFakeCode', label: '防伪码', category: '补充信息', slotTypes: ['文本'], example: 'WM20260423001' }
];

function parseSchema(schemaJson) {
  if (!schemaJson) {
    return {};
  }

  if (typeof schemaJson === 'object') {
    return schemaJson;
  }

  try {
    return JSON.parse(schemaJson);
  } catch (err) {
    console.warn('解析水印模板 schema 失败:', err.message);
    return {};
  }
}

function formatTemplate(row) {
  const schema = parseSchema(row.schema_json);
  return {
    ...row,
    status: Number(row.status ?? 1),
    schema,
    schema_json: schema,
  };
}

router.get('/binding-options', authMiddleware, async (req, res) => {
  res.json(successResponse(watermarkBindingOptions));
});

// 获取所有启用的水印模板
router.get('/templates', authMiddleware, async (req, res) => {
  try {
    const db = getPool();
    const [rows] = await db.execute(
      'SELECT id, name, title, schema_json FROM watermark_templates WHERE status = 1 ORDER BY id ASC'
    );

    const templates = rows.map(formatTemplate);

    res.json(successResponse(templates));
  } catch (err) {
    console.error('获取水印模板失败:', err);
    res.status(500).json(errorResponse('获取水印模板失败'));
  }
});

// 管理员获取所有模板(包含停用的) - 供后台表格展示
router.get('/all', authMiddleware, async (req, res) => {
  try {
    const db = getPool();
    const [rows] = await db.execute('SELECT id, name, title, schema_json, status, created_at, updated_at FROM watermark_templates ORDER BY id DESC');
    const templates = rows.map(formatTemplate);
    res.json(successResponse(templates));
  } catch (err) {
    res.status(500).json(errorResponse('获取失败'));
  }
});

// 增加新水印模板
router.post('/', authMiddleware, async (req, res) => {
  try {
    const { name, title, schema, schema_json, status } = req.body;
    const finalSchema = schema ?? schema_json ?? {};
    const db = getPool();
    await db.execute(
      'INSERT INTO watermark_templates (name, title, schema_json, status) VALUES (?, ?, ?, ?)',
      [name, title || null, JSON.stringify(finalSchema), Number(status ?? 1) === 0 ? 0 : 1]
    );
    res.json(successResponse({}, '保存成功'));
  } catch (err) {
    res.status(500).json(errorResponse('保存失败'));
  }
});

// 更新水印模板
router.put('/:id', authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const { name, title, schema, schema_json, status } = req.body;
    const finalSchema = schema ?? schema_json ?? {};
    const db = getPool();
    await db.execute(
      'UPDATE watermark_templates SET name = ?, title = ?, schema_json = ?, status = ? WHERE id = ?',
      [name, title || null, JSON.stringify(finalSchema), Number(status ?? 1) === 0 ? 0 : 1, id]
    );
    res.json(successResponse({}, '更新成功'));
  } catch (err) {
    res.status(500).json(errorResponse('更新失败'));
  }
});

// 删除水印模板
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const db = getPool();
    await db.execute('DELETE FROM watermark_templates WHERE id = ?', [id]);
    res.json(successResponse({}, '删除成功'));
  } catch (err) {
    res.status(500).json(errorResponse('删除失败'));
  }
});

module.exports = router;
