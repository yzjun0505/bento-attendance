import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../api/dio_client.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../blocs/progress/progress_bloc.dart';
import '../../models/user_model.dart';
import '../../repositories/personnel_repository.dart';

const _phases = [
  {'value': 'preparation', 'label': '准备阶段'},
  {'value': 'construction', 'label': '施工阶段'},
  {'value': 'inspection', 'label': '验收阶段'},
  {'value': 'rectification', 'label': '整改阶段'},
  {'value': 'delivery', 'label': '交付阶段'},
];

const _priorities = [
  {'value': 'low', 'label': '低'},
  {'value': 'medium', 'label': '中'},
  {'value': 'high', 'label': '高'},
  {'value': 'urgent', 'label': '紧急'},
];

class CreateNodeScreen extends StatefulWidget {
  final int projectId;
  final String projectName;

  const CreateNodeScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<CreateNodeScreen> createState() => _CreateNodeScreenState();
}

class _CreateNodeScreenState extends State<CreateNodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();

  final _personnelRepo = PersonnelRepository(apiClient: ApiClient());

  String _phase = 'construction';
  String _priority = 'medium';
  int? _assigneeId;
  DateTime? _startDate;
  DateTime? _endDate;

  List<User> _workers = [];
  bool _isLoadingWorkers = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkers() async {
    try {
      final result = await _personnelRepo.getUsers(
        role: 'worker',
        projectId: widget.projectId,
        pageSize: 200,
      );
      if (!mounted) return;
      setState(() {
        _workers = result['list'] as List<User>;
        _isLoadingWorkers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingWorkers = false);
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _startDateController.text = DateFormat('yyyy-MM-dd').format(picked);
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = null;
          _endDateController.clear();
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _endDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final data = <String, dynamic>{
      'title': _titleController.text.trim(),
      'phase': _phase,
      'priority': _priority,
    };

    if (_descController.text.trim().isNotEmpty) {
      data['description'] = _descController.text.trim();
    }
    if (_startDate != null) {
      data['plan_start_date'] = DateFormat('yyyy-MM-dd').format(_startDate!);
    }
    if (_endDate != null) {
      data['plan_end_date'] = DateFormat('yyyy-MM-dd').format(_endDate!);
    }
    if (_assigneeId != null) {
      data['assignee_id'] = _assigneeId;
    }

    context.read<ProgressBloc>().add(CreateTaskNode(
          projectId: widget.projectId,
          data: data,
        ));
  }

  String? _validateEndDate(String? value) {
    if (_startDate != null && _endDate != null) {
      if (_endDate!.isBefore(_startDate!)) {
        return '结束日期不能早于开始日期';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return BlocListener<ProgressBloc, ProgressState>(
      listener: (context, state) {
        if (state is ProgressSubmitSuccess) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: colors.success,
            ),
          );
          Navigator.pop(context, true);
        }
        if (state is TaskNodesLoaded) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('任务节点创建成功'),
              backgroundColor: colors.success,
            ),
          );
          Navigator.pop(context, true);
        }
        if (state is ProgressError) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: colors.error,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: const Text('创建任务节点'),
          backgroundColor: colors.surface,
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
                _buildProjectField(colors),
                const SizedBox(height: BentoSpacing.space16),
                _buildPhaseDropdown(colors),
                const SizedBox(height: BentoSpacing.space16),
                _buildTitleField(colors),
                const SizedBox(height: BentoSpacing.space16),
                _buildDateFields(colors),
                const SizedBox(height: BentoSpacing.space16),
                _buildAssigneeDropdown(colors),
                const SizedBox(height: BentoSpacing.space16),
                _buildPriorityDropdown(colors),
                const SizedBox(height: BentoSpacing.space16),
                _buildDescriptionField(colors),
                const SizedBox(height: BentoSpacing.space32),
                _buildSubmitButton(colors),
                SizedBox(
                    height: MediaQuery.of(context).padding.bottom +
                        BentoSpacing.space16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectField(BentoColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '所属项目',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.textSecondary,
              ),
        ),
        const SizedBox(height: BentoSpacing.space8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: BorderRadius.circular(BentoRadius.sm),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            widget.projectName,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.textPrimary,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseDropdown(BentoColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '阶段 *',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.textSecondary,
              ),
        ),
        const SizedBox(height: BentoSpacing.space8),
        DropdownButtonFormField<String>(
          initialValue: _phase,
          decoration: _inputDecoration(colors),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colors.textPrimary,
              ),
          dropdownColor: colors.surface,
          icon: Icon(Icons.expand_more, color: colors.textTertiary),
          items: _phases.map((phase) {
            return DropdownMenuItem<String>(
              value: phase['value'],
              child: Text(phase['label']!),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _phase = value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildTitleField(BentoColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '节点名称 *',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.textSecondary,
              ),
        ),
        const SizedBox(height: BentoSpacing.space8),
        TextFormField(
          controller: _titleController,
          decoration: _inputDecoration(colors).copyWith(
            hintText: '请输入任务节点标题',
          ),
          style: TextStyle(color: colors.textPrimary),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '节点名称不能为空';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDateFields(BentoColors colors) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '计划开始日期',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.textSecondary,
                    ),
              ),
              const SizedBox(height: BentoSpacing.space8),
              TextFormField(
                controller: _startDateController,
                readOnly: true,
                decoration: _inputDecoration(colors).copyWith(
                  hintText: '选择日期',
                  suffixIcon: Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: colors.textTertiary,
                  ),
                ),
                style: TextStyle(color: colors.textPrimary),
                onTap: _selectStartDate,
              ),
            ],
          ),
        ),
        const SizedBox(width: BentoSpacing.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '计划结束日期',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.textSecondary,
                    ),
              ),
              const SizedBox(height: BentoSpacing.space8),
              TextFormField(
                controller: _endDateController,
                readOnly: true,
                decoration: _inputDecoration(colors).copyWith(
                  hintText: '选择日期',
                  suffixIcon: Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: colors.textTertiary,
                  ),
                ),
                style: TextStyle(color: colors.textPrimary),
                validator: _validateEndDate,
                onTap: _selectEndDate,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAssigneeDropdown(BentoColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '负责人',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.textSecondary,
              ),
        ),
        const SizedBox(height: BentoSpacing.space8),
        DropdownButtonFormField<int?>(
          initialValue: _assigneeId,
          decoration: _inputDecoration(colors),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colors.textPrimary,
              ),
          dropdownColor: colors.surface,
          icon: _isLoadingWorkers
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.textTertiary,
                  ),
                )
              : Icon(Icons.expand_more, color: colors.textTertiary),
          hint: Text(
            _isLoadingWorkers ? '加载中...' : '请选择负责人（可选）',
            style: TextStyle(color: colors.textTertiary),
          ),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(
                '不指定',
                style: TextStyle(color: colors.textTertiary),
              ),
            ),
            ..._workers.map((user) {
              return DropdownMenuItem<int?>(
                value: user.id,
                child: Text(user.name),
              );
            }),
          ],
          onChanged: _isLoadingWorkers
              ? null
              : (value) {
                  setState(() => _assigneeId = value);
                },
        ),
      ],
    );
  }

  Widget _buildPriorityDropdown(BentoColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '优先级 *',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.textSecondary,
              ),
        ),
        const SizedBox(height: BentoSpacing.space8),
        DropdownButtonFormField<String>(
          initialValue: _priority,
          decoration: _inputDecoration(colors),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colors.textPrimary,
              ),
          dropdownColor: colors.surface,
          icon: Icon(Icons.expand_more, color: colors.textTertiary),
          items: _priorities.map((p) {
            return DropdownMenuItem<String>(
              value: p['value'],
              child: Text(p['label']!),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _priority = value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildDescriptionField(BentoColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '描述',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.textSecondary,
              ),
        ),
        const SizedBox(height: BentoSpacing.space8),
        TextFormField(
          controller: _descController,
          decoration: _inputDecoration(colors).copyWith(
            hintText: '请输入任务描述（可选）',
          ),
          style: TextStyle(color: colors.textPrimary),
          maxLines: 4,
          minLines: 3,
        ),
      ],
    );
  }

  Widget _buildSubmitButton(BentoColors colors) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.textOnPrimary,
          disabledBackgroundColor: colors.primary.withValues(alpha: 0.5),
          disabledForegroundColor: colors.textOnPrimary.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BentoRadius.sm),
          ),
          elevation: 0,
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
                '创建任务节点',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.textOnPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
      ),
    );
  }

  InputDecoration _inputDecoration(BentoColors colors) {
    return InputDecoration(
      filled: true,
      fillColor: colors.surfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BentoRadius.sm),
        borderSide: BorderSide(color: colors.error, width: 1.5),
      ),
    );
  }
}
