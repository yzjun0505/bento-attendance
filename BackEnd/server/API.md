# P1 功能模块 API 文档

## 1. 班次管理 (/api/shifts)

### 获取班次列表
```
GET /api/shifts?page=1&pageSize=20&keyword=&status=1
```

### 获取单个班次
```
GET /api/shifts/:id
```

### 创建班次
```
POST /api/shifts
Body: {
  "name": "早班",
  "start_time": "06:00:00",
  "end_time": "14:00:00",
  "late_tolerance": 15,
  "early_leave_tolerance": 15,
  "color": "#3B82F6",
  "sort_order": 1
}
```

### 更新班次
```
PUT /api/shifts/:id
Body: { "name": "早班", "start_time": "06:00:00", ... }
```

### 删除班次
```
DELETE /api/shifts/:id
```

---

## 2. 排班管理 (/api/schedules)

### 获取用户排班
```
GET /api/schedules?user_id=1&date_start=2024-01-01&date_end=2024-01-31
```

### 批量排班
```
POST /api/schedules/batch
Body: {
  "user_ids": [1, 2, 3],
  "date_start": "2024-01-01",
  "date_end": "2024-01-07",
  "shift_id": 1,
  "rest_dates": ["2024-01-06", "2024-01-07"]  // 周末休息
}
```

### 设置某天休息/取消休息
```
PUT /api/schedules/:id/rest
Body: { "is_rest": true }
```

### 删除排班
```
DELETE /api/schedules/:id
```

### 获取某天排班日历（管理端）
```
GET /api/schedules/calendar?date=2024-01-01
```

### 获取今日排班（移动端）
```
GET /api/schedules/today
Response: {
  "shift_name": "白班",
  "start_time": "08:00:00",
  "end_time": "17:00:00",
  "late_tolerance": 15,
  "early_leave_tolerance": 15
}
```

---

## 3. 节假日管理 (/api/holidays)

### 获取节假日列表
```
GET /api/holidays?year=2024
```

### 创建节假日
```
POST /api/holidays
Body: {
  "name": "国庆节",
  "date": "2024-10-01",
  "type": "holiday"  // holiday=放假, workday=调休上班
}
```

### 批量创建节假日
```
POST /api/holidays/batch
Body: {
  "holidays": [
    { "name": "元旦", "date": "2024-01-01", "type": "holiday" },
    { "name": "春节调休", "date": "2024-02-04", "type": "workday" }
  ]
}
```

### 更新节假日
```
PUT /api/holidays/:id
Body: { "name": "国庆节", "type": "holiday" }
```

### 删除节假日
```
DELETE /api/holidays/:id
```

### 检查某天类型
```
GET /api/holidays/check?date=2024-10-01
Response: {
  "is_holiday": true,
  "is_workday": false,
  "info": { "name": "国庆节", "type": "holiday" }
}
```

---

## 4. 离线打卡 (/api/offline-checkins)

### 提交离线打卡缓存
```
POST /api/offline-checkins
Body: {
  "type": "clock_in",
  "latitude": 39.9042,
  "longitude": 116.4074,
  "address": "北京市",
  "photo": "base64...",
  "remark": "现场无网络",
  "project_id": 1,
  "local_timestamp": "2024-01-01 08:30:00"
}
```

### 获取我的离线打卡记录
```
GET /api/offline-checkins/mine
```

### 同步离线打卡到正式记录
```
POST /api/offline-checkins/sync
Response: { "synced": 3, "failed": 0, "total": 3 }
```

### 获取所有离线打卡（管理端）
```
GET /api/offline-checkins?user_id=1&synced=0
```

---

## 5. 轨迹回放 (/api/tracks)

### 获取某人某天轨迹
```
GET /api/tracks/:userId?date=2024-01-01
Response: {
  "user": { "id": 1, "name": "张三" },
  "date": "2024-01-01",
  "total_points": 45,
  "total_distance": 12500,
  "stay_points": [
    { "start": "08:00:00", "end": "12:00:00", "duration": 240, "address": "项目A" }
  ],
  "track": [
    { "latitude": 39.9, "longitude": 116.4, "source": "location", "time": "08:00:00" },
    { "latitude": 39.91, "longitude": 116.41, "source": "checkin", "type": "clock_in", "time": "08:30:00" }
  ]
}
```

### 获取热力图数据
```
GET /api/tracks/heatmap?date_start=2024-01-01&date_end=2024-01-07&project_id=1
```

---

## 6. 审批管理 (/api/approvals) - 已增强

### 创建审批申请
```
POST /api/approvals
Body: {
  "type": "请假",  // 补卡/请假/加班
  "reason": "家中有事",
  "start_date": "2024-01-01",
  "end_date": "2024-01-03"
}
```

### 审批通过（自动联动考勤）
```
PUT /api/approvals/:id/approve
Body: { "remark": "同意" }
```
联动逻辑：
- **补卡** → 对应日期考勤状态改为 `normal`
- **请假** → 对应日期范围考勤状态改为 `leave`
- **加班** → 对应日期范围标记 `overtime=1`

### 审批驳回
```
PUT /api/approvals/:id/reject
Body: { "remark": "理由不充分" }
```

---

## 数据库新增表

### shifts (班次表)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 主键 |
| name | VARCHAR(100) | 班次名称 |
| start_time | TIME | 上班时间 |
| end_time | TIME | 下班时间 |
| late_tolerance | INT | 允许迟到分钟 |
| early_leave_tolerance | INT | 允许早退分钟 |
| color | VARCHAR(20) | 颜色标识 |
| sort_order | INT | 排序 |
| status | TINYINT | 1启用/0停用 |

### user_schedules (排班表)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 主键 |
| user_id | INT | 用户ID |
| date | DATE | 排班日期 |
| shift_id | INT | 班次ID |
| is_rest | TINYINT | 是否休息 |

### holidays (节假日表)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 主键 |
| name | VARCHAR(100) | 节假日名称 |
| date | DATE | 日期 |
| type | ENUM | holiday/workday |
| year | INT | 年份 |

### offline_checkins (离线打卡缓存表)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT | 主键 |
| user_id | INT | 用户ID |
| type | VARCHAR(50) | 打卡类型 |
| latitude | DOUBLE | 纬度 |
| longitude | DOUBLE | 经度 |
| local_timestamp | DATETIME | 设备本地时间 |
| synced | TINYINT | 是否已同步 |
| sync_time | DATETIME | 同步时间 |
