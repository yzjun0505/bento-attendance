# 修复水印位置和拖拽功能

## 问题分析

### 问题1：水印位置默认在左上角

当前默认值（第51行）：
```dart
Offset _normalizedOffset = const Offset(0.05, 0.65);
```

虽然 dy=0.65 理论上应该在偏下位置，但由于以下原因导致实际显示偏上：
- `_buildCameraPreview()` 使用了 `Transform.scale` 可能影响布局
- 底部控制栏占用约140px空间
- 需要调整默认位置到真正的左下角

### 问题2：拖拽水印功能不工作

当前拖拽实现（第511-520行）使用了 `GestureDetector` + `onPanUpdate`，但可能存在以下问题：
- `LayoutBuilder` 的 constraints 可能不准确
- 拖拽范围限制过严（clamp 0.0-0.8 和 0.05-0.85）
- 手势被其他组件拦截

## 修复方案

### 步骤1：修改默认水印位置

将默认位置改为真正的左下角：
```dart
// 修改前
Offset _normalizedOffset = const Offset(0.05, 0.65);

// 修改后 - 左下角位置（考虑底部工具栏）
Offset _normalizedOffset = const Offset(0.05, 0.55);
```

### 步骤2：修复拖拽功能

1. 改用 `GestureDetector` 的 `onPanStart` + `onPanUpdate`
2. 确保 `LayoutBuilder` 获取正确的约束
3. 调整拖拽边界范围
4. 添加视觉反馈（拖拽时高亮边框）

### 步骤3：优化布局计算

确保水印位置基于可视区域（排除顶部状态栏和底部工具栏）计算

## 文件修改清单

- `lib/screens/attendance/camera_checkin_screen.dart`
  - 修改默认 `_normalizedOffset` 值
  - 修复 `_buildDraggableWatermarkOverlay` 拖拽逻辑
  - 优化位置计算
