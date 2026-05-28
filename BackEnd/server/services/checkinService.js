const notificationService = require('./notificationService');

const TYPE_NAME_MAP = {
  in: '上班打卡',
  out: '下班打卡',
  clock_in: '上班打卡',
  clock_out: '下班打卡',
  site_visit: '实地考察',
  progress: '项目进度上报',
  safety: '安全检查',
  device: '设备位置上报',
  custom: '自定义',
};

const BASE_CHECKIN_TYPES = Object.keys(TYPE_NAME_MAP);
const OUTSIDE_CHECKIN_APPROVAL_TYPE = '异常打卡';

function getTypeName(type) {
  return TYPE_NAME_MAP[type] || type;
}

function pad(n) {
  return String(n).padStart(2, '0');
}

function formatDate(dateInput) {
  const d = new Date(dateInput);
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function parseLocalDateTime(value) {
  if (!value) return new Date();
  if (value instanceof Date) return value;
  return new Date(String(value).replace(' ', 'T'));
}

function formatDateTime(dateInput) {
  const d = parseLocalDateTime(dateInput);
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
}

async function getValidCheckinTypes(db) {
  const [customTypes] = await db.execute('SELECT code FROM checkin_types WHERE status = 1');
  return new Set([...BASE_CHECKIN_TYPES, ...customTypes.map((type) => type.code)]);
}

async function validateCheckinType(db, type) {
  if (!type) {
    const err = new Error('打卡类型不能为空');
    err.status = 400;
    throw err;
  }
  const validTypes = await getValidCheckinTypes(db);
  if (!validTypes.has(type)) {
    const err = new Error('不合法的打卡类型');
    err.status = 400;
    throw err;
  }
}

async function calculateFenceStatus(db, { project_id, latitude, longitude }) {
  let isOutside = 0;
  let distanceToFence = null;

  if (project_id && latitude && longitude) {
    const [projects] = await db.execute(
      'SELECT latitude, longitude, radius FROM projects WHERE id = ?',
      [project_id]
    );
    if (projects.length > 0) {
      const project = projects[0];
      if (project.latitude && project.longitude) {
        const distance = calculateDistance(
          latitude,
          longitude,
          project.latitude,
          project.longitude
        );
        distanceToFence = Math.round(distance);
        isOutside = distance > (project.radius || 500) ? 1 : 0;
      }
    }
  }

  return { isOutside, distanceToFence };
}

async function useWatermarkCode(connection, { watermarkCode, userId }) {
  if (!watermarkCode) return;

  const [codes] = await connection.execute(
    'SELECT * FROM watermark_codes WHERE code = ? AND user_id = ? FOR UPDATE',
    [watermarkCode, userId]
  );

  if (codes.length === 0) {
    const err = new Error('非法的防伪码，请使用本系统拍摄');
    err.status = 400;
    throw err;
  }

  const codeRecord = codes[0];
  if (codeRecord.status === 'used') {
    const err = new Error('该照片已上传过打卡，不可重复使用');
    err.status = 400;
    throw err;
  }

  if (codeRecord.status === 'expired' || new Date(codeRecord.expires_at) < new Date()) {
    await connection.execute('UPDATE watermark_codes SET status = ? WHERE id = ?', ['expired', codeRecord.id]);
    const err = new Error('此照片拍摄已超过30天有效期，防伪码已作废');
    err.status = 400;
    throw err;
  }

  await connection.execute('UPDATE watermark_codes SET status = ? WHERE id = ?', ['used', codeRecord.id]);
}

async function createOutsideCheckinApproval(db, { checkinId, userId, type, address, distanceToFence, createdAt }) {
  const dateStr = formatDate(createdAt || new Date());
  const typeName = getTypeName(type);
  const distanceText = distanceToFence == null ? '未知' : `${Math.round(distanceToFence)}米`;
  const reason = `系统自动生成：${typeName}发生围栏外打卡，距离围栏中心约${distanceText}，地点：${address || '未知位置'}。`;

  const [result] = await db.execute(
    `INSERT INTO approval_requests (user_id, checkin_id, type, reason, start_date, end_date)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [userId, checkinId, OUTSIDE_CHECKIN_APPROVAL_TYPE, reason, dateStr, dateStr]
  );

  await db.execute(
    `UPDATE checkins
     SET outside_approval_status = 'pending', approval_request_id = ?
     WHERE id = ?`,
    [result.insertId, checkinId]
  );

  return result.insertId;
}

async function notifyManagersForOutsideCheckin(db, { userId, checkinId, approvalId, type, address, distanceToFence, source }) {
  try {
    const [managerRows] = await db.execute(
      `SELECT id FROM users WHERE status = 1 AND role IN ('admin', 'manager')`
    );
    const managerIds = managerRows.map((row) => row.id).filter((id) => Number(id) !== Number(userId));
    if (managerIds.length === 0) return;

    const distanceText = distanceToFence == null ? '未知' : `${Math.round(distanceToFence)}米`;
    const sourceText = source === 'offline' ? '离线同步' : '在线';
    await notificationService.createNotificationForUsers(managerIds, {
      title: '围栏外打卡待审批',
      content: `${sourceText}打卡记录 #${checkinId} 已生成异常打卡审批 #${approvalId}。类型：${getTypeName(type)}，距离：${distanceText}，地点：${address || '未知位置'}。`,
      type: 'alert',
    });
  } catch (err) {
    console.warn('围栏外打卡通知管理员失败(忽略):', err.message);
  }
}

