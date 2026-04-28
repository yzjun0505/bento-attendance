/**
 * 考勤分析引擎
 * 每天凌晨1点执行，分析昨日打卡记录并生成考勤结果
 */
const cron = require('node-cron');
const { getPool } = require('../models/db');

const STATUS = {
  NORMAL: 'normal',
  LATE: 'late',
  EARLY_LEAVE: 'early_leave',
  ABSENT: 'absent',
  LEAVE: 'leave'
};

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
       FROM attendance_groups ag`
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
         WHERE agm.group_id = ? AND u.status = 1`,
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

        const checkinRecord = checkins.find(c => c.type === 'in');
        const checkoutRecord = checkins.find(c => c.type === 'out');

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

function startScheduler() {
  cron.schedule('0 1 * * *', analyzeAttendance, {
    timezone: 'Asia/Shanghai'
  });
  console.log('✅ 考勤分析定时任务已启动 (每天凌晨1点执行)');
}

module.exports = { analyzeAttendance, startScheduler, STATUS };
