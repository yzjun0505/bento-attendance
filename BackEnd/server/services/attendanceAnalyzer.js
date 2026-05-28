/**
 * 考勤分析引擎
 * 每天凌晨1点执行，分析昨日打卡记录并生成考勤结果
 */
const cron = require('node-cron');
const { getPool } = require('../models/db');
const notificationService = require('./notificationService');
const logger = require('../utils/logger');

const STATUS = {
  NORMAL: 'normal',
  LATE: 'late',
  EARLY_LEAVE: 'early_leave',
  ABSENT: 'absent',
  LEAVE: 'leave'
};

const CHECKIN_IN_TYPES = ['in', 'clock_in'];
const CHECKIN_OUT_TYPES = ['out', 'clock_out'];

async function analyzeAttendance() {
  console.log('⏰ 开始执行考勤分析任务...');
  const db = getPool();

  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  const pad = (n) => String(n).padStart(2, '0');
  const dateStr = `${yesterday.getFullYear()}-${pad(yesterday.getMonth() + 1)}-${pad(yesterday.getDate())}`;
  const startOfDay = `${dateStr} 00:00:00`;
  const endOfDay = `${dateStr} 23:59:59`;

  try {
    const [groups] = await db.execute(
      `SELECT ag.id, ag.name, ag.work_start_time as start_time, ag.work_end_time as end_time, 
        ag.late_tolerance, ag.early_leave_tolerance, ag.project_id
       FROM attendance_groups ag
       WHERE ag.status = 1`
    );

    if (groups.length === 0) {
      console.log('⚠️ 没有启用的考勤组，跳过分析');
      return;
    }

    for (const group of groups) {
      const [members] = await db.execute(
        `SELECT agm.user_id, u.name as user_name
         FROM attendance_group_members agm
         LEFT JOIN users u ON agm.user_id = u.id
         WHERE agm.group_id = ? AND u.status = 1 AND u.role != 'admin'`,
        [group.id]
      );

      for (const member of members) {
        const [checkins] = await db.execute(
          `SELECT id, type, TIME(created_at) as check_time, created_at
           FROM checkins
           WHERE user_id = ? AND created_at >= ? AND created_at < ?
           ORDER BY created_at ASC`,
          [member.user_id, startOfDay, endOfDay]
        );

        const checkinRecord = checkins.find(c => CHECKIN_IN_TYPES.includes(c.type));
        const checkoutRecord = checkins.find(c => CHECKIN_OUT_TYPES.includes(c.type));

        let status = STATUS.ABSENT;
        let checkinTime = null;
        let checkoutTime = null;

        if (checkinRecord) {
          checkinTime = checkinRecord.check_time;
          const [startHour, startMin] = group.start_time.split(':').map(Number);
          const [checkHour, checkMin] = checkinRecord.check_time.split(':').map(Number);
          const startMinutes = startHour * 60 + startMin;
          const checkMinutes = checkHour * 60 + checkMin;

          if (checkMinutes <= startMinutes + (group.late_tolerance || 0)) {
            status = STATUS.NORMAL;
          } else {
            status = STATUS.LATE;
          }
        }

        if (checkoutRecord) {
          checkoutTime = checkoutRecord.check_time;
          const [endHour, endMin] = group.end_time.split(':').map(Number);
          const [checkHour, checkMin] = checkoutRecord.check_time.split(':').map(Number);
          const endMinutes = endHour * 60 + endMin;
          const checkMinutes = checkHour * 60 + checkMin;

          if (checkMinutes < endMinutes && status === STATUS.NORMAL) {
            status = STATUS.EARLY_LEAVE;
          }
        }

        const [existing] = await db.execute(
          'SELECT id FROM attendance_results WHERE user_id = ? AND date = ?',
          [member.user_id, dateStr]
        );

        if (existing.length > 0) {
          await db.execute(
            'UPDATE attendance_results SET status = ?, checkin_time = ?, checkout_time = ?, group_id = ? WHERE id = ?',
            [status, checkinTime, checkoutTime, group.id, existing[0].id]
          );
        } else {
          await db.execute(
            'INSERT INTO attendance_results (user_id, date, status, checkin_time, checkout_time, group_id) VALUES (?, ?, ?, ?, ?, ?)',
            [member.user_id, dateStr, status, checkinTime, checkoutTime, group.id]
          );
        }
      }
    }

    console.log(`✅ 考勤分析完成: ${dateStr}`);
  } catch (err) {
    console.error('❌ 考勤分析失败:', err);
  }
}

