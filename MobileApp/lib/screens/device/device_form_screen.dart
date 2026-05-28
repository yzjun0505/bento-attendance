import 'package:flutter/material.dart';
import '../../api/dio_client.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../models/device_model.dart';
import '../../models/project_model.dart';
import '../../repositories/device_repository.dart';
import '../../repositories/project_repository.dart';

class DeviceFormScreen extends StatefulWidget {
  final Device? device;

  const DeviceFormScreen({super.key, this.device});

  @override
  State<DeviceFormScreen> createState() => _DeviceFormScreenState();
}

class _DeviceFormScreenState extends State<DeviceFormScreen> {
  final _apiClient = ApiClient();
  late final DeviceRepository _deviceRepo;
  late final ProjectRepository _projectRepo;
  final _formKey = GlobalKey<FormState>();

  final _deviceIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  String _type = 'checkpoint';
  int? _projectId;
  bool _isActive = true;
  bool _isSubmitting = false;
  List<Project> _projects = [];
  bool _projectsLoading = true;

  bool get isEditing => widget.device != null;

  static const _typeOptions = [
    {'value': 'checkpoint', 'label': '打卡点'},
    {'value': 'sensor', 'label': '传感器'},
    {'value': 'camera', 'label': '摄像头'},
    {'value': 'other', 'label': '其他'},
  ];