async function notifyOfflineSyncResult(db, { userId, synced, failed, total }) {
  if (total === 0) return;
  try {
    await notificationService.createNotification({
      user_id: userId,
      title: failed > 0 ? '离线打卡部分同步失败' : '离线打卡同步完成',
      content: `本次离线打卡同步共 ${total} 条，成功 ${synced} 条，失败 ${failed} 条。`,
      type: 'checkin',
    });
  } catch (err) {
    console.warn('离线同步结果通知失败(忽略):', err.message);
  }
}

async function calculateCheckinStatus(db, { userId, type, createdAt }) {
  const checkTime = parseLocalDateTime(createdAt || new Date());
  let checkinStatus = 'normal';
  let statusMessage = '打卡成功';

  if (type === 'clock_in' || type === 'in') {
    const [groups] = await db.execute(`
      SELECT ag.work_start_time, ag.late_tolerance
      FROM attendance_groups ag
      JOIN attendance_group_members agm ON ag.id = agm.group_id
      WHERE agm.user_id = ? AND ag.status = 1
      LIMIT 1
    `, [userId]);

    if (groups.length > 0) {
      const group = groups[0];
      const [startHour, startMin] = group.work_start_time.split(':').map(Number);
      const startMinutes = startHour * 60 + startMin;
      const checkMinutes = checkTime.getHours() * 60 + checkTime.getMinutes();
      if (checkMinutes > startMinutes + (group.late_tolerance || 0)) {
        checkinStatus = 'late';
        statusMessage = '打卡成功（迟到）';
      }
    }
  } else if (type === 'clock_out' || type === 'out') {
    const [groups] = await db.execute(`
      SELECT ag.work_end_time, ag.early_leave_tolerance
      FROM attendance_groups ag
      JOIN attendance_group_members agm ON ag.id = agm.group_id
      WHERE agm.user_id = ? AND ag.status = 1
      LIMIT 1
    `, [userId]);

    if (groups.length > 0) {
      const group = groups[0];
      const [endHour, endMin] = group.work_end_time.split(':').map(Number);
      const endMinutes = endHour * 60 + endMin;
      const checkMinutes = checkTime.getHours() * 60 + checkTime.getMinutes();
      if (checkMinutes < endMinutes - (group.early_leave_tolerance || 0)) {
        checkinStatus = 'early_leave';
        statusMessage = '打卡成功（早退）';
      }
    }
  }

  return { checkinStatus, statusMessage };
}

