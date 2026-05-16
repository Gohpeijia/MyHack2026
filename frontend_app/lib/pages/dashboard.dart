import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../services/api_services.dart';

// ─── DASHBOARD PAGE ───────────────────────────────────────────────────────────
class DashboardPage extends StatefulWidget {
  final List<ScheduleItem> schedules;

  // kept for API compatibility — no longer rendered
  final List<LocationCheckpoint>? checkpoints;
  final VoidCallback? onNavigateToMap;

  const DashboardPage({
    super.key,
    required this.schedules,
    this.checkpoints,
    this.onNavigateToMap,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late DateTime _selectedDate;
  late DateTime _calendarMonth; // month being displayed
  Map? alertData; // ← stores alerts from backend

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate   = DateTime(now.year, now.month, now.day);
    _calendarMonth  = DateTime(now.year, now.month, 1);
    loadAlerts(); // ← fetch alerts on load
  }

  void loadAlerts() async {
  final data = await getAlerts("elder_001");
  if (mounted) {  // ← add this check
    setState(() {
      alertData = data;
    });
  }
}

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int? _toMinutes(String timeStr) {
    try {
      final t = timeStr.trim();
      final sp = t.lastIndexOf(' ');
      final period = sp >= 0 ? t.substring(sp + 1).toUpperCase() : '';
      final clock  = sp >= 0 ? t.substring(0, sp) : t;
      final parts  = clock.split(':');
      int h = int.parse(parts[0]);
      final int m = int.parse(parts[1]);
      if (period == 'PM' && h != 12) h += 12;
      if (period == 'AM' && h == 12) h = 0;
      return h * 60 + m;
    } catch (_) { return null; }
  }

  bool _isMissedToday(ScheduleItem item) {
    if (item.done) return false;
    final itemMin = _toMinutes(item.time);
    if (itemMin == null) return false;
    final now    = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;
    return nowMin >= itemMin + 15;
  }

  int _minutesOverdue(ScheduleItem item) {
    final itemMin = _toMinutes(item.time) ?? 0;
    final now    = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;
    return (nowMin - itemMin).clamp(0, 9999);
  }

  // ── Today's base date (midnight) ──────────────────────────────────────────
  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  // ── Check if a repeating item applies to a given date ─────────────────────
  // Daily   → every date
  // Weekly  → same weekday as today
  // Monthly → same day-of-month as today
  bool _repeatApplies(ScheduleItem item, DateTime date) {
    switch (item.repeat) {
      case 'Daily':   return true;
      case 'Weekly':  return date.weekday == _today.weekday;
      case 'Monthly': return date.day == _today.day;
      default:        return false; // 'None'
    }
  }

  // ── Schedules for a given date ─────────────────────────────────────────────
  // Today   → live widget.schedules
  // Future  → only real repeating items that match the date
  // Past    → deterministic mock (replace with backend in production)
  List<ScheduleItem> _schedulesFor(DateTime date) {
    if (_isToday(date)) return widget.schedules;

    final isPast = date.isBefore(_today);

    if (!isPast) {
      // Future: filter real schedules by repeat rule
      return widget.schedules
          .where((item) => _repeatApplies(item, date))
          .map((item) => ScheduleItem(
                time: item.time,
                title: item.title,
                subtitle: item.subtitle,
                icon: item.icon,
                color: item.color,
                done: false,
                repeat: item.repeat,
              ))
          .toList();
    }

    // Past: deterministic mock history
    final seed = date.day + date.month * 31;
    final allItems = [
      ScheduleItem(
        time: '08:00 AM', title: 'Morning Medication',
        subtitle: 'Metformin 500mg + Vitamin D',
        icon: Icons.medication_rounded,
        color: const Color(0xFF2ECC8A),
        done: seed % 3 != 0, repeat: 'Daily',
      ),
      ScheduleItem(
        time: '10:00 AM', title: 'Doctor Appointment',
        subtitle: 'Klinik Sejahtera, SS15 Subang Jaya',
        icon: Icons.medical_services_rounded,
        color: const Color(0xFF4A90D9),
        done: seed % 5 != 1, repeat: 'None',
      ),
      ScheduleItem(
        time: '01:00 PM', title: 'Lunch Reminder',
        subtitle: 'Low sodium meal recommended',
        icon: Icons.restaurant_rounded,
        color: const Color(0xFFF39C12),
        done: seed % 4 != 2, repeat: 'Daily',
      ),
      ScheduleItem(
        time: '03:00 PM', title: 'Afternoon Walk',
        subtitle: '20 minutes light exercise',
        icon: Icons.directions_walk_rounded,
        color: const Color(0xFF9B59B6),
        done: seed % 7 != 3, repeat: 'None',
      ),
      ScheduleItem(
        time: '08:00 PM', title: 'Evening Medication',
        subtitle: 'Blood pressure tablet',
        icon: Icons.medication_liquid_rounded,
        color: const Color(0xFFE74C3C),
        done: seed % 3 == 0, repeat: 'Daily',
      ),
    ];
    return allItems;
  }

  // ── Upcoming items for a future date (repeating only) ─────────────────────
  List<ScheduleItem> _upcomingFor(DateTime date) {
    if (!date.isAfter(_today)) return [];
    return _schedulesFor(date);
  }

  List<ScheduleItem> _missedFor(DateTime date) {
    final items = _schedulesFor(date);
    if (_isToday(date)) return items.where(_isMissedToday).toList();
    if (date.isBefore(_today)) return items.where((i) => !i.done).toList();
    return [];
  }

  // ── Formatted helpers ──────────────────────────────────────────────────────

  String _formatHeaderDate(DateTime d) {
    const months   = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const weekdays = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    if (_isToday(d)) return 'Today, ${weekdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
    return '${weekdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final schedules = _schedulesFor(_selectedDate);
    final missed    = _missedFor(_selectedDate);
    final upcoming  = _upcomingFor(_selectedDate);
    final done      = schedules.where((s) => s.done).length;
    final total     = schedules.length;
    final isPast    = _selectedDate.isBefore(_today);
    final isFuture  = _selectedDate.isAfter(_today);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header ──────────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dashboard',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isFuture
                                ? 'Upcoming schedule'
                                : isPast
                                    ? 'Past activity history'
                                    : "Today's care overview",
                            style: const TextStyle(
                                fontSize: 18, color: Color(0xFF9999AA)),
                          ),
                        ],
                      ),
                    ),
                    // Selected date badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: _isToday(_selectedDate)
                            ? const Color(0xFF4A90D9).withOpacity(0.1)
                            : isPast
                                ? const Color(0xFFF39C12).withOpacity(0.1)
                                : const Color(0xFF9B59B6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formatHeaderDate(_selectedDate),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _isToday(_selectedDate)
                              ? const Color(0xFF4A90D9)
                              : isPast
                                  ? const Color(0xFFF39C12)
                                  : const Color(0xFF9B59B6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Progress bar — reacts to selected date
                _ScheduleProgressBar(
                  done: done,
                  total: total,
                  missed: missed.length,
                  isFuture: isFuture,
                ),
              ],
            ),
          ),

          // ── Scrollable body ─────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [

                // ── SECTION: Missed / Upcoming Activities ──────────────────
                _SectionHeader(
                  icon: isFuture
                      ? (upcoming.isEmpty
                          ? Icons.event_available_rounded
                          : Icons.event_repeat_rounded)
                      : (missed.isEmpty
                          ? Icons.check_circle_rounded
                          : Icons.warning_amber_rounded),
                  iconColor: isFuture
                      ? const Color(0xFF9B59B6)
                      : missed.isEmpty
                          ? const Color(0xFF2ECC8A)
                          : const Color(0xFFE74C3C),
                  title: isFuture ? 'Upcoming Activities' : 'Missed Activities',
                  badge: isFuture
                      ? (upcoming.isEmpty ? null : '${upcoming.length}')
                      : (missed.isEmpty ? null : '${missed.length}'),
                  badgeColor: isFuture
                      ? const Color(0xFF9B59B6)
                      : const Color(0xFFE74C3C),
                  subtitle: isFuture
                      ? (upcoming.isEmpty
                          ? 'No repeating activities on this date'
                          : '${upcoming.length} repeating ${upcoming.length == 1 ? 'activity' : 'activities'} scheduled')
                      : missed.isEmpty
                          ? 'All activities completed on this day 🎉'
                          : isPast
                              ? '${missed.length} not completed on this day'
                              : 'Not completed schedule',
                  subtitleColor: isFuture
                      ? (upcoming.isEmpty
                          ? const Color(0xFF9999AA)
                          : const Color(0xFF9B59B6))
                      : missed.isEmpty
                          ? const Color(0xFF2ECC8A)
                          : const Color(0xFFAA3322),
                ),
                const SizedBox(height: 12),

                if (isFuture) ...[
                  if (upcoming.isEmpty)
                    _EmptyCard(
                      icon: Icons.event_available_rounded,
                      color: const Color(0xFF9B59B6),
                      message: 'No repeating activities for this date. Add a Daily, Weekly, or Monthly schedule to see it here.',
                    )
                  else ...[
                    // Info banner
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3EEFF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFD9BBFF), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.repeat_rounded,
                              color: Color(0xFF9B59B6), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Showing repeating schedules for this date.',
                              style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF6B3FA0),
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...upcoming.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _UpcomingEventCard(item: item),
                    )),
                  ],
                ] else if (missed.isEmpty)
                  _EmptyCard(
                    icon: Icons.check_circle_outline_rounded,
                    color: const Color(0xFF2ECC8A),
                    message: 'No missed activities — great job!',
                  )
                else ...[
                  ...missed.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MissedEventCard(
                      item: item,
                      minutesOverdue: _isToday(_selectedDate)
                          ? _minutesOverdue(item)
                          : null,
                      isPastDay: isPast && !_isToday(_selectedDate),
                    ),
                  )),
                ],

                const SizedBox(height: 28),

                // ── SECTION: Activity Calendar ─────────────────────────────
                _SectionHeader(
                  icon: Icons.calendar_month_rounded,
                  iconColor: const Color(0xFF4A90D9),
                  title: 'Activity Calendar',
                  subtitle: 'Tap a date to view history',
                  subtitleColor: const Color(0xFF9999AA),
                ),
                const SizedBox(height: 14),
                _ActivityCalendar(
                  displayMonth: _calendarMonth,
                  selectedDate: _selectedDate,
                  missedCountForDate: (date) => _missedFor(date).length,
                  schedulesForDate: (date) => _schedulesFor(date),
                  onDateSelected: (date) =>
                      setState(() => _selectedDate = date),
                  onMonthChanged: (newMonth) =>
                      setState(() => _calendarMonth = newMonth),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ACTIVITY CALENDAR ────────────────────────────────────────────────────────
class _ActivityCalendar extends StatelessWidget {
  final DateTime displayMonth;
  final DateTime selectedDate;
  final int Function(DateTime) missedCountForDate;
  final List<ScheduleItem> Function(DateTime) schedulesForDate;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime> onMonthChanged;

  const _ActivityCalendar({
    required this.displayMonth,
    required this.selectedDate,
    required this.missedCountForDate,
    required this.schedulesForDate,
    required this.onDateSelected,
    required this.onMonthChanged,
  });

  static const _months = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December',
  ];
  static const _dow = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  bool _isSame(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final firstDay = displayMonth; // already normalized to day=1
    // weekday: Mon=1…Sun=7  → offset so Monday is column 0
    final startOffset = (firstDay.weekday - 1) % 7;
    final daysInMonth = DateUtils.getDaysInMonth(
        displayMonth.year, displayMonth.month);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Month navigation header ────────────────────────────────────────
          Row(
            children: [
              _NavArrow(
                icon: Icons.chevron_left_rounded,
                onTap: () => onMonthChanged(DateTime(
                    displayMonth.year, displayMonth.month - 1, 1)),
              ),
              Expanded(
                child: Text(
                  '${_months[displayMonth.month - 1]} ${displayMonth.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
              _NavArrow(
                icon: Icons.chevron_right_rounded,
                onTap: () => onMonthChanged(DateTime(
                    displayMonth.year, displayMonth.month + 1, 1)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Day-of-week labels ─────────────────────────────────────────────
          Row(
            children: _dow.map((d) => Expanded(
              child: Text(
                d,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9999AA),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),

          // ── Day grid ───────────────────────────────────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemCount: startOffset + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startOffset) return const SizedBox();

              final day = index - startOffset + 1;
              final date = DateTime(
                  displayMonth.year, displayMonth.month, day);
              final isSelected      = _isSame(date, selectedDate);
              final isToday         = _isToday(date);
              final missedCount     = missedCountForDate(date);
              final schedules       = schedulesForDate(date);
              final hasSchedule     = schedules.isNotEmpty;
              final isFuture        = date.isAfter(DateTime.now());
              // For future cells: count repeating items
              final repeatingCount  = isFuture
                  ? schedules.where((s) => s.repeat != 'None').length
                  : 0;

              return GestureDetector(
                onTap: () => onDateSelected(date),
                child: _DayCell(
                  day: day,
                  isSelected: isSelected,
                  isToday: isToday,
                  missedCount: missedCount,
                  hasSchedule: hasSchedule,
                  isFuture: isFuture,
                  repeatingCount: repeatingCount,
                ),
              );
            },
          ),

          // ── Legend ─────────────────────────────────────────────────────────
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: const Color(0xFF4A90D9),   label: 'Today'),
              const SizedBox(width: 12),
              _LegendDot(color: const Color(0xFFE74C3C),   label: 'Missed'),
              const SizedBox(width: 12),
              _LegendDot(color: const Color(0xFF2ECC8A),   label: 'All done'),
              const SizedBox(width: 12),
              _LegendDot(color: const Color(0xFF9B59B6),   label: 'Repeating'),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── DAY CELL ─────────────────────────────────────────────────────────────────
class _DayCell extends StatelessWidget {
  final int day;
  final bool isSelected;
  final bool isToday;
  final int missedCount;
  final bool hasSchedule;
  final bool isFuture;
  final int repeatingCount;

  const _DayCell({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.missedCount,
    required this.hasSchedule,
    required this.isFuture,
    this.repeatingCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor     = Colors.transparent;
    Color textColor   = const Color(0xFF1A1A2E);
    Color borderColor = Colors.transparent;

    if (isSelected && isToday) {
      bgColor   = const Color(0xFF4A90D9);
      textColor = Colors.white;
    } else if (isSelected) {
      bgColor   = const Color(0xFF1A1A2E);
      textColor = Colors.white;
    } else if (isToday) {
      borderColor = const Color(0xFF4A90D9);
      textColor   = const Color(0xFF4A90D9);
    } else if (isFuture) {
      textColor = const Color(0xFFBBBBCC);
    }

    // Dot colour under number
    Color? dotColor;
    if (!isSelected && !isFuture && hasSchedule) {
      // Past / today: red if missed, green if all done
      dotColor = missedCount > 0
          ? const Color(0xFFE74C3C)
          : const Color(0xFF2ECC8A);
    } else if (!isSelected && isFuture && repeatingCount > 0) {
      // Future: purple dot only when there are repeating activities
      dotColor = const Color(0xFF9B59B6);
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: borderColor != Colors.transparent
            ? Border.all(color: borderColor, width: 2)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          if (dotColor != null) ...[
            const SizedBox(height: 2),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.7) : dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── CALENDAR NAV ARROW ───────────────────────────────────────────────────────
class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF4A90D9)),
      ),
    );
  }
}

// ─── LEGEND DOT ───────────────────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF9999AA)),
        ),
      ],
    );
  }
}