/**
 * 每日报告推送 — 向经理/管理员发送前一日考勤汇总
 */
async function sendDailyReport() {
  try {
    const db = getPool();
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const pad = (n) => String(n).padStart(2, '0');
    const dateStr = `${yesterday.getFullYear()}-${pad(yesterday.getMonth() + 1)}-${pad(yesterday.getDate())}`;

    const [[summary]] = await db.query(`
      SELECT
        COUNT(DISTINCT ar.user_id) as totalAttendees,
        SUM(CASE WHEN ar.status = 'normal' THEN 1 ELSE 0 END) as normalCount,
        SUM(CASE WHEN ar.status = 'late' THEN 1 ELSE 0 END) as lateCount,
        SUM(CASE WHEN ar.status = 'absent' THEN 1 ELSE 0 END) as absentCount,
        SUM(CASE WHEN ar.status = 'leave' THEN 1 ELSE 0 END) as leaveCount,
        SUM(CASE WHEN ar.status = 'early_leave' THEN 1 ELSE 0 END) as earlyLeaveCount
      FROM attendance_results ar
      JOIN users u ON ar.user_id = u.id
      WHERE ar.date = ? AND u.role != 'admin'
    `, [dateStr]);

    const [absentUsers] = await db.query(`
      SELECT u.name FROM attendance_results ar
      JOIN users u ON ar.user_id = u.id
      WHERE ar.date = ? AND ar.status = 'absent' AND u.role != 'admin'
    `, [dateStr]);

    const [projects] = await db.query(`
      SELECT name,
        ROUND(AVG(progress_percent), 1) as overallProgress,
        SUM(CASE WHEN status = 'in_progress' THEN 1 ELSE 0 END) as activeNodes,
        SUM(CASE WHEN plan_end_date < CURDATE() AND status != 'completed' THEN 1 ELSE 0 END) as overdueNodes
      FROM task_nodes tn
      JOIN projects p ON tn.project_id = p.id
      GROUP BY tn.project_id, p.name
    `).catchError(() => []);

    const absentNames = absentUsers.map(u => u.name).join('、') || '无';
    const projectLines = (projects || []).map(p =>
      `· ${p.name}: ${p.overallProgress}% (进行中${p.activeNodes}项, 逾期${p.overdueNodes}项)`
    ).join('\n') || '暂无项目数据';

    const content = `📊 ${dateStr} 考勤日报

👥 出勤统计：
· 正常: ${summary.normalCount || 0}人
· 迟到: ${summary.lateCount || 0}人
· 早退: ${summary.earlyLeaveCount || 0}人
· 请假: ${summary.leaveCount || 0}人
· 缺勤: ${summary.absentCount || 0}人
· 出勤总人数: ${summary.totalAttendees || 0}人

⚠️ 缺勤人员：${absentNames}

📐 项目进度：
${projectLines}`;

    const [managers] = await db.query(
      `SELECT id FROM users WHERE status = 1 AND role IN ('admin', 'manager')`
    );
    const managerIds = managers.map(r => r.id);
    if (managerIds.length > 0) {
      await notificationService.createNotificationForUsers(managerIds, {
        title: `📊 ${dateStr} 考勤日报`,
        content,
        type: 'report',
      });
      logger.info(`每日报告已推送至 ${managerIds.length} 位管理者`);
    }
  } catch (err) {
    logger.error('发送每日报告失败', { error: err.message });
  }
}

function startScheduler() {
  cron.schedule('0 1 * * *', analyzeAttendance, {
    timezone: 'Asia/Shanghai'
  });
  // 每日报告推送：上午9点
  cron.schedule('0 9 * * *', sendDailyReport, {
    timezone: 'Asia/Shanghai'
  });
  console.log('✅ 定时任务已启动 (凌晨1点考勤分析，上午9点日报推送)');
}

module.exports = { analyzeAttendance, sendDailyReport, startScheduler, STATUS };
