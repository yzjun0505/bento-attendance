import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../widgets/bento_widgets.dart';
import '../../widgets/amap_webview.dart';
import '../../repositories/track_repository.dart';

const _kAmapWebKey = 'your_amap_web_key_here';

class TrackScreen extends StatefulWidget {
  final int? userId;
  final String? userName;
  final String? initialDate;

  const TrackScreen({super.key, this.userId, this.userName, this.initialDate});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  final TrackRepository _trackRepo = TrackRepository();
  final AMapController _mapController = AMapController();
  late String _selectedDate;
  Map<String, dynamic>? _trackData;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadTrack();
  }

  Future<void> _loadTrack() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      Map<String, dynamic>? data;
      if (widget.userId != null) {
        data = await _trackRepo.getTrack(widget.userId!, _selectedDate);
      } else {
        data = await _trackRepo.getMyTrack(_selectedDate);
      }
      setState(() {
        _trackData = data;
        _loading = false;
      });
      if (data != null) _drawTrackOnMap();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '加载轨迹失败';
      });
    }
  }

  void _drawTrackOnMap() {
    if (!_mapController.isReady || _trackData == null) return;
    final points = _trackData!['points'] as List? ?? [];
    if (points.isEmpty) return;

    final path = points
        .map((p) => {'lng': p['longitude'], 'lat': p['latitude']})
        .toList();

    _mapController.drawTrack(path);
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_selectedDate) ?? DateTime.now(),
      firstDate: DateTime(2024, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = DateFormat('yyyy-MM-dd').format(picked));
      _loadTrack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(widget.userName != null ? '${widget.userName} 的轨迹' : '我的轨迹'),
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDate,
          ),
        ],
      ),
      body: Column(
        children: [
          // 日期选择条
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: colors.surface,
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: colors.primary),
                const SizedBox(width: 8),
                Text(_selectedDate, style: theme.textTheme.bodyMedium?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (_trackData != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_trackData!['total_distance'] ?? 0} km · ${(_trackData!['points'] as List?)?.length ?? 0} 点',
                      style: theme.textTheme.labelSmall?.copyWith(color: colors.primary),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 地图区域
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                AMapWebView(
                  apiKey: _kAmapWebKey,
                  controller: _mapController,
                  isDarkMode: theme.brightness == Brightness.dark,
                  onMapReady: _drawTrackOnMap,
                ),
                if (_loading)
                  Container(
                    color: colors.background.withValues(alpha: 0.6),
                    child: Center(
                      child: CircularProgressIndicator(color: colors.primary),
                    ),
                  ),
                if (_error != null)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 40, color: colors.textTertiary),
                        const SizedBox(height: 8),
                        Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: colors.textSecondary)),
                        const SizedBox(height: 12),
                        TextButton(onPressed: _loadTrack, child: const Text('重试')),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // 底部统计和停留点
          Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(BentoRadius.lg)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, -2))],
            ),
            child: _trackData == null
                ? const SizedBox.shrink()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 统计卡片
                        Row(
                          children: [
                            _buildStatCard(context, '总里程', '${_trackData!['total_distance'] ?? 0} km', Icons.route, colors),
                            const SizedBox(width: 12),
                            _buildStatCard(context, '轨迹点', '${(_trackData!['points'] as List?)?.length ?? 0}', Icons.timeline, colors),
                            const SizedBox(width: 12),
                            _buildStatCard(context, '停留点', '${(_trackData!['stops'] as List?)?.length ?? 0}', Icons.access_time_filled, colors),
                          ],
                        ),

                        // 停留点列表
                        ..._buildStopsList(colors, theme),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, BentoColors colors) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: colors.primary),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary)),
            Text(label, style: TextStyle(fontSize: 11, color: colors.textTertiary)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStopsList(BentoColors colors, ThemeData theme) {
    final stops = _trackData?['stops'] as List? ?? [];
    if (stops.isEmpty) return [];

    return [
      const SizedBox(height: 16),
      Text('停留点', style: theme.textTheme.titleSmall?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      ...stops.map((stop) => GestureDetector(
        onTap: () {
          if (stop['longitude'] != null && stop['latitude'] != null) {
            _mapController.moveToLocation(
              (stop['longitude'] as num).toDouble(),
              (stop['latitude'] as num).toDouble(),
              zoom: 17,
            );
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceVariant.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: colors.warning, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stop['address'] ?? '未知位置', style: theme.textTheme.bodySmall?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      '${stop['start_time'] ?? ''} ~ ${stop['end_time'] ?? ''} · ${stop['duration'] ?? 0}分钟',
                      style: theme.textTheme.labelSmall?.copyWith(color: colors.textTertiary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: colors.textTertiary),
            ],
          ),
        ),
      )),
    ];
  }
}
