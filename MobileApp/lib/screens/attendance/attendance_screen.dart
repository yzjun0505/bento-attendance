import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/attendance/attendance_bloc.dart';
import '../../blocs/attendance/attendance_event.dart';
import '../../blocs/attendance/attendance_state.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../utils/watermark_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  File? _photoFile;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text("外勤打卡"),
        backgroundColor: colors.background,
      ),
      body: BlocConsumer<AttendanceBloc, AttendanceState>(
        listener: (context, state) {
          if (state is CheckinSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.isOutside ? "已在围栏外打卡" : "打卡成功"),
                backgroundColor: state.isOutside ? Colors.orange : Colors.green,
              ),
            );
            setState(() {
              _photoFile = null;
            });
          } else if (state is AttendanceError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          return _buildContent(context, state, colors);
        },
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, AttendanceState state, BentoColors colors) {
    if (state is CheckinSubmissionInProgress && _photoFile == null) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    if (state is AttendanceError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colors.error),
            const SizedBox(height: 16),
            Text(state.message,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textPrimary)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () =>
                  context.read<AttendanceBloc>().add(LoadAttendanceData()),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (state is AttendanceLoading || state is AttendanceInitial) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    if (state is! AttendanceLoaded) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    final loadedState = state;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLocationInfo(loadedState, colors),
          const SizedBox(height: 24),
          _buildProjectInfo(loadedState, colors),
          const SizedBox(height: 24),
          _buildPhotoSection(colors, loadedState),
          const SizedBox(height: 32),
          _buildCheckButtons(context, loadedState, colors),
        ],
      ),
    );
  }

  Widget _buildPhotoSection(BentoColors colors, AttendanceLoaded state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BentoRadius.md),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '打卡照片',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_photoFile != null)
                TextButton.icon(
                  onPressed: () => setState(() => _photoFile = null),
                  icon: Icon(Icons.refresh, color: colors.primary),
                  label: Text('重拍', style: TextStyle(color: colors.primary)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_photoFile == null)
            _isProcessing
                ? Center(
                    child: CircularProgressIndicator(color: colors.primary))
                : _buildPhotoButtons(colors, state)
          else
            _buildPhotoPreview(colors),
        ],
      ),
    );
  }

  Widget _buildPhotoButtons(BentoColors colors, AttendanceLoaded state) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _takePhoto(state),
        icon: const Icon(Icons.camera_alt),
        label: const Text('拍照打卡'),
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BentoRadius.md),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPreview(BentoColors colors) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BentoRadius.md),
        border: Border.all(color: colors.primary, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BentoRadius.md),
        child: Image.file(
          _photoFile!,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Future<void> _takePhoto(AttendanceLoaded state) async {
    try {
      setState(() => _isProcessing = true);

      final photoFile = await WatermarkService.capturePhoto();
      if (photoFile == null) {
        setState(() => _isProcessing = false);
        return;
      }

      final watermarkedFile = await _addWatermarkToPhoto(photoFile, state);
      if (watermarkedFile != null) {
        setState(() {
          _photoFile = watermarkedFile;
          _isProcessing = false;
        });
      } else {
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('添加水印失败，请重试'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败：$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<File?> _addWatermarkToPhoto(
      File photoFile, AttendanceLoaded state) async {
    try {
      final authState = context.read<AuthBloc>().state;

      if (authState is! AuthAuthenticated) {
        return null;
      }

      final latitude = state.currentLatitude ?? 0.0;
      final longitude = state.currentLongitude ?? 0.0;

      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final rand = DateTime.now().millisecondsSinceEpoch;
      final code =
          List.generate(16, (i) => chars[(rand + i * 7) % chars.length]).join();

      return await WatermarkService.addWatermark(
        imageFile: photoFile,
        userName: authState.user.name,
        projectName: state.nearestProject?.name ?? '未关联项目',
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
        watermarkCode: code,
        address: state.currentAddress,
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception('水印处理超时');
      });
    } catch (e) {
      debugPrint('添加水印失败: $e');
      return null;
    }
  }

  Widget _buildLocationInfo(AttendanceLoaded state, BentoColors colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BentoRadius.md),
      ),
      child: Column(
        children: [
          Icon(Icons.location_on, color: colors.primary, size: 48),
          const SizedBox(height: 12),
          Text(
            '当前位置',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          if (state.currentLatitude != null && state.currentLongitude != null)
            Text(
              '${state.currentLatitude!.toStringAsFixed(6)}, ${state.currentLongitude!.toStringAsFixed(6)}',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            Text(
              '正在获取位置...',
              style: TextStyle(color: colors.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _buildProjectInfo(AttendanceLoaded state, BentoColors colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BentoRadius.md),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.business, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  state.nearestProject?.name ?? "未发现邻近工地",
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '距离围栏中心',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(state.distanceToNearest ?? 0).toStringAsFixed(1)} 米',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '打卡状态',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: state.isInsideGeofence
                          ? colors.success.withValues(alpha: 0.2)
                          : colors.error.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      state.isInsideGeofence ? "已进入范围" : "未进入范围",
                      style: TextStyle(
                        color: state.isInsideGeofence
                            ? colors.success
                            : colors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckButtons(
      BuildContext context, AttendanceLoaded state, BentoColors colors) {
    return Column(
      children: [
        if (_photoFile == null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.warningLight.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(BentoRadius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: colors.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '请先拍照后再进行打卡',
                    style: TextStyle(color: colors.warning, fontSize: 14),
                  ),
                ),
              ],
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: _buildCheckButton(context, "上班打卡", "in", colors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child:
                    _buildCheckButton(context, "下班打卡", "out", colors.success),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildCheckButton(
      BuildContext context, String label, String type, Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
        borderRadius: BorderRadius.circular(BentoRadius.md),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (_photoFile != null) {
              context.read<AttendanceBloc>().add(SubmitCheckin(
                    type: type,
                    photoPath: _photoFile!.path,
                  ));
            }
          },
          borderRadius: BorderRadius.circular(BentoRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
