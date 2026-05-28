import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../api/dio_client.dart';
import '../../repositories/checkin_repository.dart';
import '../../repositories/project_repository.dart';

class CheckinConfirmScreen extends StatefulWidget {
  final String photoPath;
  final Map<String, dynamic>? watermarkData;
  final Map<String, dynamic>? location;
  final Map<String, dynamic>? project;

  const CheckinConfirmScreen({
    super.key,
    required this.photoPath,
    this.watermarkData,
    this.location,
    this.project,
  });

  @override
  State<CheckinConfirmScreen> createState() => _CheckinConfirmScreenState();
}

class _CheckinConfirmScreenState extends State<CheckinConfirmScreen> {
  late final CheckinRepository _checkinRepo;
  late final ProjectRepository _projectRepo;
  final _workLogController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<dynamic> _projects = [];
  int? _selectedProjectId;
  String _checkinType = 'clock_in';
  bool _isSubmitting = false;
  bool _isLoading = true;

  final List<Map<String, dynamic>> _checkinTypes = [
    {'value': 'clock_in', 'label': '上班打卡', 'icon': Icons.login, 'color': null},
    {
      'value': 'clock_out',
      'label': '下班打卡',
      'icon': Icons.logout,
      'color': null
    },
    {
      'value': 'field_visit',
      'label': '实地考察',
      'icon': Icons.explore,
      'color': null
    },
    {
      'value': 'progress_report',
      'label': '项目进度上报',
      'icon': Icons.trending_up,
      'color': null
    },
    {
      'value': 'safety_check',
      'label': '安全检查',
      'icon': Icons.verified_user,
      'color': null
    },
    {
      'value': 'location_report',
      'label': '位置上报',
      'icon': Icons.location_on,
      'color': null
    },
  ];

  @override
  void initState() {
    super.initState();
    _checkinRepo = CheckinRepository(apiClient: ApiClient());
    _projectRepo = ProjectRepository(apiClient: ApiClient());
    _selectedProjectId = widget.project?['id'];
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    try {
      final projects = await _projectRepo.getAllProjects();
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _workLogController.dispose();
    super.dispose();
  }

  Future<void> _submitCheckin() async {
    if (_workLogController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写施工日志/备注说明')),
      );
      return;
    }

    if (_selectedProjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择项目')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _checkinRepo.submitCheckin(
        type: _checkinType,
        latitude: widget.location?['latitude'] ?? 0.0,
        longitude: widget.location?['longitude'] ?? 0.0,
        address: widget.location?['address'] ?? '',
        projectId: _selectedProjectId,
        remark: _workLogController.text.trim(),
        photo: widget.photoPath,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('打卡成功！')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打卡失败: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('确认打卡'),
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPhotoPreview(colors),
                    const SizedBox(height: 24),
                    _buildProjectSelector(colors),
                    const SizedBox(height: 16),
                    _buildTypeSelector(colors),
                    const SizedBox(height: 16),
                    _buildWorkLogInput(colors),
                    const SizedBox(height: 32),
                    _buildSubmitButton(colors),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPhotoPreview(BentoColors colors) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BentoRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BentoRadius.md),
        child: Image.file(
          File(widget.photoPath),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildProjectSelector(BentoColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择项目 *',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(BentoRadius.md),
            border: Border.all(color: colors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              value: _selectedProjectId,
              hint: Text('请选择项目', style: TextStyle(color: colors.textTertiary)),
              dropdownColor: colors.surface,
              style: TextStyle(color: colors.textPrimary),
              items: _projects.map((p) {
                final id =
                    p is Map<String, dynamic> ? p['id'] : (p as dynamic)?.id;
                final name = p is Map<String, dynamic>
                    ? p['name']
                    : (p as dynamic)?.name;
                return DropdownMenuItem<int>(
                  value: id as int?,
                  child: Text(name ?? ''),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedProjectId = value);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSelector(BentoColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '打卡类型 *',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: _checkinTypes.map((type) {
            final isSelected = _checkinType == type['value'];
            return GestureDetector(
              onTap: () =>
                  setState(() => _checkinType = type['value'] as String),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.primary.withValues(alpha: 0.15)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(BentoRadius.sm),
                  border: Border.all(
                    color: isSelected ? colors.primary : colors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      type['icon'] as IconData,
                      size: 16,
                      color: isSelected ? colors.primary : colors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      type['label'] as String,
                      style: TextStyle(
                        color:
                            isSelected ? colors.primary : colors.textSecondary,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildWorkLogInput(BentoColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '施工日志/备注说明',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(' *', style: TextStyle(color: colors.error)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(BentoRadius.md),
            border: Border.all(color: colors.border),
          ),
          child: TextField(
            controller: _workLogController,
            maxLines: 5,
            maxLength: 500,
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: '请描述今日工作内容，如：一期地基浇筑完成',
              hintStyle: TextStyle(color: colors.textTertiary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              counterStyle: TextStyle(color: colors.textTertiary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(BentoColors colors) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitCheckin,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BentoRadius.md)),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              )
            : const Text('确认提交',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
