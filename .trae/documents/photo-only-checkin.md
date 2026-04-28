# 仅允许拍照打卡

## 需求

移除相册选择照片功能，只允许用户通过拍照进行打卡。

## 修改内容

### 文件：`lib/screens/attendance/attendance_screen.dart`

#### 1. 修改 `_buildPhotoButtons` 方法

将原来的两个按钮（拍照 + 相册）改为只有一个拍照按钮：

**修改前：**
```dart
Widget _buildPhotoButtons(bool isDarkMode, AttendanceLoaded state) {
  return Row(
    children: [
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () => _takePhoto(state),
          icon: const Icon(Icons.camera_alt),
          label: const Text('拍照'),
          // ...
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () => _pickFromGallery(state),
          icon: const Icon(Icons.photo_library),
          label: const Text('相册'),
          // ...
        ),
      ),
    ],
  );
}
```

**修改后：**
```dart
Widget _buildPhotoButtons(bool isDarkMode, AttendanceLoaded state) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: () => _takePhoto(state),
      icon: const Icon(Icons.camera_alt),
      label: const Text('拍照打卡'),
      style: ElevatedButton.styleFrom(
        backgroundColor: BentoTheme.accentBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  );
}
```

#### 2. 删除 `_pickFromGallery` 方法

移除不再需要的 `_pickFromGallery` 方法。

#### 3. 可选：删除 `watermark_service.dart` 中的 `pickFromGallery` 方法

如果其他地方不使用，可以一并移除。
