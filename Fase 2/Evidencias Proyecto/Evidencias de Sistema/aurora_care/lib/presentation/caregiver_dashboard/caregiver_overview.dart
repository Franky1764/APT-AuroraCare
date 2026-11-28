// lib/presentation/caregiver_dashboard/caregiver_overview.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../games/game_catalog.dart';
import '../profile/profile_portrait.dart';
import 'caregiver_calendar.dart';
import 'caregiver_history.dart';
import 'caregiver_report_screen.dart';
import 'caregiver_signal.dart';
import 'shared_practice_provider.dart';
import 'widgets/caregiver_animations.dart';

/// Panel del cuidador con el diseño de Figma (caregiver-dashboard, nodo
/// 5:773): tarjeta de estado de la persona, «Actividad reciente» y botón
/// «Ver reporte de progreso» (SCRUM-32).
///
/// Lee el MISMO resumen compartido que SharedPracticeCard
/// (shared_practice_provider.dart); no cambia cómo se entrega la
/// información del vínculo. No muestra puntajes ni porcentajes.
class CaregiverOverview extends ConsumerWidget {
  const CaregiverOverview({super.key, required this.onOpenReport});

  final VoidCallback onOpenReport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(sharedPracticeLinkProvider);
    final token = link.valueOrNull;
    final summary = token == null
        ? null
        : ref.watch(sharedPracticeSummaryProvider(token));
    final data = summary?.valueOrNull;

    if (link.hasError || summary?.hasError == true) {
      return const _MessageCard(
        'No pudimos consultar la actividad en este momento.',
      );
    }
    if (link.isLoading || summary?.isLoading == true) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (token == null) {
      return const _MessageCard('No hay un vínculo activo.');
    }
    if (data == null) {
      return const _MessageCard(
        'Aún no hay actividad disponible. Si se vincularon antes de esta '
        'función, generen un nuevo código desde el perfil de la persona mayor.',
      );
    }

    // SCRUM-33: guarda cada práctica nueva en el historial de 28 días.
    ref.watch(caregiverAreaHistoryProvider);

    final now = DateTime.now();
    final published = _date(data['publishedAt']);
    final fresh = published != null && now.difference(published).inDays < 28;
    final activities = [
      for (final (key, label) in _areas)
        if (data[key] case final Map area when (area['count'] as int? ?? 0) > 0)
          _Activity.from(key, label, area, fresh: fresh),
    ]..sort((a, b) => (b.at ?? DateTime(0)).compareTo(a.at ?? DateTime(0)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeSlideIn(
          index: 1,
          child: _SeniorStatusCard(
            lastPractice: _date(data['lastPracticeAt']),
            status: _GeneralStatus.from(activities),
          ),
        ),
        const SizedBox(height: 24),
        FadeSlideIn(
          index: 2,
          child: const _SectionTitle(
            icon: Icons.bolt_rounded,
            title: 'Actividad reciente',
            subtitle: 'La última práctica de cada área',
          ),
        ),
        const SizedBox(height: 12),
        if (activities.isEmpty)
          Text(
            'Aún no hay prácticas recientes registradas.',
            style: AppTextStyles.bodySecondary,
          ),
        for (var i = 0; i < activities.length; i++) ...[
          _ActivityReveal(
            index: i,
            color: activities[i].signal.color,
            child: _ActivityTile(activity: activities[i]),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 20),
        const FadeSlideIn(index: 4, child: CaregiverActivityCalendar()),
        const SizedBox(height: 16),
        FadeSlideIn(
          index: 5,
          child: OutlinedButton.icon(
            onPressed: onOpenReport,
            icon: const Icon(Icons.show_chart),
            label: const Text('Ver reporte de progreso'),
          ),
        ),
        const SizedBox(height: 12),
        FadeSlideIn(
          index: 6,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              caregiverPageRoute<void>(const CaregiverHistoryScreen()),
            ),
            icon: const Icon(Icons.timeline_rounded),
            label: const Text('Ver historial (28 días)'),
          ),
        ),
      ],
    );
  }
}

/// Nombre para el saludo del cuidador: si la cuenta solo tiene el correo,
/// usa la parte antes de la @ con mayúscula inicial.
String caregiverGreetingName(String? raw) {
  final value = raw?.trim() ?? '';
  final name = value.contains('@') ? value.split('@').first : value;
  if (name.isEmpty) return '';
  return name[0].toUpperCase() + name.substring(1);
}

