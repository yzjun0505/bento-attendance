function normalizeWatermarkCode(code) {
  return String(code || '')
    .trim()
    .replace(/[\s-]+/g, '')
    .toUpperCase();
}

function statusText(status) {
  switch (status) {
    case 'used':
      return '防伪码已使用';
    case 'expired':
      return '防伪码已过期';
    case 'pending':
      return '防伪码已预占，尚未绑定打卡记录';
    default:
      return '未找到该防伪码';
  }
}

async function lookupWatermarkCode(db, code, {
  checkinScope = '',
  checkinParams = [],
  progressScope = '',
  progressParams = [],
  userScope = '',
  userParams = [],
} = {}) {
  const normalizedCode = normalizeWatermarkCode(code);
  if (!normalizedCode) {
    const err = new Error('请提供防伪码');
    err.status = 400;
    throw err;
  }

  const [checkinRows] = await db.query(
    `SELECT c.*, c.watermark_code, u.name as user_name, u.username, p.name as project_name,
            wc.status as code_status, wc.expires_at as code_expires_at
       FROM checkins c
       LEFT JOIN users u ON c.user_id = u.id
       LEFT JOIN projects p ON c.project_id = p.id
       LEFT JOIN watermark_codes wc ON wc.code = c.watermark_code
       WHERE UPPER(REPLACE(c.watermark_code, '-', '')) = ?${checkinScope}
       LIMIT 1`,
    [normalizedCode, ...checkinParams]
  );

  if (checkinRows.length > 0) {
    const row = checkinRows[0];
    const codeStatus = row.code_status || 'used';
    return {
      found: true,
      kind: 'checkin',
      code: normalizedCode,
      data: {
        ...row,
        watermark_code: row.watermark_code || normalizedCode,
        code_status: codeStatus,
        code_status_text: statusText(codeStatus),
      },
    };
  }

  const [progressRows] = await db.query(
    `SELECT pr.id, pr.node_id, pr.reporter_id as user_id, pr.description,
            pr.photo, pr.photos, pr.progress_percent, pr.watermark_codes,
            pr.created_at, u.name as user_name, u.username,
            tn.title as node_title, p.name as project_name, p.id as project_id,
            wc.status as code_status, wc.expires_at as code_expires_at
       FROM progress_reports pr
       INNER JOIN task_nodes tn ON pr.node_id = tn.id
       LEFT JOIN projects p ON tn.project_id = p.id
       LEFT JOIN users u ON pr.reporter_id = u.id
       LEFT JOIN watermark_codes wc ON UPPER(REPLACE(wc.code, '-', '')) = ?
       WHERE pr.watermark_codes IS NOT NULL
         AND JSON_CONTAINS(pr.watermark_codes, JSON_QUOTE(?))
         ${progressScope}
       LIMIT 1`,
    [normalizedCode, normalizedCode, ...progressParams]
  );

  if (progressRows.length > 0) {
    const row = progressRows[0];
    const photos = parseJsonArray(row.photos);
    const codeStatus = row.code_status || 'used';
    return {
      found: true,
      kind: 'progress_report',
      code: normalizedCode,
      data: {
        ...row,
        type: 'progress_report',
        record_type: 'progress_report',
        record_type_text: '项目进度上报',
        watermark_code: normalizedCode,
        photo: row.photo || photos[0] || '',
        code_status: codeStatus,
        code_status_text: statusText(codeStatus),
      },
    };
  }

  const [codeRows] = await db.query(
    `SELECT wc.code, wc.status, wc.created_at, wc.expires_at,
            u.id as user_id, u.name as user_name, u.username
       FROM watermark_codes wc
       LEFT JOIN users u ON wc.user_id = u.id
       WHERE UPPER(REPLACE(wc.code, '-', '')) = ?${userScope}
       LIMIT 1`,
    [normalizedCode, ...userParams]
  );

  if (codeRows.length > 0) {
    const row = codeRows[0];
    let codeStatus = row.status || 'pending';
    if (codeStatus !== 'expired' && row.expires_at && new Date(row.expires_at) < new Date()) {
      codeStatus = 'expired';
    }
    return {
      found: true,
      kind: 'reserved_code',
      code: normalizedCode,
      data: {
        watermark_code: row.code || normalizedCode,
        code_status: codeStatus,
        code_status_text: statusText(codeStatus),
        user_id: row.user_id,
        user_name: row.user_name,
        username: row.username,
        created_at: row.created_at,
        expires_at: row.expires_at,
      },
    };
  }

  return {
    found: false,
    kind: 'not_found',
    code: normalizedCode,
    data: null,
    message: statusText(null),
  };
}

function parseJsonArray(value) {
  if (!value) return [];
  if (Array.isArray(value)) return value;
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed : [];
  } catch (_) {
    return [];
  }
}

module.exports = {
  normalizeWatermarkCode,
  lookupWatermarkCode,
};
