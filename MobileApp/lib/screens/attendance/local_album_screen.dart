import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import '../../utils/local_album_service.dart';
import '../../utils/coord_utils.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../repositories/checkin_repository.dart';

class LocalAlbumScreen extends StatefulWidget {
  const LocalAlbumScreen({super.key});

  @override
  State<LocalAlbumScreen> createState() => _LocalAlbumScreenState();
}

class _LocalAlbumScreenState extends State<LocalAlbumScreen> {
  List<LocalPhotoRecord> _photos = [];
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  /// 将本地保存的打卡类型映射为后端合法的类型 code
  /// 旧类型 in/out 和自定义类型 custom 统一映射
  static String _mapCheckinType(String localType) {
    const typeMap = {
      'in': 'clock_in',
      'out': 'clock_out',
      'clock_in': 'clock_in',
      'clock_out': 'clock_out',
      'site_visit': 'site_visit',
      'progress': 'progress',
      'safety': 'safety',
      'device': 'device',
      'custom': 'custom',
    };
    return typeMap[localType] ?? 'custom';
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    final photos = await LocalAlbumService.getPhotos();
    setState(() {
      _photos = photos;
      _isLoading = false;
    });
  }

  Future<void> _uploadPhoto(LocalPhotoRecord photo) async {
    if (_isUploading) return;
    setState(() => _isUploading = true);
    
    try {
      final repo = context.read<CheckinRepository>();
      
      // Upload raw image file via photo upload api
      final file = File(photo.path);
      if (!file.existsSync()) {
        throw Exception('图片文件已在本地丢失');
      }

      final uploadedUrl = await repo.uploadPhoto(file);
      if (uploadedUrl == null) {
        throw Exception('图片上传失败，请检查网络');
      }

      // Submit checkin payload using the reserved watermark code
      // 打卡类型映射：旧类型 in/out 和 custom 统一映射为合法 code
      final checkinTypeCode = _mapCheckinType(photo.checkinType);
      // 坐标转换：本地保存的可能是 WGS84 原始坐标，需转为 GCJ02 以匹配后端项目坐标
      final gcj = CoordUtils.wgs84ToGcj02(photo.latitude, photo.longitude);
      await repo.submitCheckin(
        type: checkinTypeCode,
        latitude: gcj['latitude']!,
        longitude: gcj['longitude']!,
        address: photo.address,
        projectId: photo.projectId,
        remark: (photo.remark?.isEmpty ?? true) ? photo.customCheckinName : '${photo.customCheckinName}: ${photo.remark}',
        photo: uploadedUrl,
        watermarkCode: photo.watermarkCode,
      );

      // If successful, remove from local cache
      await LocalAlbumService.removePhoto(photo.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('照片上传同步成功！'), backgroundColor: Colors.green),
        );
        _loadPhotos();
      }
    } on DioException catch (e) {
      if (mounted) {
        final errResponse = e.response?.data;
        String errMsg = '网络异常，请稍后再试';
        
        if (errResponse != null && errResponse['message'] != null) {
          errMsg = errResponse['message'];
          // 如果是超期作废或者已经被使用过，可能需要提示用户甚至自动清理
          if (errMsg.contains('已作废') || errMsg.contains('不可重复使用')) {
            await LocalAlbumService.removePhoto(photo.id);
            _loadPhotos();
          }
        }
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('上传失败: $errMsg'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('错误: $e'), backgroundColor: Colors.orange),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _confirmUpload(LocalPhotoRecord photo) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('上传照片', style: TextStyle(color: colors.textPrimary)),
        content: Text('准备将此记录与防伪码同步至后台，请确认网络畅通。', style: TextStyle(color: colors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: colors.textTertiary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _uploadPhoto(photo);
            },
            child: Text('立即上传', style: TextStyle(color: colors.primary)),
          ),
        ],
      )
    );
  }

  void _confirmDelete(LocalPhotoRecord photo) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: const Text('删除照片', style: TextStyle(color: Colors.red)),
        content: Text('确定要永久删除这张带有防伪码的水印照片吗？此操作无法恢复。', style: TextStyle(color: colors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: colors.textTertiary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deletePhoto(photo);
            },
            child: const Text('彻底删除', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      )
    );
  }

  Future<void> _deletePhoto(LocalPhotoRecord photo) async {
    try {
      await LocalAlbumService.removePhoto(photo.id);
      
      // Attempt to physically delete the file as well
      final file = File(photo.path);
      if (file.existsSync()) {
        await file.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除该打卡照片'), backgroundColor: Colors.green),
        );
        _loadPhotos();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: Colors.black, // Dark background for immersive photo view
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('本地水印图库', style: TextStyle(fontSize: 16, color: Colors.white)),
        backgroundColor: Colors.black45,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator(color: colors.primary))
        : _photos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined, size: 64, color: Colors.white.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  Text('暂无待上传的本地照片', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                ],
              ),
            )
          : PageView.builder(
              itemCount: _photos.length,
              itemBuilder: (context, index) {
                final photo = _photos[index];
                return _buildPhotoPage(photo, index, _photos.length, colors);
              },
            ),
    );
  }

  Widget _buildPhotoPage(LocalPhotoRecord photo, int index, int total, BentoColors colors) {
    File imgFile = File(photo.path);
    bool fileExists = imgFile.existsSync();

    return Stack(
      fit: StackFit.expand,
      children: [
        fileExists 
          ? Image.file(imgFile, fit: BoxFit.contain)
          : Container(color: Colors.white10, child: const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 48))),
        
        // 分页指示器
        Positioned(
          top: MediaQuery.of(context).padding.top + 56 + 16,
          right: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
            child: Text('${index + 1} / $total', style: const TextStyle(color: Colors.white, fontSize: 14)),
          )
        ),

        // 底部详情与操作按钮
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 20, left: 24, right: 24, top: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withValues(alpha: 0.9), Colors.transparent],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.warning.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        photo.customCheckinName.isNotEmpty ? photo.customCheckinName : '打卡',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    Text(
                      photo.createdTime,
                      style: const TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          onPressed: () => _confirmDelete(photo),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BentoRadius.md)),
                          ),
                          child: const Icon(Icons.delete_outline, color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isUploading || !fileExists ? null : () => _confirmUpload(photo),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BentoRadius.md)),
                          ),
                          child: _isUploading 
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                            : const Text('上传至后台', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
