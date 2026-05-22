import 'package:flutter/material.dart';
import '../../api/dio_client.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../models/device_model.dart';
import '../../repositories/device_repository.dart';
import '../../widgets/bento_empty_state.dart';
import '../../widgets/bento_loading.dart';
import 'device_form_screen.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final _apiClient = ApiClient();
  late final DeviceRepository _deviceRepo;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<Device> _devices = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _page = 1;
  int _total = 0;
  int? _statusFilter;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _deviceRepo = DeviceRepository(apiClient: _apiClient);
    _scrollController.addListener(_onScroll);
    _loadDevices();
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

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
      _page = 1;
    });

    try {
      final result = await _deviceRepo.getDevices(
        keyword: _keyword.isNotEmpty ? _keyword : null,
        status: _statusFilter,
        page: 1,
      );

      if (!mounted) return;
      setState(() {
        _devices = result['list'] as List<Device>;
        _total = result['total'] as int;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载失败: $e')),
      );
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _devices.length >= _total) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _page + 1;
      final result = await _deviceRepo.getDevices(
        keyword: _keyword.isNotEmpty ? _keyword : null,
        status: _statusFilter,
        page: nextPage,
      );

      if (!mounted) return;
      final newDevices = result['list'] as List<Device>;
      setState(() {
        _page = nextPage;
        _devices.addAll(newDevices);
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _onSearchChanged(String value) {
    _keyword = value;
    _loadDevices();
  }

  Future<void> _deleteDevice(Device device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除设备'),
        content: Text('确定要删除设备"${device.name}"吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _deviceRepo.deleteDevice(device.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备已删除')),
        );
        _loadDevices();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  void _navigateToForm({Device? device}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceFormScreen(device: device),
      ),
    );
    if (result == true && mounted) {
      _loadDevices();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('设备管理'),
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: colors.primary),
            onPressed: () => _navigateToForm(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(colors),
          _buildStatusFilter(colors),
          Expanded(child: _buildBody(colors)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BentoColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BentoSpacing.space16,
        vertical: BentoSpacing.space8,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: TextStyle(color: colors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: '搜索设备名称或ID',
          hintStyle: TextStyle(color: colors.textTertiary),
          prefixIcon: Icon(Icons.search, color: colors.textTertiary, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: colors.textTertiary, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: colors.surfaceVariant,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

  Widget _buildStatusFilter(BentoColors colors) {
    final filters = [
      {'label': '全部', 'value': null},
      {'label': '正常', 'value': 1},
      {'label': '停用', 'value': 0},
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: BentoSpacing.space16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: BentoSpacing.space8),
        itemBuilder: (context, index) {
          final isSelected = _statusFilter == filters[index]['value'];
          return GestureDetector(
            onTap: () {
              setState(() => _statusFilter = filters[index]['value'] as int?);
              _loadDevices();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? colors.primary : colors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  filters[index]['label'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? colors.textOnPrimary
                        : colors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(BentoColors colors) {
    if (_isLoading) {
      return const BentoLoading.spinner();
    }

    if (_devices.isEmpty) {
      return BentoEmptyState(
        icon: Icons.devices_other,
        title: '暂无设备',
        description: '点击右上角"+"添加设备',
        actionText: '添加设备',
        onAction: () => _navigateToForm(),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDevices,
      color: colors.primary,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(BentoSpacing.space16),
        itemCount: _devices.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _devices.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: BentoSpacing.space16),
              child: BentoLoading.spinner(size: 24),
            );
          }
          return _buildDeviceCard(_devices[index], colors);
        },
      ),
    );
  }

  Widget _buildDeviceCard(Device device, BentoColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: BentoSpacing.space12),
      padding: const EdgeInsets.all(BentoSpacing.space16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BentoRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primaryLight,
              borderRadius: BorderRadius.circular(BentoRadius.sm),
            ),
            child: Icon(
              device.typeIcon,
              color: colors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: BentoSpacing.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${device.deviceId}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textTertiary,
                  ),
                ),
                if (device.projectName != null &&
                    device.projectName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.folder_outlined,
                          size: 12, color: colors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        device.projectName!,
                        style:
                            TextStyle(fontSize: 12, color: colors.textTertiary),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: BentoSpacing.space8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: device.isActive
                      ? colors.successLight
                      : colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  device.statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color:
                        device.isActive ? colors.success : colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: BentoSpacing.space8),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 18,
                color: colors.surface,
                icon: Icon(Icons.more_horiz, color: colors.textSecondary),
                onSelected: (value) {
                  if (value == 'edit') {
                    _navigateToForm(device: device);
                  } else if (value == 'delete') {
                    _deleteDevice(device);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined,
                            size: 18, color: colors.textPrimary),
                        const SizedBox(width: 8),
                        Text('编辑', style: TextStyle(color: colors.textPrimary)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('删除', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