  @override
  void initState() {
    super.initState();
    _deviceRepo = DeviceRepository(apiClient: _apiClient);
    _projectRepo = ProjectRepository(apiClient: _apiClient);
    _loadProjects();

    if (widget.device != null) {
      final d = widget.device!;
      _deviceIdController.text = d.deviceId;
      _nameController.text = d.name;
      _type = d.type;
      _projectId = d.projectId;
      _isActive = d.isActive;
      _latitudeController.text = d.latitude?.toString() ?? '';
      _longitudeController.text = d.longitude?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    _nameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    try {
      final projects = await _projectRepo.getAllProjects();
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _projectsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _projectsLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final deviceId = _deviceIdController.text.trim();
      final name = _nameController.text.trim();
      final latitude = double.tryParse(_latitudeController.text.trim());
      final longitude = double.tryParse(_longitudeController.text.trim());

      if (isEditing) {
        await _deviceRepo.updateDevice(
          widget.device!.id,
          deviceId: deviceId,
          name: name,
          type: _type,
          projectId: _projectId,
          status: _isActive ? 1 : 0,
          latitude: latitude,
          longitude: longitude,
        );
      } else {
        await _deviceRepo.createDevice(
          deviceId: deviceId,
          name: name,
          type: _type,
          projectId: _projectId,
          status: _isActive ? 1 : 0,
          latitude: latitude,
          longitude: longitude,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEditing ? '设备更新成功' : '设备创建成功')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(isEditing ? '编辑设备' : '添加设备'),
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(BentoSpacing.space20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionLabel('基本信息', colors),
              const SizedBox(height: BentoSpacing.space16),
              _buildTextField(
                controller: _deviceIdController,
                label: '设备ID',
                hint: '请输入设备编号',
                required: true,
                colors: colors,
                prefixIcon: Icons.tag,
              ),
              const SizedBox(height: BentoSpacing.space16),
              _buildTextField(
                controller: _nameController,
                label: '设备名称',
                hint: '请输入设备名称',
                required: true,
                colors: colors,
                prefixIcon: Icons.devices,
              ),
              const SizedBox(height: BentoSpacing.space16),
              _buildTypeDropdown(colors),
              const SizedBox(height: BentoSpacing.space16),
              _buildProjectDropdown(colors),
              const SizedBox(height: BentoSpacing.space24),
              _buildSectionLabel('其他信息', colors),
              const SizedBox(height: BentoSpacing.space16),
              _buildStatusSwitch(colors),
              const SizedBox(height: BentoSpacing.space16),
              _buildTextField(
                controller: _longitudeController,
                label: '经度',
                hint: '请输入经度（可选）',
                colors: colors,
                prefixIcon: Icons.language,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: BentoSpacing.space16),
              _buildTextField(
                controller: _latitudeController,
                label: '纬度',
                hint: '请输入纬度（可选）',
                colors: colors,
                prefixIcon: Icons.language,
                keyboardType: TextInputType.number,
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
                      borderRadius: BorderRadius.circular(BentoRadius.sm),
                    ),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.textOnPrimary,
                          ),
                        )
                      : Text(
                          isEditing ? '保存修改' : '创建设备',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: BentoSpacing.space32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String title, BentoColors colors) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required BentoColors colors,
    bool required = false,
    IconData? prefixIcon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
            if (required)
              Text(
                ' *',
                style: TextStyle(color: colors.error, fontSize: 14),
              ),
          ],
        ),
        const SizedBox(height: BentoSpacing.space8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(color: colors.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: colors.textTertiary),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 20, color: colors.textTertiary)
                : null,
            filled: true,
            fillColor: colors.surfaceVariant,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BentoRadius.sm),
              borderSide: BorderSide(color: colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BentoRadius.sm),
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BentoRadius.sm),
              borderSide: BorderSide(color: colors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BentoRadius.sm),
              borderSide: BorderSide(color: colors.error),
            ),
          ),
          validator: required
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '$label不能为空';
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildTypeDropdown(BentoColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '设备类型',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: BentoSpacing.space8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: BorderRadius.circular(BentoRadius.sm),
            border: Border.all(color: colors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _type,
              isExpanded: true,
              icon:
                  Icon(Icons.keyboard_arrow_down, color: colors.textSecondary),
              style: TextStyle(color: colors.textPrimary, fontSize: 15),
              dropdownColor: colors.surface,
              items: _typeOptions.map((option) {
                return DropdownMenuItem<String>(
                  value: option['value'] as String,
                  child: Text(option['label'] as String),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _type = value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectDropdown(BentoColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '所属项目',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: BentoSpacing.space8),
        _projectsLoading
            ? Container(
                height: 48,
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(BentoRadius.sm),
                ),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.textTertiary,
                    ),
                  ),
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(BentoRadius.sm),
                  border: Border.all(color: colors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _projectId,
                    isExpanded: true,
                    icon: Icon(Icons.keyboard_arrow_down,
                        color: colors.textSecondary),
                    style: TextStyle(color: colors.textPrimary, fontSize: 15),
                    dropdownColor: colors.surface,
                    hint: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '请选择项目（可选）',
                        style: TextStyle(color: colors.textTertiary),
                      ),
                    ),
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text('无',
                            style: TextStyle(color: colors.textTertiary)),
                      ),
                      ..._projects.map((project) {
                        return DropdownMenuItem<int?>(
                          value: project.id,
                          child: Text(project.name),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => _projectId = value);
                    },
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildStatusSwitch(BentoColors colors) {
    return Container(
      padding: const EdgeInsets.all(BentoSpacing.space16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BentoRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(
            _isActive ? Icons.check_circle : Icons.pause_circle,
            color: _isActive ? colors.success : colors.textTertiary,
            size: 20,
          ),
          const SizedBox(width: BentoSpacing.space12),
          Expanded(
            child: Text(
              '设备状态',
              style: TextStyle(
                fontSize: 15,
                color: colors.textPrimary,
              ),
            ),
          ),
          Text(
            _isActive ? '正常' : '停用',
            style: TextStyle(
              fontSize: 14,
              color: _isActive ? colors.success : colors.textSecondary,
            ),
          ),
          const SizedBox(width: BentoSpacing.space8),
          Switch(
            value: _isActive,
            onChanged: (value) => setState(() => _isActive = value),
            activeThumbColor: colors.success,
            inactiveTrackColor: colors.surfaceVariant,
            inactiveThumbColor: colors.textTertiary,
          ),
        ],
      ),
    );
  }
}
