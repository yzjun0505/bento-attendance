# Tasks

- [x] Task 1: 修复 Mobile App 中打卡时间差 8 小时的问题
  - [x] SubTask 1.1: 打开 `MobileApp/lib/models/checkin_model.dart`。
  - [x] SubTask 1.2: 在 `Checkin.fromJson` 中，解析 `created_at` 字段时，先判断字符串是否有 `Z` 或时区后缀，如果没有则补充 `Z` 强制作为 UTC 时间，然后再使用 `toLocal()` 转换为本地时间。

- [x] Task 2: 修正 Mobile App 中的“距离围栏”文案
  - [x] SubTask 2.1: 全局搜索 App 工程中的“距离”及“围栏”，将考勤界面的 `距离围栏` 或 `距离` 统一修改为 `距离围栏中心`。例如 `attendance_screen.dart` 的列表视图中。

- [x] Task 3: 在 Web 管理端显示打卡距离
  - [x] SubTask 3.1: 打开 `BackEnd/web-admin/src/views/Checkin.vue`。
  - [x] SubTask 3.2: 找到表格列 `<el-table-column prop="is_outside" label="围栏">`。
  - [x] SubTask 3.3: 在表格单元格的模板中，除了原有的状态标签（围栏外/正常）之外，如果 `row.distance_to_fence` 存在，在下方补充一行灰色小字显示：`距离中心：{{ Math.round(row.distance_to_fence) }} 米`。

# Task Dependencies
- [Task 1] depends on None
- [Task 2] depends on None
- [Task 3] depends on None
