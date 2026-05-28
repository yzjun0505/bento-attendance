import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/dio_client.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../models/checkin_model.dart';
import '../../repositories/checkin_repository.dart';
import '../../widgets/bento_widgets.dart';

class MyCheckinsScreen extends StatefulWidget {
  const MyCheckinsScreen({super.key});

  @override
  State<MyCheckinsScreen> createState() => _MyCheckinsScreenState();
}

class _MyCheckinsScreenState extends State<MyCheckinsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final CheckinRepository _repository =
      CheckinRepository(apiClient: ApiClient());

  DateTime? _selectedDate;
  String _query = '';

  List<Checkin> _allCheckins = [];
  List<Checkin> _displayedCheckins = [];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;

  int _currentPage = 1;
  static const int _pageSize = 20;

  String get _dateLabel {
    final d = _selectedDate;
    if (d == null) return '筛选';
    return DateFormat('MM月dd日').format(d);
  }

  bool get _hasActiveFilter => _query.isNotEmpty || _selectedDate != null;

  @override
  void initState() {
    super.initState();
    _loadCheckins();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadCheckins() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
    });

    try {
      final list = await _repository.getMyCheckins(
        page: 1,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _allCheckins = list;
        _hasMore = list.length >= _pageSize;
        _currentPage = 1;
        _updateDisplayedList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _hasActiveFilter) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final list = await _repository.getMyCheckins(
        page: nextPage,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _allCheckins.addAll(list);
        _hasMore = list.length >= _pageSize;
        _currentPage = nextPage;
        _updateDisplayedList();
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _updateDisplayedList() {
    _displayedCheckins = _filterCheckins(_allCheckins);
  }

  List<Checkin> _filterCheckins(List<Checkin> checkins) {
    return checkins.where((item) {
      final selected = _selectedDate;
      if (selected != null) {
        final created = item.createdAt;
        if (created.year != selected.year ||
            created.month != selected.month ||
            created.day != selected.day) {
          return false;
        }
      }

      if (_query.isEmpty) return true;
      final haystack = [
        item.type,
        item.typeName,
        item.address,
        item.remark,
        item.projectName ?? '',
        item.watermarkCode ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(_query.toLowerCase());
    }).toList();
  }

  void _applyFilter() {
    setState(() => _updateDisplayedList());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('我的打卡'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(context, colors, theme),
          if (_hasActiveFilter) _buildFilterSummary(context, colors, theme),
          Expanded(child: _buildBody(context, colors, theme)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(
      BuildContext context, BentoColors colors, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BentoSpacing.space20,
        BentoSpacing.space8,
        BentoSpacing.space20,
        BentoSpacing.space8,
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _showSearchSheet(context),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(BentoRadius.sm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 20, color: colors.textTertiary),
                    const SizedBox(width: 8),
                    Text(
                      _query.isEmpty ? '搜索类型、项目、地点、备注' : _query,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _query.isEmpty
                            ? colors.textTertiary
                            : colors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: BentoSpacing.space8),
          GestureDetector(
            onTap: () => _showDatePicker(context),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(BentoRadius.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 16, color: colors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    _dateLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSummary(
      BuildContext context, BentoColors colors, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          BentoSpacing.space20, 0, BentoSpacing.space20, BentoSpacing.space8),
      child: Row(
        children: [
          if (_selectedDate != null)
            _buildFilterChip(
              icon: Icons.calendar_today_outlined,
              label: DateFormat('yyyy-MM-dd').format(_selectedDate!),
              colors: colors,
              onDeleted: () {
                setState(() => _selectedDate = null);
                _applyFilter();
              },
            ),
          if (_query.isNotEmpty) ...[
            if (_selectedDate != null) const SizedBox(width: 8),
            Expanded(
              child: _buildFilterChip(
                icon: Icons.search,
                label: _query,
                colors: colors,
                onDeleted: () {
                  _searchController.clear();
                  setState(() => _query = '');
                  _applyFilter();
                },
              ),
            ),
          ],
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _query = '';
                _selectedDate = null;
              });
              _applyFilter();
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required BentoColors colors,
    required VoidCallback onDeleted,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(BentoRadius.sm),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 14, color: colors.textTertiary),
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            padding: EdgeInsets.zero,
            onPressed: onDeleted,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, BentoColors colors, ThemeData theme) {
    if (_isLoading) {
      return const BentoLoading.spinner();
    }

    if (_errorMessage != null) {
      return BentoEmptyState(
        icon: Icons.error_outline,
        title: '加载失败',
        description: _errorMessage!,
        actionText: '重试',
        onAction: _loadCheckins,
      );
    }

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: _loadCheckins,
      child: _displayedCheckins.isEmpty
          ? ListView(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                BentoEmptyState(
                  icon: Icons.history,
                  title: _hasActiveFilter ? '没有匹配记录' : '暂无打卡记录',
                  description: _hasActiveFilter ? '换个关键词或日期再试试' : '还没有打卡记录',
                ),
              ],
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: BentoSpacing.space20,
              ),
              itemCount: _displayedCheckins.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _displayedCheckins.length) {
                  return const Padding(
                    padding:
                        EdgeInsets.symmetric(vertical: BentoSpacing.space16),
                    child: BentoLoading.inline(),
                  );
                }
                final item = _displayedCheckins[index];
                return _buildCheckinItem(context, item, colors, theme);
              },
            ),
    );
  }

  Widget _buildCheckinItem(
      BuildContext context, Checkin item, BentoColors colors, ThemeData theme) {
    final iconColor = item.isOutside ? colors.warning : item.typeColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: BentoSpacing.space8),
      child: BentoCard(
        padding: const EdgeInsets.all(BentoSpacing.space12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(BentoRadius.sm),
              ),
              child: Icon(
                item.typeIcon,
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: BentoSpacing.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.typeName,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        DateFormat('yyyy-MM-dd HH:mm').format(item.createdAt),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        item.isOutside
                            ? Icons.warning_amber
                            : Icons.location_on,
                        size: 12,
                        color: iconColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.isOutside
                              ? '距围栏中心 ${item.distanceToFence ?? '-'}m · 异常'
                              : (item.projectName ?? item.address),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: item.isOutside
                                ? colors.warning
                                : colors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.isAbnormal) ...[
                        const SizedBox(width: 6),
                        BentoBadge.warning(
                          text: item.statusText ?? '异常',
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSearchSheet(BuildContext context) async {
    final colors = context.colors;
    _searchController.text = _query;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: BentoSpacing.space20,
            right: BentoSpacing.space20,
            top: BentoSpacing.space20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom +
                BentoSpacing.space20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                            _applyFilter();
                            Navigator.pop(sheetContext);
                          },
                        ),
                  hintText: '搜索类型、项目、地点、备注',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(BentoRadius.sm)),
                ),
                onSubmitted: (value) {
                  setState(() => _query = value.trim());
                  _applyFilter();
                  Navigator.pop(sheetContext);
                },
              ),
              const SizedBox(height: BentoSpacing.space16),
              ElevatedButton(
                onPressed: () {
                  setState(() => _query = _searchController.text.trim());
                  _applyFilter();
                  Navigator.pop(sheetContext);
                },
                child: const Text('搜索'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDatePicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() => _selectedDate = picked);
      _applyFilter();
    }
  }
}
