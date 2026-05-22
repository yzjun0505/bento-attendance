import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../blocs/progress/progress_bloc.dart';
import '../../models/task_node_model.dart';
import '../../repositories/progress_repository.dart';

class SubmitProgressScreen extends StatefulWidget {
  final TaskNode node;

  const SubmitProgressScreen({super.key, required this.node});

  @override
  State<SubmitProgressScreen> createState() => _SubmitProgressScreenState();
}

class _SubmitProgressScreenState extends State<SubmitProgressScreen> {
  final _descController = TextEditingController();
  final _riskController = TextEditingController();
  final _blockerController = TextEditingController();
  final _progressRepository = ProgressRepository();
  double _progressPercent = 50;
  final List<File> _photos = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _progressPercent = widget.node.progressPercent.toDouble();
  }

  @override
  void dispose() {
    _descController.dispose();
    _riskController.dispose();
    _blockerController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      setState(() {
        _photos.add(File(pickedFile.path));
      });
    }
  }

  Future<void> _submit() async {
    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写进度描述')),
      );
      return;
    }

    if (widget.node.isOverdue && _riskController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前任务已逾期，请填写风险说明')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      List<String>? photoUrls;
      if (_photos.isNotEmpty) {
        photoUrls = await _progressRepository.uploadPhotos(_photos);
      }

      if (!mounted) return;

      context.read<ProgressBloc>().add(SubmitProgressReport(
            nodeId: widget.node.id,
            description: _descController.text.trim(),
            photo: photoUrls?.isNotEmpty == true ? photoUrls!.first : null,
            progressPercent: _progressPercent.round(),
            riskNote: _riskController.text.trim().isEmpty
                ? null
                : _riskController.text.trim(),
            blockerNote: _blockerController.text.trim().isEmpty
                ? null
                : _blockerController.text.trim(),
            photos: photoUrls,
          ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showPhotoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('拍照'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('从相册选择'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return BlocListener<ProgressBloc, ProgressState>(
      listener: (context, state) {
        if (state is ProgressSubmitSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('进度上报成功')),
          );
          Navigator.pop(context, true);
        } else if (state is ProgressError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: const Text('进度上报'),
          backgroundColor: colors.surface,
          foregroundColor: colors.textPrimary,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(BentoSpacing.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.node.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: colors.textPrimary,
                    ),
              ),
              const SizedBox(height: BentoSpacing.space4),
              Text(
                '当前进度: ${widget.node.progressPercent}%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
              ),
              const SizedBox(height: BentoSpacing.space24),
              if (widget.node.isOverdue)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.orange.shade50,
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '当前进度可能延期，计划完成日期已过，请关注',
                          style: TextStyle(color: Colors.orange.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.node.isOverdue)
                const SizedBox(height: BentoSpacing.space24),
              Text(
                '进度描述',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: BentoSpacing.space8),
              TextField(
                controller: _descController,
                maxLines: 4,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: '请描述当前进度情况...',
                  hintStyle: TextStyle(color: colors.textTertiary),
                  filled: true,
                  fillColor: colors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(BentoRadius.md),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(BentoSpacing.space16),
                ),
              ),
              const SizedBox(height: BentoSpacing.space24),
              Text(
                '进度百分比',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: BentoSpacing.space8),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _progressPercent,
                      min: 0,
                      max: 100,
                      divisions: 100,
                      activeColor: colors.primary,
                      inactiveColor: colors.surfaceVariant,
                      label: '${_progressPercent.round()}%',
                      onChanged: (value) {
                        setState(() => _progressPercent = value);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${_progressPercent.round()}%',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BentoSpacing.space24),
              Text(
                '风险说明${widget.node.isOverdue ? "（必填）" : "（可选）"}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: BentoSpacing.space8),
              TextFormField(
                controller: _riskController,
                maxLines: 2,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: '是否有风险？如材料延迟、天气影响等',
                  hintStyle: TextStyle(color: colors.textTertiary),
                  filled: true,
                  fillColor: colors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(BentoRadius.md),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(BentoSpacing.space16),
                ),
              ),
              const SizedBox(height: BentoSpacing.space24),
              Text(
                '阻塞项（可选）',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: BentoSpacing.space8),
              TextFormField(
                controller: _blockerController,
                maxLines: 2,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: '是否有阻塞项？需要哪些支持...',
                  hintStyle: TextStyle(color: colors.textTertiary),
                  filled: true,
                  fillColor: colors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(BentoRadius.md),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(BentoSpacing.space16),
                ),
              ),
              const SizedBox(height: BentoSpacing.space24),
              Text(
                '现场照片（可选）',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: BentoSpacing.space8),
              if (_photos.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (int i = 0; i < _photos.length; i++)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(BentoRadius.md),
                            child: Image.file(
                              _photos[i],
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => setState(() => _photos.removeAt(i)),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    GestureDetector(
                      onTap: _showPhotoSheet,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(BentoRadius.md),
                          border: Border.all(
                            color: colors.border,
                          ),
                        ),
                        child: Center(
                          child: Icon(Icons.add,
                              size: 28, color: colors.textTertiary),
                        ),
                      ),
                    ),
                  ],
                )
              else
                GestureDetector(
                  onTap: _showPhotoSheet,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(BentoRadius.md),
                      border: Border.all(
                        color: colors.border,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo,
                              size: 32, color: colors.textTertiary),
                          const SizedBox(height: 4),
                          Text(
                            '点击拍照或选择图片',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: colors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: BentoSpacing.space32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.textOnPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(BentoRadius.md),
                    ),
                    disabledBackgroundColor: colors.textTertiary,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('提交上报', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
