import 'package:flutter/material.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../repositories/approval_repository.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CreateApprovalScreen extends StatefulWidget {
  const CreateApprovalScreen({super.key});

  @override
  State<CreateApprovalScreen> createState() => _CreateApprovalScreenState();
}

class _CreateApprovalScreenState extends State<CreateApprovalScreen> {
  final _approvalRepo = ApprovalRepository();
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  String _approvalType = '补卡';
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isSubmitting = false;

  final List<String> _approvalTypes = ['补卡', '请假', '加班'];

  @override
  void initState() {
    super.initState();
    // 支持从路由参数预选类型（如从工作台请假入口进入）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['type'] != null) {
        setState(() => _approvalType = args['type'] as String);
      }
    });
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate,
      firstDate: _startDate,
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写申请原因')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authState = context.read<AuthBloc>().state;
      String? token;
      if (authState is AuthAuthenticated) {
        token = authState.token;
      }

      await _approvalRepo.createApproval(
        type: _approvalType,
        reason: _reasonController.text.trim(),
        startDate: _startDate.toIso8601String().split('T')[0],
        endDate: _endDate?.toIso8601String().split('T')[0],
        token: token,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('申请已提交')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交失败: ${e.toString()}')),
        );
      }
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
        title: const Text('提交申请'),
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTypeSelector(colors),
              const SizedBox(height: 20),
              _buildDateSelector(colors),
              const SizedBox(height: 20),
              _buildReasonInput(colors),
              const SizedBox(height: 32),
              _buildSubmitButton(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector(BentoColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '申请类型',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: _approvalTypes.map((type) {
            final isSelected = _approvalType == type;
            Color color;
            switch (type) {
              case '补卡':
                color = colors.primary;
                break;
              case '请假':
                color = colors.success;
                break;
              case '加班':
                color = colors.warning;
                break;
              default:
                color = colors.textSecondary;
            }

            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _approvalType = type),
                child: Container(
                  margin: EdgeInsets.only(right: type == '加班' ? 0 : 12),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.15)
                        : colors.surface,
                    borderRadius: BorderRadius.circular(BentoRadius.md),
                    border: Border.all(
                      color: isSelected ? color : colors.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      type,
                      style: TextStyle(
                        color: isSelected ? color : colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDateSelector(BentoColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '日期选择',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _selectStartDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(BentoRadius.md),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 20, color: colors.primary),
                      const SizedBox(width: 12),
                      Text(
                        '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_approvalType != '补卡') ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('至', style: TextStyle(color: colors.textSecondary)),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _selectEndDate,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(BentoRadius.md),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 20, color: colors.success),
                        const SizedBox(width: 12),
                        Text(
                          _endDate != null
                              ? '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}'
                              : '结束日期',
                          style: TextStyle(
                            color: _endDate != null
                                ? colors.textPrimary
                                : colors.textTertiary,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildReasonInput(BentoColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '申请原因',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              ' *',
              style: TextStyle(color: colors.error),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(BentoRadius.md),
            border: Border.all(color: colors.border),
          ),
          child: TextField(
            controller: _reasonController,
            maxLines: 5,
            maxLength: 500,
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: '请详细描述申请原因',
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
        onPressed: _isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BentoRadius.md),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                '提交申请',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
