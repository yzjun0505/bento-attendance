/**
 * 打卡控制器
 */
const crypto = require('crypto');
const ExcelJS = require('exceljs');
const { getPool } = require('../models/db');
const { successResponse, errorResponse, parsePagination, getTodayRange } = require('../utils/helpers');
const checkinService = require('../services/checkinService');
const { getTypeName } = checkinService;

/**
 * 生成16位防伪码（大写字母+数字）
 */
function generateWatermarkCode() {
  return crypto.randomBytes(8).toString('hex').toUpperCase().slice(0, 16);
}

/**
 * 提交打卡
 * POST /api/checkin
 */
async function submitCheckin(req, res) {
  try {
    const db = getPool();
    const result = await checkinService.createCheckin(db, {
      userId: req.user.id,
      data: req.body,
      source: 'online',
    });

    const { message, ...data } = result;
    res.json(successResponse(data, message));
  } catch (err) {
    if (err.status) {
      return res.status(err.status).json(errorResponse(err.message, err.status));
    }
    console.error('打卡失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 查询打卡记录
 * GET /api/checkin
 */
async function getCheckins(req, res) {
  try {
    const db = getPool();
    const { page, pageSize, offset } = parsePagination(req.query);
    const { user_id, project_id, type, date_start, date_end, is_outside } = req.query;

    let where = 'WHERE 1=1';
    const params = [];

    if (user_id) {
      where += ' AND c.user_id = ?';
      params.push(parseInt(user_id));
    }
    if (project_id) {
      where += ' AND c.project_id = ?';
      params.push(parseInt(project_id));
    }
    if (type) {
      where += ' AND c.type = ?';
      params.push(type);
    }
    if (date_start) {
      where += ' AND c.created_at >= ?';
      params.push(date_start);
    }
    if (date_end) {
      where += ' AND c.created_at <= ?';
      params.push(date_end);
    }
    if (is_outside !== undefined && is_outside !== '') {
      where += ' AND c.is_outside = ?';
      params.push(parseInt(is_outside));
    }

    // 非管理员只能看自己的
    if (req.user.role === 'worker') {
      where += ' AND c.user_id = ?';
      params.push(req.user.id);
    }

    const [countRows] = await db.execute(
      `SELECT COUNT(*) as total FROM checkins c ${where}`,
      params
    );
    const total = countRows[0].total;

    const [rows] = await db.query(
      `SELECT c.*, c.watermark_code, u.name as user_name, u.username, p.name as project_name,
              ag.work_start_time, ag.work_end_time, ag.late_tolerance, ag.early_leave_tolerance
       FROM checkins c
       LEFT JOIN users u ON c.user_id = u.id
       LEFT JOIN projects p ON c.project_id = p.id
       LEFT JOIN attendance_group_members agm ON c.user_id = agm.user_id
       LEFT JOIN attendance_groups ag ON agm.group_id = ag.id
       ${where}
       ORDER BY c.created_at DESC LIMIT ${Number(pageSize)} OFFSET ${Number(offset)}`,
      params
    );

    // Calculate attendance status for display
    const list = rows.map(row => {
      let status = 'normal';
      let expectedTime = null;
      
      if (row.created_at && row.work_start_time) {
        const checkinTime = new Date(row.created_at);
        const timeStr = checkinTime.toTimeString().substring(0, 8); // HH:MM:SS
        
        if (row.type === 'clock_in' || row.type === 'in') {
          expectedTime = row.work_start_time;
          
          // Calculate if late
          const [h, m, s] = row.work_start_time.split(':').map(Number);
          const startLimit = new Date(checkinTime);
          startLimit.setHours(h, m + (row.late_tolerance || 0), s || 0);
          
          if (checkinTime > startLimit) {
            status = 'late';
          }
        } else if (row.type === 'clock_out' || row.type === 'out') {
          expectedTime = row.work_end_time;
          
          // Calculate if early leave
          const [h, m, s] = row.work_end_time.split(':').map(Number);
          const endLimit = new Date(checkinTime);
          endLimit.setHours(h, m - (row.early_leave_tolerance || 0), s || 0);
          
          if (checkinTime < endLimit) {
            status = 'early';
          }
        }
      }
      
      return {
        ...row,
        attendance_status: status,
        expected_time: expectedTime
      };
    });

    res.json(successResponse({ list, total, page, pageSize }));
  } catch (err) {
    console.error('查询打卡记录失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 今日打卡统计
 * GET /api/checkin/today-stats
 */
async function getTodayStats(req, res) {
  try {
    const db = getPool();
    const { start, end } = getTodayRange();

    // 总人数
    const [totalUsers] = await db.execute('SELECT COUNT(*) as total FROM users WHERE status = 1');

    // 今日已打卡上班人数
    const [checkedIn] = await db.execute(
      `SELECT COUNT(DISTINCT user_id) as total FROM checkins WHERE type = 'in' AND created_at >= ? AND created_at < ?`,
      [start, end]
    );

    // 今日已打卡下班人数
    const [checkedOut] = await db.execute(
      `SELECT COUNT(DISTINCT user_id) as total FROM checkins WHERE type = 'out' AND created_at >= ? AND created_at < ?`,
      [start, end]
    );

    // 围栏外打卡
    const [outsideCount] = await db.execute(
      `SELECT COUNT(*) as total FROM checkins WHERE is_outside = 1 AND created_at >= ? AND created_at < ?`,
      [start, end]
    );

    // 业务打卡（非上下班打卡）
    const [businessCheckins] = await db.execute(
      `SELECT COUNT(*) as total FROM checkins WHERE type NOT IN ('in', 'out', 'clock_in', 'clock_out') AND created_at >= ? AND created_at < ?`,
      [start, end]
    );

    res.json(successResponse({
      totalUsers: totalUsers[0].total,
      checkedIn: checkedIn[0].total,
      checkedOut: checkedOut[0].total,
      notCheckedIn: totalUsers[0].total - checkedIn[0].total,
      outsideCount: outsideCount[0].total,
      businessCheckins: businessCheckins[0].total
    }));
  } catch (err) {
    console.error('获取今日统计失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 根据防伪码搜索打卡记录
 * GET /api/checkin/search-code?code=XXXX
 */
async function searchByWatermarkCode(req, res) {
  try {
    const { code } = req.query;
    if (!code) {
      return res.status(400).json(errorResponse('请提供防伪码', 400));
    }

    const db = getPool();
    const [rows] = await db.query(
      `SELECT c.*, c.watermark_code, u.name as user_name, u.username, p.name as project_name
       FROM checkins c
       LEFT JOIN users u ON c.user_id = u.id
       LEFT JOIN projects p ON c.project_id = p.id
       WHERE c.watermark_code = ?`,
      [code.toUpperCase()]
    );

    if (rows.length === 0) {
      return res.json(successResponse(null, '未找到该防伪码对应的打卡记录'));
    }

    res.json(successResponse(rows[0]));
  } catch (err) {
    console.error('搜索防伪码失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 生成预占防伪码（供移动端预请求）
 * GET /api/checkin/reserve-code
 */
async function reserveCode(req, res) {
  try {
    const code = generateWatermarkCode();
    const db = getPool();
    const userId = req.user.id;
    
    // 自当前时间后30天过期
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30);

    await db.execute(
      'INSERT INTO watermark_codes (code, user_id, expires_at) VALUES (?, ?, ?)',
      [code, userId, expiresAt]
    );

    res.json(successResponse({ watermark_code: code }));
  } catch (err) {
    console.error('生成预占防伪码失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

/**
 * 导出打卡记录为Excel
 * GET /api/checkin/export
 */
async function exportCheckins(req, res) {
  try {
    const db = getPool();
    const { user_id, project_id, type, date_start, date_end, is_outside } = req.query;

    let where = 'WHERE 1=1';
    const params = [];

    if (user_id) {
      where += ' AND c.user_id = ?';
      params.push(parseInt(user_id));
    }
    if (project_id) {
      where += ' AND c.project_id = ?';
      params.push(parseInt(project_id));
    }
    if (type) {
      where += ' AND c.type = ?';
      params.push(type);
    }
    if (date_start) {
      where += ' AND c.created_at >= ?';
      params.push(date_start);
    }
    if (date_end) {
      where += ' AND c.created_at <= ?';
      params.push(date_end);
    }
    if (is_outside !== undefined && is_outside !== '') {
      where += ' AND c.is_outside = ?';
      params.push(parseInt(is_outside));
    }

    if (req.user.role === 'worker') {
      where += ' AND c.user_id = ?';
      params.push(req.user.id);
    }

    const [rows] = await db.query(
      `SELECT c.*, c.watermark_code, u.name as user_name, u.username, p.name as project_name,
              ag.work_start_time, ag.work_end_time, ag.late_tolerance, ag.early_leave_tolerance
       FROM checkins c
       LEFT JOIN users u ON c.user_id = u.id
       LEFT JOIN projects p ON c.project_id = p.id
       LEFT JOIN attendance_group_members agm ON c.user_id = agm.user_id
       LEFT JOIN attendance_groups ag ON agm.group_id = ag.id
       ${where}
       ORDER BY c.created_at DESC`,
      params
    );

    const list = rows.map(row => {
      let status = '正常';
      let expectedTime = '';
      
      if (row.created_at && row.work_start_time) {
        const checkinTime = new Date(row.created_at);
        
        if (row.type === 'clock_in' || row.type === 'in') {
          expectedTime = row.work_start_time;
          const [h, m, s] = row.work_start_time.split(':').map(Number);
          const startLimit = new Date(checkinTime);
          startLimit.setHours(h, m + (row.late_tolerance || 0), s || 0);
          if (checkinTime > startLimit) status = '迟到';
        } else if (row.type === 'clock_out' || row.type === 'out') {
          expectedTime = row.work_end_time;
          const [h, m, s] = row.work_end_time.split(':').map(Number);
          const endLimit = new Date(checkinTime);
          endLimit.setHours(h, m - (row.early_leave_tolerance || 0), s || 0);
          if (checkinTime < endLimit) status = '早退';
        }
      }
      
      return {
        ...row,
        attendance_status_text: status,
        expected_time: expectedTime
      };
    });

    const workbook = new ExcelJS.Workbook();
    const worksheet = workbook.addWorksheet('打卡记录');

    worksheet.columns = [
      { header: 'ID', key: 'id', width: 10 },
      { header: '员工姓名', key: 'user_name', width: 15 },
      { header: '用户名', key: 'username', width: 15 },
      { header: '项目名称', key: 'project_name', width: 20 },
      { header: '打卡类型', key: 'type', width: 12 },
      { header: '打卡时间', key: 'created_at', width: 20 },
      { header: '规定时间', key: 'expected_time', width: 15 },
      { header: '考勤状态', key: 'attendance_status', width: 12 },
      { header: '地址', key: 'address', width: 40 },
      { header: '纬度', key: 'latitude', width: 15 },
      { header: '经度', key: 'longitude', width: 15 },
      { header: '是否围栏外', key: 'is_outside', width: 12 },
      { header: '防伪码', key: 'watermark_code', width: 20 },
      { header: '备注', key: 'remark', width: 30 }
    ];

    worksheet.getRow(1).font = { bold: true };
    worksheet.getRow(1).fill = {
      type: 'pattern',
      pattern: 'solid',
      fgColor: { argb: 'FFE0E0E0' }
    };

    list.forEach(row => {
      worksheet.addRow({
        id: row.id,
        user_name: row.user_name || '',
        username: row.username || '',
        project_name: row.project_name || '',
        type: getTypeName(row.type),
        created_at: row.created_at ? new Date(row.created_at).toLocaleString('zh-CN', { hour12: false }) : '',
        expected_time: row.expected_time || '',
        attendance_status: row.attendance_status_text,
        address: row.address || '',
        latitude: row.latitude || '',
        longitude: row.longitude || '',
        is_outside: row.is_outside === 1 ? '是' : '否',
        watermark_code: row.watermark_code || '',
        remark: row.remark || ''
      });
    });

    const nowForFile = new Date();
    const padF = (n) => String(n).padStart(2, '0');
    const fileName = `打卡记录_${nowForFile.getFullYear()}-${padF(nowForFile.getMonth()+1)}-${padF(nowForFile.getDate())}.xlsx`;
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename*=UTF-8''${encodeURIComponent(fileName)}`);

    await workbook.xlsx.write(res);
    res.end();
  } catch (err) {
    console.error('导出打卡记录失败:', err);
    res.status(500).json(errorResponse('服务器错误'));
  }
}

module.exports = { submitCheckin, getCheckins, getTodayStats, searchByWatermarkCode, reserveCode, exportCheckins };