/// Entrada notable de cada actividad: llega desde la derecha con un
/// pequeño rebote, una tras otra, y su borde se ilumina un momento.
class _ActivityReveal extends StatelessWidget {
  const _ActivityReveal({
    required this.index,
    required this.color,
    required this.child,
  });

  final int index;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = 0.15 * index;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 900 + 250 * index),
      builder: (context, value, child) {
        final local = ((value - delay) / (1 - delay)).clamp(0.0, 1.0);
        final move = Curves.easeOutBack.transform(local);
        final glow = 4 * local * (1 - local);
        return Opacity(
          opacity: Curves.easeOut.transform(local),
          child: Transform.translate(
            offset: Offset(60 * (1 - move), 0),
            child: Transform.scale(
              scale: 0.92 + 0.08 * move,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45 * glow),
                      blurRadius: 16 * glow,
                      spreadRadius: 2 * glow,
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}

const _areas = [
  ('memoria', 'Memoria'),
  ('atencion', 'Atención'),
  ('praxias', 'Motricidad'),
];

DateTime? _date(Object? value) =>
    value is Timestamp ? value.toDate().toLocal() : null;

String _gameTitle(String? gameType) =>
    gameCatalog.values
        .expand((games) => games)
        .where((game) => game.gameType == gameType)
        .firstOrNull
        ?.title ??
    'Ejercicio registrado';

/// «Hoy, 10:15», «Ayer, 16:30» o «24 nov, 11:20».
String practiceDateLabel(DateTime at, DateTime now) {
  const months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sept', 'oct', 'nov', 'dic',
  ];
  final time =
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
  final today = DateUtils.dateOnly(now);
  final day = DateUtils.dateOnly(at);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hoy, $time';
  if (diff == 1) return 'Ayer, $time';
  return '${at.day} ${months[at.month - 1]}, $time';
}

/// «Practicó hoy», «Practicó ayer» o «Practicó hace N días».
String lastPracticeLabel(DateTime? at, DateTime now) {
  if (at == null) return 'Aún no hay prácticas registradas';
  final diff = DateUtils.dateOnly(now).difference(DateUtils.dateOnly(at)).inDays;
  if (diff <= 0) return 'Practicó hoy';
  if (diff == 1) return 'Practicó ayer';
  return 'Practicó hace $diff días';
}

class _Activity {
  const _Activity({
    required this.key,
    required this.area,
    required this.game,
    required this.at,
    required this.signal,
  });

  factory _Activity.from(
    String key,
    String label,
    Map area, {
    required bool fresh,
  }) => _Activity(
    key: key,
    area: label,
    game: _gameTitle(area['latestGame'] as String?),
    at: _date(area['latestAt']),
    signal: CaregiverSignal.fromSummary(area['trend'], fresh: fresh),
  );

  final String key;
  final String area;
  final String game;
  final DateTime? at;
  final CaregiverSignal signal;
}

/// Estado general de la tarjeta de la persona, sin números.
class _GeneralStatus {
  const _GeneralStatus(this.text, this.color, this.background, this.icon);

  factory _GeneralStatus.from(List<_Activity> activities) {
    final signals = activities.map((a) => a.signal).toSet();
    if (signals.contains(CaregiverSignal.revisar) ||
        signals.contains(CaregiverSignal.atencion)) {
      final s = CaregiverSignal.atencion;
      return _GeneralStatus(
        'Algunas partidas recientes tuvieron resultados más bajos',
        s.color,
        s.background,
        s.icon,
      );
    }
    if (signals.contains(CaregiverSignal.mejora)) {
      final s = CaregiverSignal.mejora;
      return _GeneralStatus(
        'En general, muestra avances',
        s.color,
        s.background,
        s.icon,
      );
    }
    if (signals.contains(CaregiverSignal.estable)) {
      return _GeneralStatus(
        'En general, se mantiene bien',
        AppColors.success,
        AppColors.successBackground,
        Icons.check_circle,
      );
    }
    final s = CaregiverSignal.inicial;
    return _GeneralStatus(
      activities.isEmpty
          ? 'Aún no hay prácticas para resumir'
          : 'Seguimiento inicial: aún faltan partidas para ver una tendencia',
      s.color,
      s.background,
      s.icon,
    );
  }

  final String text;
  final Color color;
  final Color background;
  final IconData icon;
}

IconData _areaIcon(String key) => switch (key) {
  'memoria' => Icons.psychology_outlined,
  'atencion' => Icons.center_focus_strong_outlined,
  _ => Icons.back_hand_outlined,
};

const _weekdays = [
  'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
];
const _monthsLong = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
  'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// «Lunes 10 de noviembre».
String todayLongLabel(DateTime d) =>
    '${_weekdays[d.weekday - 1]} ${d.day} de ${_monthsLong[d.month - 1]}';

/// Encabezado del panel: degradado con los colores del tema, saludo,
/// fecha y la foto o avatar del cuidador (abre Configuración).
class CaregiverGreetingHeader extends StatelessWidget {
  const CaregiverGreetingHeader({
    super.key,
    required this.name,
    required this.onOpenSettings,
  });

  final String name;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final onPrimary = AppColors.textOnPrimary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
        ),
        child: Stack(
          children: [
            // Círculos decorativos suaves.
            Positioned(
              right: -40,
              top: -50,
              child: _Bubble(size: 160, color: onPrimary, alpha: 0.10),
            ),
            Positioned(
              left: -30,
              bottom: -60,
              child: _Bubble(size: 130, color: onPrimary, alpha: 0.07),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hola 👋',
                          style: AppTextStyles.body.copyWith(
                            color: onPrimary.withValues(alpha: 0.9),
                          ),
                        ),
                        // Con texto grande (A+) el nombre se achica para
                        // caber completo en vez de cortarse (H70).
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            name.isEmpty ? 'Bienvenido' : name,
                            maxLines: 1,
                            style: AppTextStyles.greeting.copyWith(
                              color: onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _HeaderPill(
                              icon: Icons.volunteer_activism_outlined,
                              text: 'Cuidador de su familiar',
                            ),
                            _HeaderPill(
                              icon: Icons.today_outlined,
                              text: todayLongLabel(DateTime.now()),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Tooltip(
                    message: 'Configuración',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onOpenSettings,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: onPrimary, width: 2.5),
                        ),
                        child: ProfilePortrait(
                          initial: name.isEmpty ? '' : name[0].toUpperCase(),
                          radius: 28,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.color, required this.alpha});

  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: alpha),
    ),
  );
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final onPrimary = AppColors.textOnPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: onPrimary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: onPrimary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text, style: AppTextStyles.tag.copyWith(color: onPrimary)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.cardTitle.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(subtitle, style: AppTextStyles.bodySecondary),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tarjeta de la persona: última práctica y estado general, sin números.
class _SeniorStatusCard extends StatelessWidget {
  const _SeniorStatusCard({required this.lastPractice, required this.status});

