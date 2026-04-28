# 修复拍照后程序无响应问题

## 问题分析

拍照后程序无响应的原因：

1. **位置获取阻塞**：`_addWatermarkToPhoto` 方法中调用 `Geolocator.getCurrentPosition()` 没有设置超时，如果 GPS 信号弱或无法定位，会导致程序长时间卡住

2. **重复获取位置**：每次拍照都重新获取位置，而实际上 `AttendanceLoaded` 状态中已经有当前位置信息

3. **缺少加载提示**：虽然有 `_isProcessing` 标志，但用户可能没注意到

## 修复步骤

### 步骤 1：修改 `attendance_screen.dart` 中的 `_addWatermarkToPhoto` 方法

- 移除重复的位置获取逻辑
- 直接使用 `AttendanceLoaded` 状态中已有的位置信息
- 添加超时处理和错误提示

### 步骤 2：优化水印服务 `watermark_service.dart`

- 添加错误处理
- 确保图片处理不会无限等待

### 步骤 3：改进用户体验

- 添加处理进度提示
- 确保错误时有明确的反馈

## 具体代码修改

### 修改 1：`lib/screens/attendance/attendance_screen.dart`

将 `_addWatermarkToPhoto` 方法从：

```dart
Future<File?> _addWatermarkToPhoto(File photoFile) async {
  try {
    final authState = context.read<AuthBloc>().state;
    final attendanceState = context.read<AttendanceBloc>().state;
    
    if (authState is! AuthAuthenticated || attendanceState is! AttendanceLoaded) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    return await WatermarkService.addWatermark(
      imageFile: photoFile,
      userName: authState.user.name,
      projectName: attendanceState.nearestProject?.name ?? '未关联项目',
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: DateTime.now(),
    );
  } catch (e) {
    print('添加水印失败: $e');
    return null;
  }
}
```

改为：

```dart
Future<File?> _addWatermarkToPhoto(File photoFile, AttendanceLoaded state) async {
  try {
    final authState = context.read<AuthBloc>().state;
    
    if (authState is! AuthAuthenticated) {
      return null;
    }

    // 使用已有位置，避免重复获取导致卡顿
    final latitude = state.currentLatitude ?? 0.0;
    final longitude = state.currentLongitude ?? 0.0;

    return await WatermarkService.addWatermark(
      imageFile: photoFile,
      userName: authState.user.name,
      projectName: state.nearestProject?.name ?? '未关联项目',
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
    );
  } catch (e) {
    print('添加水印失败: $e');
    return null;
  }
}
```

### 修改 2：更新 `_takePhoto` 和 `_pickFromGallery` 方法

传递当前状态给 `_addWatermarkToPhoto`，避免在方法内部重新读取状态。

### 修改 3：添加超时保护

为水印处理添加超时限制，防止无限等待。
