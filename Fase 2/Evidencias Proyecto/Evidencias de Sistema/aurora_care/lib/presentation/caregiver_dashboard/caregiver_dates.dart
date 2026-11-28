class CaregiverDates {
  CaregiverDates._();

  static const List<String> monthNames = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  /// El cuidador ve el historial de los últimos 28 días (caregiver_history).
  static const int daysOfHistory = 28;

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime addDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  static DateTime startOfWeek(DateTime date) {
    final day = dateOnly(date);
    return addDays(day, -(day.weekday - DateTime.monday));
  }

  static DateTime get currentWeekStart => startOfWeek(DateTime.now());

  static DateTime get oldestWeekStart =>
      startOfWeek(addDays(dateOnly(DateTime.now()), -(daysOfHistory - 1)));

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isCurrentWeek(DateTime weekStart) =>
      isSameDay(weekStart, currentWeekStart);

  static String capitalize(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  static String monthYear(DateTime date) =>
      '${capitalize(monthNames[date.month - 1])} ${date.year}';

  static String weekLabel(DateTime weekStart) {
    final end = addDays(weekStart, 6);
    final startMonth = monthNames[weekStart.month - 1];
    final endMonth = monthNames[end.month - 1];

    if (weekStart.month == end.month) {
      return 'Semana del ${weekStart.day} al ${end.day} de $endMonth';
    }
    return 'Semana del ${weekStart.day} de $startMonth '
        'al ${end.day} de $endMonth';
  }
}