  final DateTime? lastPractice;
  final _GeneralStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GentlePulse(
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: AppColors.textOnPrimary,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Su familiar',
                      style: AppTextStyles.cardTitle.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_available_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              lastPracticeLabel(lastPractice, DateTime.now()),
                              style: AppTextStyles.tag.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: status.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                PopIn(
                  index: 3,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(status.icon, color: status.color, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estado general',
                        style: AppTextStyles.tag.copyWith(
                          color: status.color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        status.text,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity});

  final _Activity activity;

  @override
  Widget build(BuildContext context) {
    final signal = activity.signal;
    final at = activity.at;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          caregiverPageRoute<void>(
            CaregiverAreaDetailScreen(
              areaKey: activity.key,
              label: activity.area,
              icon: _areaIcon(activity.key),
            ),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Franja del color de la señal.
                Container(width: 6, color: signal.color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _areaIcon(activity.key),
                            color: AppColors.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activity.game,
                                style: AppTextStyles.cardTitle.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  activity.area,
                                  if (at != null)
                                    practiceDateLabel(at, DateTime.now()),
                                ].join(' · '),
                                style: AppTextStyles.bodySecondary,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: signal.background,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      signal.icon,
                                      size: 15,
                                      color: signal.color,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        signal.label,
                                        style: AppTextStyles.tag.copyWith(
                                          color: signal.color,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, style: AppTextStyles.body),
      ),
    );
  }
}
