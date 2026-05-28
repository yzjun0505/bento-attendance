import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../api/dio_client.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../repositories/personnel_repository.dart';
import '../../widgets/bento_card.dart';
import '../../widgets/bento_empty_state.dart';
import '../../widgets/bento_loading.dart';
import '../../widgets/bento_avatar.dart';
import 'personnel_form_screen.dart';

class PersonnelListScreen extends StatefulWidget {
  const PersonnelListScreen({super.key});

  @override
  State<PersonnelListScreen> createState() => _PersonnelListScreenState();
}

class _PersonnelListScreenState extends State<PersonnelListScreen> {
  final _personnelRepo = PersonnelRepository(apiClient: ApiClient());
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<dynamic> _users = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _page = 1;
  int _total = 0;
  String _keyword = '';

  bool get _isManager {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return authState.user.role == 'manager';
    }
    return false;
  }

  int? get _currentUserId {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return authState.user.id;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      _loadMore();
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _page = 1;
    });

    try {
      final role = _isManager ? 'worker' : null;
      final result = await _personnelRepo.getUsers(
        keyword: _keyword.isNotEmpty ? _keyword : null,
        role: role,
        page: 1,
      );
      setState(() {
        _users = result['list'] as List<dynamic>;
        _total = result['total'] as int;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _users.length >= _total) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _page + 1;
      final role = _isManager ? 'worker' : null;
      final result = await _personnelRepo.getUsers(
        keyword: _keyword.isNotEmpty ? _keyword : null,
        role: role,
        page: nextPage,
      );
      final newUsers = result['list'] as List<dynamic>;
      setState(() {
        _page = nextPage;
        _users.addAll(newUsers);
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  void _onSearchChanged(String value) {
    _keyword = value;
    _loadUsers();
  }

  Future<void> _navigateToForm({dynamic user}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PersonnelFormScreen(user: user),
      ),
    );
    if (result == true) {
      _loadUsers();
    }
  }

  Future<void> _handleDelete(dynamic user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除用户「${user.name}」吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _personnelRepo.deleteUser(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除成功')),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  Future<void> _handleResetPassword(dynamic user) async {
    final passwordController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重置密码'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: '请输入新密码',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, passwordController.text),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('密码不能为空')),
        );
      }
      return;
    }

    try {
      await _personnelRepo.resetPassword(user.id, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('密码重置成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('重置密码失败: $e')),
        );
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

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return '管理员';
      case 'manager':
        return '项目经理';
      case 'worker':
        return '工人';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currentUserId = _currentUserId;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('人员管理'),
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加人员',
            onPressed: () => _navigateToForm(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(colors),
          Expanded(child: _buildBody(colors, currentUserId)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BentoColors colors) {
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(
        BentoSpacing.space16,
        0,
        BentoSpacing.space16,
        BentoSpacing.space12,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: TextStyle(color: colors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: '搜索姓名 / 用户名 / 手机号',
          hintStyle: TextStyle(color: colors.textTertiary, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: colors.textTertiary, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: colors.textTertiary, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: colors.surfaceVariant,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
        ),
      ),
    );
  }

  Widget _buildBody(BentoColors colors, int? currentUserId) {
    if (_isLoading) {
      return const BentoLoading.spinner();
    }

    if (_users.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadUsers,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            BentoEmptyState(
              icon: Icons.people_outline,
              title: '暂无人员数据',
              description: '点击右上角 + 添加人员',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(BentoSpacing.space16),
        itemCount: _users.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _users.length) {
            return const Padding(
              padding: EdgeInsets.all(BentoSpacing.space16),
              child: BentoLoading.inline(),
            );
          }
          return _buildUserCard(_users[index], colors, currentUserId);
        },
      ),
    );
  }

  Widget _buildUserCard(dynamic user, BentoColors colors, int? currentUserId) {
    final role = user.role as String? ?? 'worker';
    final roleColor = _getRoleColor(role, colors);
    final roleLabel = _getRoleLabel(role);
    final isSelf = currentUserId != null && user.id == currentUserId;

    return Padding(
      padding: const EdgeInsets.only(bottom: BentoSpacing.space10),
      child: BentoCard(
        padding: const EdgeInsets.all(BentoSpacing.space16),
        child: Row(
          children: [
            BentoAvatar(
              size: 44,
              text: (user.name as String? ?? '?')[0],
              backgroundColor: roleColor.withValues(alpha: 0.15),
              textColor: roleColor,
            ),
            const SizedBox(width: BentoSpacing.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user.name ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      if (isSelf) ...[
                        const SizedBox(width: BentoSpacing.space8),
                        Text(
                          '(我)',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: BentoSpacing.space4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          roleLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: roleColor,
                          ),
                        ),
                      ),
                      if (user.projectName != null &&
                          (user.projectName as String).isNotEmpty) ...[
                        const SizedBox(width: BentoSpacing.space8),
                        Expanded(
                          child: Text(
                            user.projectName as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (!isSelf)
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _navigateToForm(user: user);
                      break;
                    case 'reset_password':
                      _handleResetPassword(user);
                      break;
                    case 'delete':
                      _handleDelete(user);
                      break;
                  }
                },
                icon:
                    Icon(Icons.more_vert, color: colors.textTertiary, size: 20),
                color: colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(BentoRadius.sm),
                ),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18, color: colors.textSecondary),
                        const SizedBox(width: BentoSpacing.space8),
                        Text(
                          '编辑',
                          style: TextStyle(color: colors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'reset_password',
                    child: Row(
                      children: [
                        Icon(Icons.lock_reset,
                            size: 18, color: colors.textSecondary),
                        const SizedBox(width: BentoSpacing.space8),
                        Text(
                          '重置密码',
                          style: TextStyle(color: colors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            size: 18, color: colors.error),
                        const SizedBox(width: BentoSpacing.space8),
                        Text(
                          '删除',
                          style: TextStyle(color: colors.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
