# Fix Attendance Time and Distance Spec

## Why
当前应用存在两个影响打卡体验的体验问题：
1. **上下班打卡时间对不上**：因为服务端数据库返回的时间字符串是 UTC 标准，但在 `mysql2` 关闭了默认的 Date 转换后直接作为字符串返回。App 端在 `DateTime.parse()` 时没有将其识别为 UTC 并转换，导致本地显示了偏移了 8 小时的时间。
2. **打卡距离表述和展示不完整**：在 App 的打卡界面上，目前展示的是“距离围栏多少米”，由于实际计算逻辑是计算距离围栏**中心点**的距离，在表述上改为“距离围栏中心 X 米”更为准确。同时，Web 端的打卡管理界面并未展示该距离，导致后台管理人员无法直观判断打卡距离中心的位置（不论是否在围栏内都需要显示）。

## What Changes
- **修复时间解析问题**：在 App 的 `Checkin` 模型中，对 `createdAt` 的解析增加对 UTC 的强制转换与本地时间化处理，以确保时间显示准确。
- **修改距离文案**：在 App 端的考勤展示相关页面（如 MapDashboardScreen、HistoryScreen 等）中，将“距离围栏”修改为“距离围栏中心”。
- **更新 Web 管理界面**：在 Web 管理后台（`Checkin.vue`）的打卡列表中，“围栏”一列不仅显示正常或围栏外的状态标签，还要在其下方补充显示“距离中心：X 米”。

## Impact
- Affected specs: Checkin Data Parsing, App UI Wording, Web Admin UI
- Affected code:
  - `MobileApp/lib/models/checkin_model.dart`
  - `MobileApp/lib/screens/attendance/attendance_screen.dart` / `map_dashboard_screen.dart` 等展示距离的文件
  - `BackEnd/web-admin/src/views/Checkin.vue`

## ADDED Requirements
### Requirement: Distance Display on Web Admin
The system SHALL display the exact distance to the project's geofence center in the Web Admin check-in list view, underneath the status tag (e.g., "距离中心: 120米"), for all check-in records that have distance data.

## MODIFIED Requirements
### Requirement: Accurate Time Parsing
**Reason**: To resolve the 8-hour timezone shift issue caused by database timezone settings.
**Migration**: Update `Checkin.fromJson` to ensure `created_at` string is treated as UTC and converted to local time via `.toLocal()`.

### Requirement: Distance Terminology
**Reason**: To clarify that the distance is calculated from the center of the geofence, not its edge.
**Migration**: Change all "距离围栏" texts to "距离围栏中心" in the Mobile App UI.
