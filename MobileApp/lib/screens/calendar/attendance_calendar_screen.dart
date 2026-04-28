import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../api/dio_client.dart';
import '../../repositories/checkin_repository.dart';
import '../../widgets/bento_empty_state.dart';

class AttendanceCalendarScreen extends StatefulWidget {
  const AttendanceCalendarScreen({super.key});

  @override
  State<AttendanceCalendarScreen> createState() => _AttendanceCalendarScreenState();
}

class _AttendanceCalendarScreenState extends State<AttendanceCalendarScreen> {
  late final CheckinRepository _checkinRepo;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Map<DateTime, List<Map<String, dynamic>>> _events = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkinRepo = CheckinRepository(apiClient: ApiClient());
    _loadAttendanceData();
  }

  Future<void> _loadAttendanceData() async {
    try {
      final checkins = await _checkinRepo.getMyCheckins();

      final Map<DateTime, List<Map<String, dynamic>>> events = {};
      for (final checkin in checkins) {
        final dateStr = checkin.createdAt.toIso8601String().split('T')[0];
        final date = DateTime.parse(dateStr);
        final normalizedDate = DateTime(date.year, date.month, date.day);
        events.putIfAbsent(normalizedDate, () => []);
        events[normalizedDate]!.add({
          'type': checkin.type,
          'created_at': checkin.createdAt.toIso8601String(),
          'address': checkin.address,
          'is_outside': checkin.isOutside ? 1 : 0,
        });
      }

      if (!mounted) return;
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('考勤日历'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildCalendar(colors),
                Divider(height: 1, color: colors.border),
                Expanded(child: _buildEventList(colors)),
              ],
            ),
    );
  }

  Widget _buildCalendar(BentoColors colors) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BentoRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarFormat: CalendarFormat.month,
        eventLoader: _getEventsForDay,
        startingDayOfWeek: StartingDayOfWeek.monday,
        headerStyle: HeaderStyle(
          formatButtonTextStyle: TextStyle(color: colors.primary),
          titleTextStyle: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
          leftChevronIcon: Icon(Icons.chevron_left, color: colors.textSecondary),
          rightChevronIcon: Icon(Icons.chevron_right, color: colors.textSecondary),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(weekdayStyle: TextStyle(color: colors.textSecondary)),
        weekendDays: const [DateTime.sunday],
        holidayPredicate: (day) => day.weekday == DateTime.sunday,
        calendarStyle: CalendarStyle(
          defaultTextStyle: TextStyle(color: colors.textPrimary),
          weekendTextStyle: TextStyle(color: colors.textTertiary),
          holidayTextStyle: TextStyle(color: colors.textTertiary),
          outsideTextStyle: TextStyle(color: colors.textTertiary),
          selectedDecoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
          todayDecoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.2), shape: BoxShape.circle,
          ),
          markerDecoration: BoxDecoration(color: colors.success, shape: BoxShape.circle),
          markerSize: 6.0,
          markersAutoAligned: false,
          markersOffset: const PositionedOffset(bottom: 4),
        ),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
      ),
    );
  }

  Widget _buildEventList(BentoColors colors) {
    final events = _getEventsForDay(_selectedDay);

    if (events.isEmpty) {
      return const BentoEmptyState(
        icon: Icons.event_busy,
        title: '当天无打卡记录',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) => _buildEventCard(events[index], colors),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event, BentoColors colors) {
    final type = event['type'] ?? 'in';
    final time = event['created_at'] ?? '';
    final address = event['address'] ?? '';
    final isOutside = event['is_outside'] == 1;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isOutside) {
      statusColor = colors.error;
      statusText = '围栏外打卡';
      statusIcon = Icons.warning_amber_rounded;
    } else if (type == 'in') {
      statusColor = colors.success;
      statusText = '上班打卡';
      statusIcon = Icons.login;
    } else {
      statusColor = colors.primary;
      statusText = '下班打卡';
      statusIcon = Icons.logout;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BentoRadius.sm),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(BentoRadius.sm),
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(statusText, style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                    if (isOutside) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('异常', style: TextStyle(color: colors.error, fontSize: 12, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(time.toString().split('.').first, style: TextStyle(color: colors.textSecondary, fontSize: 14)),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: colors.textTertiary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(address, style: TextStyle(color: colors.textTertiary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
