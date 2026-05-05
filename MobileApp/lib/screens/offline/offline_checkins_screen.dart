import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../widgets/bento_widgets.dart';
import '../../repositories/offline_checkin_repository.dart';

class OfflineCheckinsScreen extends StatefulWidget {
  const OfflineCheckinsScreen({super.key});

  @override
  State<OfflineCheckinsScreen> createState() => _OfflineCheckinsScreenState();
}

class _OfflineCheckinsScreenState extends State<OfflineCheckinsScreen> {
  final OfflineCheckinRepository _repo = OfflineCheckinRepository();
  List<Map<String, dynamic>> _checkins = [];
  int _cachedCount = 0;
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _loadCached();
  }

  Future<void> _loadCached() async {
    setState(() => _loading = true);
    final checkins = await _repo.getCachedCheckins();
    final count = await _repo.getCachedCount();
    setState(() {
      _checkins = checkins.reversed.toList();
      _cachedCount = count;
      _loading = false;
    });
  }

  Future<void> _syncAll() async {
    if (_cachedCount == 0) return;
    setState(() => _syncing = true);
    try {
      final synced = await _repo.syncCheckins();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已同步 $synced 条离线打卡'), backgroundColor: Colors.green),
        );
      }
      await _loadCached();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('离线打卡记录'),
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 顶部统计 + 同步按钮
          Container(
            padding: const EdgeInsets.all(16),
            color: colors.surface,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _cachedCount > 0 ? colors.warning.withValues(alpha: 0.1) : colors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _cachedCount > 0 ? Icons.cloud_off : Icons.cloud_done,
                        size: 16,
                        color: _cachedCount > 0 ? colors.warning : colors.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _cachedCount > 0 ? '$_cachedCount 条待同步' : '全部已同步',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _cachedCount > 0 ? colors.warning : colors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _cachedCount > 0 && !_syncing ? _syncAll : null,
                  icon: _syncing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync, size: 18),
                  label: Text(_syncing ? '同步中...' : '立即同步'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),

          // 列表
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: colors.primary))
                : _checkins.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_done, size: 64, color: colors.textTertiary.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            Text('没有离线打卡记录', style: theme.textTheme.bodyMedium?.copyWith(color: colors.textSecondary)),
                            const SizedBox(height: 4),
                            Text('网络异常时打卡会自动缓存到这里', style: theme.textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _checkins.length,
                        itemBuilder: (context, index) {
                          final item = _checkins[index];
                          final type = item['type'] as String? ?? '';
                          final isClockIn = type == 'clock_in';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colors.divider.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    color: (isClockIn ? colors.success : colors.warning).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isClockIn ? Icons.login : Icons.logout,
                                    color: isClockIn ? colors.success : colors.warning,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            isClockIn ? '上班打卡' : '下班打卡',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              color: colors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: colors.warning.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text('待同步', style: TextStyle(fontSize: 10, color: colors.warning)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item['address'] ?? '未知位置',
                                        style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        item['local_timestamp'] ?? '',
                                        style: theme.textTheme.labelSmall?.copyWith(color: colors.textTertiary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
