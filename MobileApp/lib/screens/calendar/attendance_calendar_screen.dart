import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../api/dio_client.dart';
import '../../repositories/checkin_repository.dart';
import '../../repositories/schedule_repository.dart';
import '../../repositories/holiday_repository.dart';
import '../../widgets/bento_empty_state.dart';

class AttendanceCalendarScreen extends StatefulWidget {
  const AttendanceCalendarScreen({super.key});

  @override
  State<AttendanceCalendarScreen> createState() =>
      _AttendanceCalendarScreenState();
}

class _AttendanceCalendarScreenState extends State<AttendanceCalendarScreen> {
  late final CheckinRepository _checkinRepo;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  Map<String, List<Map<String, dynamic>>> _scheduleMap =
      {}; // date -> schedules
  Map<String, Map<String, dynamic>> _holidayMap = {}; // date -> holiday info
  late final ScheduleRepository _scheduleRepo;
  late final HolidayRepository _holidayRepo;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkinRepo = CheckinRepository(apiClient: ApiClient());
    _scheduleRepo = ScheduleRepository();
    _holidayRepo = HolidayRepository();
    _loadAttendanceData();
  }

  Future<void> _loadAttendanceData() async {
    setState(() => _isLoading = true);
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

      // 同时加载排班和节假日数据
      final month =
          '${_focusedDay.year}-${_focusedDay.month.toString().padLeft(2, '0')}';
      final scheduleMap = await _scheduleRepo.getCalendarSchedules(month);
      final holidayMap = await _holidayRepo.getMonthHolidays(_focusedDay);

      if (!mounted) return;
      setState(() {
        _events = events;
        _scheduleMap = scheduleMap;
        _holidayMap = holidayMap;
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

  String _dateKey(DateTime day) => DateFormat('yyyy-MM-dd').format(day);

  List<Map<String, dynamic>> _getSchedulesForDay(DateTime day) {
    return _scheduleMap[_dateKey(day)] ?? [];
  }

  Map<String, dynamic>? _getHolidayForDay(DateTime day) {
    return _holidayMap[_dateKey(day)];
  }

  Color _parseColor(String? value, BentoColors colors) {
    if (value == null || value.isEmpty) return colors.primary;
    final hex = value.replaceAll('#', '');
    if (hex.length != 6) return colors.primary;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return colors.primary;
    return Color(0xFF000000 | parsed);
  }

  String _scheduleName(Map<String, dynamic> schedule) {
    return (schedule['shift_name'] ??
            schedule['name'] ??
            schedule['shift']?['name'] ??
            (schedule['is_rest'] == 1 || schedule['is_rest'] == true
                ? '休'
                : '班'))
        .toString();
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
          titleTextStyle: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600),
          leftChevronIcon:
              Icon(Icons.chevron_left, color: colors.textSecondary),
          rightChevronIcon:
              Icon(Icons.chevron_right, color: colors.textSecondary),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(color: colors.textSecondary)),
        weekendDays: const [DateTime.sunday],
        holidayPredicate: (day) => day.weekday == DateTime.sunday,
        calendarStyle: CalendarStyle(
          defaultTextStyle: TextStyle(color: colors.textPrimary),
          weekendTextStyle: TextStyle(color: colors.textTertiary),
          holidayTextStyle: TextStyle(color: colors.textTertiary),
          outsideTextStyle: TextStyle(color: colors.textTertiary),
          selectedDecoration:
              BoxDecoration(color: colors.primary, shape: BoxShape.circle),
          todayDecoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          markerDecoration:
              BoxDecoration(color: colors.success, shape: BoxShape.circle),
          markerSize: 6.0,
          markersAutoAligned: false,
          markersOffset: const PositionedOffset(bottom: 4),
        ),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) =>
              _buildDayCell(day, colors),
          todayBuilder: (context, day, focusedDay) =>
              _buildDayCell(day, colors, isToday: true),
          selectedBuilder: (context, day, focusedDay) =>
              _buildDayCell(day, colors, isSelected: true),
          outsideBuilder: (context, day, focusedDay) =>
              _buildDayCell(day, colors, isOutsideMonth: true),
        ),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
          _selectedDay = focusedDay;
          _loadAttendanceData();
        },
      ),
    );
  }

  Widget _buildDayCell(
    DateTime day,
    BentoColors colors, {
    bool isToday = false,
    bool isSelected = false,
    bool isOutsideMonth = false,
  }) {
    final schedules = _getSchedulesForDay(day);
    final holiday = _getHolidayForDay(day);
    final events = _getEventsForDay(day);
    final isRest =
        schedules.any((s) => s['is_rest'] == 1 || s['is_rest'] == true);
    final isHoliday =
        holiday?['type'] == 'holiday' || holiday?['is_holiday'] == true;
    final isWorkday =
        holiday?['type'] == 'workday' || holiday?['is_workday'] == true;
    final Color scheduleColor = schedules.isEmpty
        ? colors.textTertiary
        : _parseColor(schedules.first['color']?.toString(), colors);
    final String? badge = isHoliday
        ? '休'
        : isWorkday
            ? '班'
            : isRest
                ? '休'
                : schedules.isNotEmpty
                    ? _scheduleName(schedules.first)
                    : null;

    final textColor = isOutsideMonth
        ? colors.textTertiary
        : isSelected
            ? colors.textOnPrimary
            : colors.textPrimary;

    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? colors.primary
            : isToday
                ? colors.primary.withValues(alpha: 0.12)
                : isHoliday
                    ? colors.success.withValues(alpha: 0.10)
                    : isWorkday
                        ? colors.warning.withValues(alpha: 0.10)
                        : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isToday && !isSelected
            ? Border.all(color: colors.primary.withValues(alpha: 0.35))
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 14,
            child: badge == null
                ? (events.isEmpty
                    ? const SizedBox.shrink()
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: events.take(3).map((_) {
                          return Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                                color: isSelected
                                    ? colors.textOnPrimary
                                    : colors.success,
                                shape: BoxShape.circle),
                          );
                        }).toList(),
                      ))
                : Container(
                    constraints: const BoxConstraints(maxWidth: 42),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color:
                          (isHoliday || isRest ? colors.success : scheduleColor)
                              .withValues(alpha: isSelected ? 0.28 : 0.16),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected
                            ? colors.textOnPrimary
                            : (isHoliday || isRest
                                ? colors.success
                                : scheduleColor),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList(BentoColors colors) {
    final events = _getEventsForDay(_selectedDay);
    final schedules = _getSchedulesForDay(_selectedDay);
    final holiday = _getHolidayForDay(_selectedDay);

    if (events.isEmpty && schedules.isEmpty && holiday == null) {
      return const BentoEmptyState(
        icon: Icons.event_busy,
        title: '当天无打卡记录',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDaySummary(schedules, holiday, colors),
        ...events.map((event) => _buildEventCard(event, colors)),
      ],
    );
  }

  Widget _buildDaySummary(
    List<Map<String, dynamic>> schedules,
    Map<String, dynamic>? holiday,
    BentoColors colors,
  ) {
    if (schedules.isEmpty && holiday == null) return const SizedBox.shrink();

    final holidayName = holiday?['name']?.toString();
    final holidayType = holiday?['type']?.toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BentoRadius.sm),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('当天安排',
              style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          if (holiday != null) ...[
            const SizedBox(height: 10),
            _buildSummaryRow(
              icon: holidayType == 'workday'
                  ? Icons.work_outline
                  : Icons.beach_access_outlined,
              color: holidayType == 'workday' ? colors.warning : colors.success,
              title: holidayName == null || holidayName.isEmpty
                  ? (holidayType == 'workday' ? '调休上班' : '节假日')
                  : holidayName,
              subtitle: holidayType == 'workday' ? '调休上班日' : '休息日',
              colors: colors,
            ),
          ],
          if (schedules.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...schedules.map((schedule) {
              final isRest =
                  schedule['is_rest'] == 1 || schedule['is_rest'] == true;
              final scheduleColor = isRest
                  ? colors.success
                  : _parseColor(schedule['color']?.toString(), colors);
              final start = schedule['start_time']?.toString();
              final end = schedule['end_time']?.toString();
              final subtitle = isRest
                  ? '排班休息'
                  : [start, end]
                      .whereType<String>()
                      .where((s) => s.isNotEmpty)
                      .join(' - ');
              return _buildSummaryRow(
                icon: isRest ? Icons.weekend_outlined : Icons.schedule,
                color: scheduleColor,
                title: _scheduleName(schedule),
                subtitle: subtitle.isEmpty ? '已排班' : subtitle,
                colors: colors,
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required BentoColors colors,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ],
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
    } else if (type == 'in' || type == 'clock_in') {
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
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(BentoRadius.sm),
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
                    Text(statusText,
                        style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    if (isOutside) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('异常',
                            style: TextStyle(
                                color: colors.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(time.toString().split('.').first,
                    style:
                        TextStyle(color: colors.textSecondary, fontSize: 14)),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 14, color: colors.textTertiary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(address,
                            style: TextStyle(
                                color: colors.textTertiary, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
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
