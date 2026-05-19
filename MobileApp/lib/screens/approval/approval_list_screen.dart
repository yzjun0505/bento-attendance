import 'package:flutter/material.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../repositories/approval_repository.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../widgets/bento_empty_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ApprovalListScreen extends StatefulWidget {
  const ApprovalListScreen({super.key});

  @override
  State<ApprovalListScreen> createState() => _ApprovalListScreenState();
}

class _ApprovalListScreenState extends State<ApprovalListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _approvalRepo = ApprovalRepository();

  List<Map<String, dynamic>> _pendingApprovals = [];
  List<Map<String, dynamic>> _myApprovals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    setState(() {});
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final authState = context.read<AuthBloc>().state;
      String? token;
      if (authState is AuthAuthenticated) {
        token = authState.token;
      }

      final results = await Future.wait([
        _approvalRepo.getMyApprovals(token: token),
        _approvalRepo.getAllApprovals(token: token),
      ]);

      setState(() {
        _myApprovals = results[0];
        _pendingApprovals = results[1].where((a) => a['status'] == 'pending').toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('审批中心'),
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, '/approval/create');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colors.primary,
          labelColor: colors.primary,
          unselectedLabelColor: colors.textSecondary,
          tabs: const [
            Tab(text: '我的申请'),
            Tab(text: '待我审批'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMyApprovalsList(colors),
                _buildPendingApprovalsList(colors),
              ],
            ),
    );
  }

  Widget _buildMyApprovalsList(BentoColors colors) {
    if (_myApprovals.isEmpty) {
      return const BentoEmptyState(
        icon: Icons.inbox_outlined,
        title: '暂无申请记录',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myApprovals.length,
        itemBuilder: (context, index) {
          return _buildApprovalCard(_myApprovals[index], isMyApproval: true, colors: colors);
        },
      ),
    );
  }

  Widget _buildPendingApprovalsList(BentoColors colors) {
    if (_pendingApprovals.isEmpty) {
      return const BentoEmptyState(
        icon: Icons.inbox_outlined,
        title: '暂无待审批事项',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingApprovals.length,
        itemBuilder: (context, index) {
          return _buildApprovalCard(_pendingApprovals[index], isMyApproval: false, colors: colors);
        },
      ),
    );
  }

  Widget _buildApprovalCard(Map<String, dynamic> approval, {required bool isMyApproval, required BentoColors colors}) {
    final type = approval['type'] ?? '';
    final status = approval['status'] ?? 'pending';
    final reason = approval['reason'] ?? '';
    final userName = approval['user_name'] ?? '';
    final createdAt = approval['created_at'] ?? '';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'approved':
        statusColor = colors.success;
        statusText = '已通过';
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = colors.error;
        statusText = '已驳回';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = colors.warning;
        statusText = '待审批';
        statusIcon = Icons.pending;
    }

    Color typeColor;
    String typeText;
    switch (type) {
      case '补卡':
        typeColor = colors.primary;
        typeText = '补卡申请';
        break;
      case '请假':
        typeColor = colors.success;
        typeText = '请假申请';
        break;
      case '加班':
        typeColor = colors.warning;
        typeText = '加班申请';
        break;
      case '异常打卡':
        typeColor = colors.error;
        typeText = '异常打卡审批';
        break;
      default:
        typeColor = colors.textSecondary;
        typeText = type;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BentoRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  typeText,
                  style: TextStyle(
                    color: typeColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(statusIcon, size: 18, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!isMyApproval) ...[
            Text(
              '申请人: $userName',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            '原因: $reason',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 15,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            '提交时间: $createdAt',
            style: TextStyle(
              color: colors.textTertiary,
              fontSize: 12,
            ),
          ),
          if (!isMyApproval && status == 'pending') ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _handleReject(approval),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.error,
                  ),
                  child: const Text('驳回'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _handleApprove(approval),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('同意'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleApprove(Map<String, dynamic> approval) async {
    try {
      final authState = context.read<AuthBloc>().state;
      String? token;
      if (authState is AuthAuthenticated) {
        token = authState.token;
      }

      await _approvalRepo.approve(approval['id'], token: token);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('审批已通过，考勤记录已更新')),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: ${e.toString()}')),
      );
    }
  }

  Future<void> _handleReject(Map<String, dynamic> approval) async {
    final remarkController = TextEditingController();

    final authState = context.read<AuthBloc>().state;
    String? token;
    if (authState is AuthAuthenticated) {
      token = authState.token;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('驳回原因'),
        content: TextField(
          controller: remarkController,
          decoration: const InputDecoration(
            hintText: '请输入驳回原因',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, remarkController.text),
            child: const Text('确认驳回'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await _approvalRepo.reject(approval['id'], remark: result, token: token);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已驳回')),
        );
        _loadData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: ${e.toString()}')),
        );
      }
    }
  }
}
