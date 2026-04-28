import 'package:flutter/material.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../widgets/bento_card.dart';
import '../../widgets/bento_empty_state.dart';
import '../../widgets/bento_loading.dart';
import '../../models/notification_model.dart';
import '../../repositories/notification_repository.dart';
import '../../api/dio_client.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late final NotificationRepository _notificationRepository;
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _notificationRepository = NotificationRepository(
      apiClient: ApiClient(),
    );
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final notifications = await _notificationRepository.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _markAsRead(NotificationModel notification, int index) async {
    if (notification.isRead) return;

    final success = await _notificationRepository.markAsRead(notification.id);
    if (success && mounted) {
      setState(() {
        _notifications[index] = notification.copyWith(isRead: true);
      });
    }
  }

  Future<void> _markAllAsRead() async {
    final success = await _notificationRepository.markAllAsRead();
    if (success && mounted) {
      setState(() {
        _notifications = _notifications
            .map((n) => n.copyWith(isRead: true))
            .toList();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已全部标记为已读')),
        );
      }
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'system':
        return Icons.info_outline;
      case 'attendance':
        return Icons.access_time;
      case 'project':
        return Icons.work_outline;
      case 'warning':
        return Icons.warning_amber_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getNotificationColor(String type, BentoColors colors) {
    switch (type) {
      case 'system':
        return colors.primary;
      case 'attendance':
        return colors.success;
      case 'project':
        return colors.warning;
      case 'warning':
        return colors.error;
      default:
        return colors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '消息中心',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        actions: [
          if (_notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                '全部已读',
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(BentoColors colors) {
    if (_isLoading) {
      return const Center(child: BentoLoading.spinner());
    }

    if (_hasError) {
      return BentoEmptyState(
        icon: Icons.error_outline,
        title: '加载失败',
        description: _errorMessage.isNotEmpty ? _errorMessage : null,
        actionText: '重试',
        onAction: _loadNotifications,
      );
    }

    if (_notifications.isEmpty) {
      return const BentoEmptyState(
        icon: Icons.notifications_none,
        title: '暂无消息',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return _buildNotificationItem(notification, index, colors);
        },
      ),
    );
  }

  Widget _buildNotificationItem(
    NotificationModel notification,
    int index,
    BentoColors colors,
  ) {
    final iconColor = _getNotificationColor(notification.type, colors);

    return GestureDetector(
      onTap: () => _markAsRead(notification, index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: BentoCard(
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(BentoRadius.sm),
                    ),
                    child: Icon(
                      _getNotificationIcon(notification.type),
                      color: iconColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!notification.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: colors.error,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notification.content,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          notification.formattedTime,
                          style: TextStyle(
                            color: colors.textSecondary.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
