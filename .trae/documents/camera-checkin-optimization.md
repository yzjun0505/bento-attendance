# 优化水印打卡 - 实时相机预览

## 需求

1. 打开 App 直接进入打卡界面
2. 背景是相机实时预览
3. 实时显示水印信息（员工、项目、时间、位置）
4. 点击拍照直接完成打卡

## 实现方案

### 步骤 1：添加 camera 插件

在 `pubspec.yaml` 中添加：
```yaml
dependencies:
  camera: ^0.11.0
```

### 步骤 2：创建相机打卡界面

新建 `lib/screens/camera_checkin_screen.dart`：
- 初始化相机控制器
- 全屏相机预览作为背景
- 叠加水印信息层（实时更新时间、位置）
- 底部拍照按钮和打卡按钮
- 拍照后显示预览，确认后提交打卡

### 步骤 3：修改导航逻辑

修改 `main_navigation.dart`：
- 将默认页面改为打卡页面（`_currentIndex = 1`）

### 步骤 4：添加相机权限

在 `android/app/src/main/AndroidManifest.xml` 添加：
```xml
<uses-permission android:name="android.permission.CAMERA" />
```

## 详细实现

### 界面布局

```
┌─────────────────────────────┐
│  相机预览（全屏背景）          │
│                             │
│  ┌─────────────────────┐   │
│  │ 水印信息层（半透明）    │   │
│  │ 员工: 张三           │   │
│  │ 项目: XX工地         │   │
│  │ 时间: 2024-01-01     │   │
│  │ 位置: 39.9xxx,116.4xxx│   │
│  └─────────────────────┘   │
│                             │
│        [拍照按钮]            │
│                             │
│     [上班打卡] [下班打卡]     │
└─────────────────────────────┘
```

### 文件修改清单

1. `pubspec.yaml` - 添加 camera 依赖
2. `lib/screens/camera_checkin_screen.dart` - 新建相机打卡界面
3. `lib/screens/main_navigation.dart` - 修改默认页面
4. `lib/screens/attendance/attendance_screen.dart` - 替换为相机界面
5. `android/app/src/main/AndroidManifest.xml` - 添加相机权限

## 注意事项

- 需要处理相机权限请求
- 需要处理相机初始化失败情况
- 水印信息每秒更新时间
- 位置信息使用已有位置或实时获取
