# Optimize Attendance Screen Spec

## Why
当前打卡界面（MapDashboardScreen）的“今日考勤”部分在进入时需要较长的加载时间，影响了用户的快速打卡体验（无论是离线还是在线状态）。此外，底部的操作面板占据了过多的屏幕空间，导致地图显示区域在手机端显得过于狭小。在功能主次关系上，当前大号的“水印拍照”容易被误认为是“上下班打卡”，而“本地图库”和“更多打卡类型”的入口在首页和水印相机页面存在功能重叠，需要在设计上做减法和层级梳理。

## What Changes
- **优化打卡按钮的加载速度**：解除界面对 `AttendanceLoaded` 状态的强依赖，即使在加载中（`AttendanceLoading`）也优先渲染骨架屏或基于本地缓存的打卡按钮，让用户能立刻看到按钮。
- **调整按钮主次与布局**：将“水印拍照”作为主位按钮，居中并放大显示；将“上班打卡”和“下班打卡”作为辅位按钮，缩小尺寸并放置在主按钮两侧，释放更多空间给地图。
- **精简首页元素**：从首页打卡面板中移除“本地图库”按钮和“更多打卡类型”列表。
- **将精简功能转移至水印相机页**：在 `CameraCheckinScreen` 中增加“本地图库”入口（如放置在快门键左侧），并将“更多打卡类型”集成到水印相机页的设置或界面中。

## Impact
- Affected specs: UI Layout, Attendance Data Loading Logic
- Affected code:
  - `MobileApp/lib/screens/attendance/map_dashboard_screen.dart`
  - `MobileApp/lib/screens/attendance/camera_checkin_screen.dart`

## ADDED Requirements
### Requirement: Instant Render of Attendance Panel
The system SHALL display the check-in panel (Clock In/Out, Watermark Camera) immediately upon entering the MapDashboardScreen, using cached or empty states if network requests are pending.

### Requirement: Centralized Watermark Camera
The system SHALL present the "Watermark Camera" as the primary centered action button on the MapDashboardScreen, with "Clock In" and "Clock Out" as secondary buttons on the sides.

### Requirement: Relocated Features
The system SHALL provide access to the "Local Gallery" and "More Check-in Types" exclusively from within the CameraCheckinScreen, removing them from the main dashboard.

## MODIFIED Requirements
### Requirement: Clock In / Out Action
**Reason**: To clarify that Clock In/Out is secondary and distinct from taking a watermark photo.
**Migration**: The buttons will automatically capture location and submit the check-in directly (which is already the underlying logic, but the UI must make it clear that it's a one-tap action).

## REMOVED Requirements
### Requirement: Local Gallery on Dashboard
**Reason**: Redundant with the feature inside the watermark camera.
**Migration**: Removed from dashboard.

### Requirement: More Check-in Types on Dashboard
**Reason**: Clutters the dashboard and takes up map space.
**Migration**: Moved to CameraCheckinScreen.
