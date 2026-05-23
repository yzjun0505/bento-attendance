import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../repositories/approval_repository.dart';
import '../../widgets/bento_loading.dart';

class ApprovalDetailScreen extends StatefulWidget {
  final int approvalId;

  const ApprovalDetailScreen({super.key, required this.approvalId});

  @override
  State<ApprovalDetailScreen> createState() => _ApprovalDetailScreenState();
}

class _ApprovalDetailScreenState extends State<ApprovalDetailScreen> {
  final _approvalRepo = ApprovalRepository();
  Map<String, dynamic>? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() { _loading = true; _error = null; });
    try {
      final detail = await _approvalRepo.getApprovalById(widget.approvalId);
      if (mounted) setState(() { _detail = detail; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('审批详情'),
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const BentoLoading.spinner()
          : _error != null
              ? _buildError(colors, theme)
              : _detail == null
                  ? const Center(child: Text('暂无数据'))
                  : _buildContent(colors, theme),
    );
  }

  Widget _buildError(BentoColors colors, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: colors.error),
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: colors.error)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadDetail, child: const Text('重试')),
        ],
      ),
    );
  }

  Widget _buildContent(BentoColors colors, ThemeData theme) {
    final d = _detail!;
    final type = d['type'] ?? '';
    final status = d['status'] ?? 'pending';
    final reason = d['reason'] ?? '';
    final remark = d['remark'] ?? '';
    final startDate = d['start_date'] ?? '';
    final endDate = d['end_date'] ?? '';
    final userName = d['user_name'] ?? '';
    final approverName = d['approver_name'] ?? '';
    final createdAt = d['created_at'] ?? '';
    final checkin = d['checkin'] as Map<String, dynamic>?;

    final isRejected = status == 'rejected';
    final isOutsideCheckin = type == '异常打卡';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态头部
          _buildStatusHeader(colors, theme, type, status),
          const SizedBox(height: 16),

          // 基本信息卡片
          _buildInfoCard(colors, theme, [
            _infoRow('申请人', userName, Colors.transparent, colors),
            _infoRow('申请类型', _typeLabel(type), _typeColor(type, colors), colors),
            _infoRow('申请日期', startDate.isNotEmpty ? '$startDate${endDate.isNotEmpty && endDate != startDate ? ' ~ $endDate' : ''}' : '-', Colors.transparent, colors),
            _infoRow('申请原因', reason.isNotEmpty ? reason : '-', Colors.transparent, colors),
            if (createdAt.isNotEmpty)
              _infoRow('提交时间', _fmtDateTime(createdAt), Colors.transparent, colors),
          ]),
          const SizedBox(height: 12),

          // 审批结果
          if (status == 'approved' || isRejected) ...[
            _buildInfoCard(colors, theme, [
              _infoRow(
                isRejected ? '驳回人' : '审批人',
                approverName.isNotEmpty ? approverName : '-',
                Colors.transparent, colors,
              ),
              _infoRow(
                isRejected ? '驳回原因' : '审批备注',
                remark.isNotEmpty ? remark : '-',
                isRejected ? colors.error : Colors.transparent, colors,
              ),
              if (d['approved_at'] != null)
                _infoRow('处理时间', _fmtDateTime(d['approved_at']), Colors.transparent, colors),
            ]),
            const SizedBox(height: 12),
          ],

          // 关联打卡记录（异常打卡审批）
          if (isOutsideCheckin && checkin != null) ...[
            Text('关联打卡记录', style: theme.textTheme.titleSmall?.copyWith(
              color: colors.textPrimary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _buildCheckinCard(colors, theme, checkin),
            const SizedBox(height: 12),
          ],

          // 重新打卡按钮（被驳回的异常打卡）
          if (isRejected && isOutsideCheckin)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/camera_checkin');
                },
                icon: const Icon(Icons.camera_alt),
                label: const Text('重新打卡'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BentoRadius.md),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(BentoColors colors, ThemeData theme, String type, String status) {
    IconData icon;
    Color color;
    String text;

    switch (status) {
      case 'approved':
        icon = Icons.check_circle; color = colors.success; text = '已通过';
        break;
      case 'rejected':
        icon = Icons.cancel; color = colors.error; text = '已驳回';
        break;
      default:
        icon = Icons.pending; color = colors.warning; text = '待审批';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BentoRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 12),
          Text(text, style: theme.textTheme.titleLarge?.copyWith(
            color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(_typeLabel(type), style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BentoColors colors, ThemeData theme, List<Widget> rows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BentoRadius.lg),
      ),
      child: Column(children: rows),
    );
  }

  Widget _infoRow(String label, String value, Color valueColor, BentoColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: TextStyle(color: colors.textTertiary, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor != Colors.transparent ? valueColor : colors.textPrimary,
                fontSize: 13, fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckinCard(BentoColors colors, ThemeData theme, Map<String, dynamic> checkin) {
    final address = checkin['address'] ?? '';
    final photo = checkin['photo'] ?? '';
    final time = _fmtDateTime(checkin['created_at']);
    final type = checkin['type'] ?? '';
    final isIn = type == 'in' || type == 'clock_in';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(BentoRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isIn ? Icons.login : Icons.logout, size: 18,
                  color: isIn ? colors.success : colors.error),
              const SizedBox(width: 6),
              Text(isIn ? '上班打卡' : '下班打卡',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          if (address.isNotEmpty)
            Text('📍 $address', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
          Text('🕐 $time', style: TextStyle(color: colors.textTertiary, fontSize: 12)),
          if (photo.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(photo, height: 120, width: double.infinity,
                  fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
            ),
          ],
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case '补卡': return '补卡申请';
      case '请假': return '请假申请';
      case '加班': return '加班申请';
      case '异常打卡': return '异常打卡审批';
      default: return type;
    }
  }

  Color _typeColor(String type, BentoColors colors) {
    switch (type) {
      case '补卡': return colors.primary;
      case '请假': return colors.success;
      case '加班': return colors.warning;
      case '异常打卡': return colors.error;
      default: return colors.textSecondary;
    }
  }

  String _fmtDateTime(String? dt) {
    if (dt == null || dt.isEmpty) return '-';
    try {
      final s = dt.replaceAll(' ', 'T');
      final date = DateTime.parse(s);
      return DateFormat('yyyy-MM-dd HH:mm').format(date);
    } catch (_) {
      return dt;
    }
  }
}