// ─── SCHEDULE PROGRESS BAR ────────────────────────────────────────────────────
class _ScheduleProgressBar extends StatelessWidget {
  final int done;
  final int total;
  final int missed;
  final bool isFuture;

  const _ScheduleProgressBar({
    required this.done,
    required this.total,
    required this.missed,
    this.isFuture = false,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : done / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECFF), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFuture
                          ? '$total activities scheduled'
                          : '$done of $total activities completed',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    if (missed > 0 && !isFuture) ...[
                      const SizedBox(height: 3),
                      Text(
                        '$missed missed',
                        style: const TextStyle(
                            fontSize: 19, color: Color(0xFFE74C3C)),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                isFuture ? '--' : '${(pct * 100).round()}%',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isFuture
                      ? const Color(0xFF9999AA)
                      : pct == 1.0
                          ? const Color(0xFF2ECC8A)
                          : const Color(0xFF4A90D9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: isFuture ? 0 : pct,
              minHeight: 9,
              backgroundColor: const Color(0xFFDDE3FF),
              valueColor: AlwaysStoppedAnimation<Color>(
                isFuture
                    ? const Color(0xFFDDE3FF)
                    : pct == 1.0
                        ? const Color(0xFF2ECC8A)
                        : const Color(0xFF4A90D9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SECTION HEADER ───────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color subtitleColor;
  final String? badge;
  final Color? badgeColor;

  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.subtitleColor,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor ?? const Color(0xFFE74C3C),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(fontSize: 15, color: subtitleColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── MISSED EVENT CARD ────────────────────────────────────────────────────────
class _MissedEventCard extends StatelessWidget {
  final ScheduleItem item;
  final int? minutesOverdue;   // null = past day (show "Not completed")
  final bool isPastDay;

  const _MissedEventCard({
    required this.item,
    this.minutesOverdue,
    this.isPastDay = false,
  });

  String get _overdueLabel {
    if (isPastDay) return 'Not completed';
    final m = minutesOverdue ?? 0;
    if (m < 60) return '${m}m overdue';
    final h = m ~/ 60;
    final mins = m % 60;
    return mins > 0 ? '${h}h ${mins}m overdue' : '${h}h overdue';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCCBB), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE74C3C).withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.color, size: 27),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                      fontSize: 15, color: Color(0xFF9999AA)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Right: time + badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.time,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: item.color,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEEB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 14, color: Color(0xFFE74C3C)),
                    const SizedBox(width: 4),
                    Text(
                      _overdueLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE74C3C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── UPCOMING EVENT CARD ──────────────────────────────────────────────────────
class _UpcomingEventCard extends StatelessWidget {
  final ScheduleItem item;
  const _UpcomingEventCard({required this.item});

  String get _repeatLabel {
    switch (item.repeat) {
      case 'Daily':   return 'Every day';
      case 'Weekly':  return 'Every week';
      case 'Monthly': return 'Every month';
      default:        return item.repeat;
    }
  }

  @override
  Widget build(BuildContext context) {
    const purple     = Color(0xFF9B59B6);
    const purpleBg   = Color(0xFFF3EEFF);
    const purpleBorder = Color(0xFFD9BBFF);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: purpleBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: purple.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.color, size: 24),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF9999AA)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Right: time + repeat badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.time,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: item.color,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: purpleBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.repeat_rounded,
                        size: 13, color: purple),
                    const SizedBox(width: 4),
                    Text(
                      _repeatLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: purple,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── EMPTY STATE CARD ─────────────────────────────────────────────────────────
class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _EmptyCard({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── LOCATION CHECKPOINT MODEL (kept for API compatibility) ──────────────────
class LocationCheckpoint {
  final String time;
  final String placeName;
  final String address;
  final IconData icon;
  final Color color;
  final bool isCurrentLocation;

  const LocationCheckpoint({
    required this.time,
    required this.placeName,
    required this.address,
    required this.icon,
    required this.color,
    this.isCurrentLocation = false,
  });
}