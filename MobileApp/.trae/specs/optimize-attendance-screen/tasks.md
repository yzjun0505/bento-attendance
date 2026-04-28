# Tasks

- [x] Task 1: 优化 MapDashboardScreen 加载与骨架屏
  - [x] SubTask 1.1: 修改 `MapDashboardScreen`，使打卡面板在 `AttendanceLoading` 或未加载完成的状态下即可提前渲染骨架或缓存按钮，避免进入页面时底部的空白和长加载转圈。

- [x] Task 2: 重新设计 MapDashboardScreen 底部操作面板
  - [x] SubTask 2.1: 移除原有的“本地图库” (`_buildAuxEntry`) 和“更多打卡类型” (`_buildMoreCheckinTypes`)。
  - [x] SubTask 2.2: 重新排列打卡按钮区域，将“水印拍照” (`_buildBigPhotoButton`) 居中作为主位按钮。
  - [x] SubTask 2.3: 缩小“上班”和“下班”打卡按钮的尺寸，将它们改为辅位按钮，排列在“水印拍照”按钮的两侧（左侧为上班，右侧为下班，或者放置在其上方一排），整体减少底部面板的高度以留出更多空间给地图。
  - [x] SubTask 2.4: 确保“上班”和“下班”点击后依然自动获取位置并提交，不跳转到水印相机（维持原 `_handleCheckin` 逻辑）。

- [x] Task 3: 在 CameraCheckinScreen 中整合打卡类型与本地图库
  - [x] SubTask 3.1: 在水印相机界面 (`CameraCheckinScreen`) 的底部控制区（例如快门键左侧）增加“本地图库”入口，点击可打开 `/gallery`。
  - [x] SubTask 3.2: 将“更多打卡类型”的选择移动到水印相机页面，可以在顶部标题栏或水印设置面板中增加一个“打卡类型”的下拉选择器或弹窗，供用户选择“外出”、“加班”等其他打卡类型。

# Task Dependencies
- [Task 2] depends on [Task 1]
- [Task 3] depends on [Task 2]