async function insertCheckinInTransaction(db, { userId, data, source = 'online' }) {
  const type = data.type;
  await validateCheckinType(db, type);

  const createdAt = data.local_timestamp || data.created_at || null;
  const watermarkCode = data.watermark_code || null;
  const { isOutside, distanceToFence } = await calculateFenceStatus(db, data);

  await useWatermarkCode(db, { watermarkCode, userId });

  const fields = ['user_id', 'project_id', 'type', 'latitude', 'longitude', 'address', 'photo', 'remark', 'is_outside', 'distance_to_fence', 'watermark_code'];
  const placeholders = ['?', '?', '?', '?', '?', '?', '?', '?', '?', '?', '?'];
  const values = [
    userId,
    data.project_id || null,
    type,
    data.latitude || null,
    data.longitude || null,
    data.address || '',
    data.photo || '',
    data.remark || '',
    isOutside,
    distanceToFence,
    watermarkCode,
  ];

  if (createdAt) {
    fields.push('created_at');
    placeholders.push('?');
    values.push(formatDateTime(createdAt));
  }

  const [result] = await db.execute(
    `INSERT INTO checkins (${fields.join(', ')}) VALUES (${placeholders.join(', ')})`,
    values
  );

  const checkinId = result.insertId;
  let approvalId = null;
  if (isOutside === 1) {
    approvalId = await createOutsideCheckinApproval(db, {
      checkinId,
      userId,
      type,
      address: data.address,
      distanceToFence,
      createdAt: createdAt || new Date(),
    });
  }

  return {
    id: checkinId,
    is_outside: isOutside,
    outside_approval_status: isOutside === 1 ? 'pending' : 'none',
    approval_request_id: approvalId,
    watermark_code: watermarkCode,
    distance_to_fence: distanceToFence,
    type,
    address: data.address,
    createdAt: createdAt || new Date(),
    source,
  };
}

async function createCheckin(db, { userId, data, source = 'online', notifyManagers = true }) {
  // 管理员无需打卡
  const [[userCheck]] = await db.execute('SELECT role FROM users WHERE id = ?', [userId]);
  if (userCheck && userCheck.role === 'admin') {
    const err = new Error('管理员无需打卡');
    err.status = 400;
    throw err;
  }

  const connection = await db.getConnection();
  let inserted;
  try {
    await connection.beginTransaction();
    inserted = await insertCheckinInTransaction(connection, {
      userId,
      data,
      source,
    });
    await connection.commit();
  } catch (err) {
    try {
      await connection.rollback();
    } catch (_) {}
    throw err;
  } finally {
    connection.release();
  }

  const status = await calculateCheckinStatus(db, {
    userId,
    type: inserted.type,
    createdAt: inserted.createdAt,
  });
  const statusMessage = inserted.is_outside === 1
    ? (inserted.approval_request_id ? '打卡成功（围栏外，已生成审批）' : '打卡成功（围栏外）')
    : status.statusMessage;

  if (inserted.approval_request_id && notifyManagers) {
    notifyManagersForOutsideCheckin(db, {
      userId,
      checkinId: inserted.id,
      approvalId: inserted.approval_request_id,
      type: inserted.type,
      address: inserted.address,
      distanceToFence: inserted.distance_to_fence,
      source,
    });
  }

  return {
    id: inserted.id,
    is_outside: inserted.is_outside,
    outside_approval_status: inserted.outside_approval_status,
    approval_request_id: inserted.approval_request_id,
    watermark_code: inserted.watermark_code,
    checkin_status: status.checkinStatus,
    distance_to_fence: inserted.distance_to_fence,
    message: statusMessage,
  };
}

async function createCheckinsBatch(db, { userId, checkins, source = 'offline', notifyManagers = true }) {
  if (!Array.isArray(checkins) || checkins.length === 0) return [];

  const connection = await db.getConnection();
  const insertedRows = [];
  try {
    await connection.beginTransaction();
    for (const item of checkins) {
      if (!item?.type || !item?.local_timestamp) {
        const err = new Error('离线打卡数据缺少类型或本地时间');
        err.status = 400;
        throw err;
      }
      const inserted = await insertCheckinInTransaction(connection, {
        userId,
        data: item,
        source,
      });
      insertedRows.push(inserted);
    }
    await connection.commit();
  } catch (err) {
    try {
      await connection.rollback();
    } catch (_) {}
    throw err;
  } finally {
    connection.release();
  }

  if (notifyManagers) {
    for (const inserted of insertedRows) {
      if (inserted.approval_request_id) {
        notifyManagersForOutsideCheckin(db, {
          userId,
          checkinId: inserted.id,
          approvalId: inserted.approval_request_id,
          type: inserted.type,
          address: inserted.address,
          distanceToFence: inserted.distance_to_fence,
          source,
        });
      }
    }
  }

  return insertedRows;
}

function calculateDistance(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLng / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

module.exports = {
  createCheckin,
  createCheckinsBatch,
  getTypeName,
  notifyOfflineSyncResult,
};
