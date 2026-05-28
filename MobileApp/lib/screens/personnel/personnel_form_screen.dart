import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../api/dio_client.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../models/project_model.dart';
import '../../repositories/personnel_repository.dart';
import '../../repositories/project_repository.dart';
import '../../widgets/bento_button.dart';
import '../../widgets/bento_card.dart';
import '../../widgets/bento_input.dart';

class PersonnelFormScreen extends StatefulWidget {
  final dynamic user;

  const PersonnelFormScreen({super.key, this.user});

  bool get isEditing => user != null;

  @override
  State<PersonnelFormScreen> createState() => _PersonnelFormScreenState();
}

class _PersonnelFormScreenState extends State<PersonnelFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _personnelRepo = PersonnelRepository(apiClient: ApiClient());
  final _projectRepo = ProjectRepository(apiClient: ApiClient());

  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _selectedRole;
  int? _selectedProjectId;
  List<Project> _projects = [];
  bool _isLoadingProjects = true;
  bool _isSaving = false;
  bool _obscurePassword = true;

  List<Map<String, String>> get _availableRoles {
    if (_isManager) {
      return const [
        {'value': 'worker', 'label': '工人'},
      ];
    }
    return const [
      {'value': 'admin', 'label': '管理员'},
      {'value': 'manager', 'label': '项目经理'},
      {'value': 'worker', 'label': '工人'},
    ];
  }

  bool get _isManager {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return authState.user.role == 'manager';
    }
    return false;
  }

  int? get _currentUserProjectId {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return authState.user.projectId;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadProjects();

    if (widget.isEditing) {
      final user = widget.user!;
      _usernameController.text = user.username ?? '';
      _nameController.text = user.name ?? '';
      _phoneController.text = user.phone ?? '';
      _selectedRole = user.role;
      _selectedProjectId = user.projectId;
    } else {
      _selectedRole = _isManager ? 'worker' : null;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    try {
      final projects = await _projectRepo.getAllProjects();
      setState(() {
        if (_isManager && _currentUserProjectId != null) {
          _projects =
              projects.where((p) => p.id == _currentUserProjectId).toList();
        } else {
          _projects = projects;
        }
        _isLoadingProjects = false;
      });
    } catch (_) {
      setState(() => _isLoadingProjects = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择角色')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (widget.isEditing) {
        await _personnelRepo.updateUser(
          widget.user!.id,
          name: _nameController.text.trim(),
          role: _selectedRole,
          phone: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
          projectId: _selectedProjectId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('更新成功')),
          );
          Navigator.pop(context, true);
        }
      } else {
        await _personnelRepo.createUser(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
          role: _selectedRole!,
          phone: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
          projectId: _selectedProjectId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('创建成功')),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Color _getRoleColor(String role, BentoColors colors) {
    switch (role) {
      case 'admin':
        return colors.error;
      case 'manager':
        return colors.primary;
      case 'worker':
        return colors.success;
      default:
        return colors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(widget.isEditing ? '编辑人员' : '添加人员'),
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(BentoSpacing.space16),
        child: Form(
          key: _formKey,
          child: BentoCard(
            padding: const EdgeInsets.all(BentoSpacing.space20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BentoInput(
                  label: '用户名',
                  hint: '请输入用户名',
                  controller: _usernameController,
                  enabled: !widget.isEditing,
                  readOnly: widget.isEditing,
                  validator: (value) {
                    if (!widget.isEditing &&
                        (value == null || value.trim().isEmpty)) {
                      return '请输入用户名';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: BentoSpacing.space16),
                BentoInput(
                  label: '姓名',
                  hint: '请输入姓名',
                  controller: _nameController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入姓名';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: BentoSpacing.space16),
                BentoInput(
                  label: '手机号',
                  hint: '请输入手机号（选填）',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: BentoSpacing.space16),
                _buildRoleDropdown(colors),
                const SizedBox(height: BentoSpacing.space16),
                _buildProjectDropdown(colors),
                if (!widget.isEditing) ...[
                  const SizedBox(height: BentoSpacing.space16),
                  BentoInput(
                    label: '密码',
                    hint: '请输入密码',
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 20,
                        color: colors.textTertiary,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    validator: (value) {
                      if (!widget.isEditing &&
                          (value == null || value.isEmpty)) {
                        return '请输入密码';
                      }
                      if (!widget.isEditing && value!.length < 6) {
                        return '密码至少6位';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: BentoSpacing.space24),
                BentoButton.primary(
                  text: widget.isEditing ? '保存修改' : '创建人员',
                  onPressed: _isSaving ? null : _save,
                  loading: _isSaving,
                  fullWidth: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleDropdown(BentoColors colors) {
    final roles = _availableRoles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '角色',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.textSecondary,
              ),
        ),
        const SizedBox(height: BentoSpacing.space8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BentoRadius.sm),
            border: Border.all(color: colors.border),
            color: colors.surfaceVariant,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedRole,
              isExpanded: true,
              dropdownColor: colors.surface,
              icon: Icon(Icons.arrow_drop_down, color: colors.textTertiary),
              style: TextStyle(
                fontSize: 16,
                color: colors.textPrimary,
              ),
              hint: Text(
                '请选择角色',
                style: TextStyle(color: colors.textTertiary),
              ),
              items: roles.map((role) {
                final roleColor = _getRoleColor(role['value']!, colors);
                return DropdownMenuItem<String>(
                  value: role['value'],
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: roleColor,
                        ),
                      ),
                      const SizedBox(width: BentoSpacing.space8),
                      Text(role['label']!),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedRole = value);
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '所属项目',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.textSecondary,
              ),
        ),
        const SizedBox(height: BentoSpacing.space8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BentoRadius.sm),
            border: Border.all(color: colors.border),
            color: colors.surfaceVariant,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _selectedProjectId,
              isExpanded: true,
              dropdownColor: colors.surface,
              icon: _isLoadingProjects
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    )
                  : Icon(Icons.arrow_drop_down, color: colors.textTertiary),
              style: TextStyle(
                fontSize: 16,
                color: colors.textPrimary,
              ),
              hint: Text(
                _isLoadingProjects ? '加载中...' : '请选择项目（可选）',
                style: TextStyle(color: colors.textTertiary),
              ),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(
                    '未分配项目',
                    style: TextStyle(color: colors.textTertiary),
                  ),
                ),
                ..._projects.map((project) {
                  return DropdownMenuItem<int?>(
                    value: project.id,
                    child: Text(project.name),
                  );
                }),
              ],
              onChanged: _isLoadingProjects
                  ? null
                  : (value) {
                      setState(() => _selectedProjectId = value);
                    },
            ),
          ),
        ),
      ],
    );
  }
}
