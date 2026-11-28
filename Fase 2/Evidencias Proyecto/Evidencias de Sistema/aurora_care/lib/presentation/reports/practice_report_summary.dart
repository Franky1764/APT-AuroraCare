import '../../domain/entities/cognitive_metrics.dart';
import '../../domain/entities/progress_report.dart';
import '../../domain/entities/session.dart';
import '../games/game_catalog.dart';
import '../progress/progress_providers.dart';

String reportAreaName(String domain) => switch (domain) {
  'memoria' => 'Memoria',
  'atencion' => 'Atención',
  _ => 'Motricidad',
};
String reportDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}

class PracticeReportGroup {
  PracticeReportGroup(this.sessions);
  final List<Session> sessions;
  Session get first => sessions.first;
  String get title =>
      gameCatalog.values
          .expand((games) => games)
          .where((game) => game.gameType == first.gameType)
          .firstOrNull
          ?.title ??
      'Ejercicio registrado';
  String get label => '$title · Nivel ${first.nivel.label}';

  List<String> get results {
    final metrics = sessions.map((session) => session.metrics).toList();
    String? average(String label, Iterable<num> values, String unit) {
      final valid = values
          .where((value) => value.isFinite && value >= 0)
          .toList();
      if (valid.isEmpty) return null;
      final mean =
          valid.fold<double>(0, (sum, value) => sum + value) / valid.length;
      return '$label: ${mean.toStringAsFixed(1).replaceAll('.', ',')} $unit '
          '(${valid.length} ${valid.length == 1 ? 'registro' : 'registros'}).';
    }

    final rows = <String?>[];
    if (metrics.every((m) => m is MemoriaMetrics)) {
      rows.add(
        average(
          'Aciertos promedio por partida',
          metrics
              .cast<MemoriaMetrics>()
              .map((m) => m.tasaAciertoPct)
              .where((v) => v <= 100),
          '%',
        ),
      );
    } else if (metrics.every((m) => m is AtencionMetrics)) {
      rows.add(
        average(
          'Tiempo promedio por partida para responder',
          metrics
              .cast<AtencionMetrics>()
              .where((m) => m.tiempoRespuestaMs > 0)
              .map((m) => m.tiempoRespuestaMs / 1000),
          'segundos',
        ),
      );
      rows.add(
        average(
          'Errores promedio por partida',
          metrics
              .cast<AtencionMetrics>()
              .map((m) => m.tasaErrorPct)
              .where((v) => v <= 100),
          '%',
        ),
      );
    } else {
      var completed = 0;
      var total = 0;
      var supported = 0;
      var hasActions = false;
      for (final metric in metrics) {
        final counts = switch (metric) {
          PhoneTouchMetrics() => (
            metric.completedTargets,
            metric.totalTargets,
            0,
          ),
          PhoneListMetrics() => (
            metric.completedSearches,
            metric.totalSearches,
            metric.searchesWithHelp,
          ),
          PhoneSwipeMetrics() => (
            metric.completedActions,
            metric.totalActions,
            metric.assistedActions,
          ),
          PhoneDragMetrics() => (
            metric.completedActions,
            metric.totalActions,
            metric.assistedActions,
          ),
          PhoneZoomMetrics() => (
            metric.completedActions,
            metric.totalActions,
            metric.assistedActions,
          ),
          _ => null,
        };
        if (counts != null &&
            counts.$1 >= 0 &&
            counts.$2 >= counts.$1 &&
            counts.$3 >= 0) {
          hasActions = true;
          completed += counts.$1;
          total += counts.$2;
          supported += counts.$3;
        }
      }
      if (hasActions) {
        rows.add('Acciones completadas: $completed de $total.');
        if (metrics.first is! PhoneTouchMetrics) {
          rows.add('Acciones con apoyo: $supported.');
        }
      } else if (metrics.every((m) => m is PraxiasMetrics)) {
        rows.add(
          average(
            'Precisión promedio del recorrido por partida',
            metrics
                .cast<PraxiasMetrics>()
                .map((m) => m.precisionPct)
                .where((v) => v <= 100),
            '%',
          ),
        );
      }
    }
    final available = rows.whereType<String>().toList();
    return available.isEmpty
        ? ['Prácticas registradas; sin medidas resumibles disponibles.']
        : available;
  }
}

class PracticeReportSummary {
  PracticeReportSummary(this.summary, this.now);
  final ProgressSummary summary;
  final DateTime now;
  List<Session> get sessions =>
      summary.domains.expand((area) => area.recordedSessions).toList()
        ..sort((a, b) => b.endTime.compareTo(a.endTime));
  int get count =>
      summary.domains.fold(0, (total, area) => total + area.sessions);
  int get days => sessions
      .map((s) {
        final date = s.startTime.toLocal();
        return (date.year, date.month, date.day);
      })
      .toSet()
      .length;
  int get areas => summary.domains.where((area) => area.sessions > 0).length;
  String get overview => count == 0
      ? 'Su informe estará disponible desde su primera práctica.'
      : 'Durante el período realizó $count ${count == 1 ? 'práctica' : 'prácticas'}'
            '${sessions.isEmpty ? '' : ' en $days ${days == 1 ? 'día' : 'días'}'}. '
            'Practicó $areas ${areas == 1 ? 'área' : 'áreas'}.'
            '${sessions.isEmpty ? '' : ' Su última práctica fue el ${reportDate(sessions.first.endTime)}.'}';
  List<PracticeReportGroup> groupsFor(DomainSummary area) {
    // Separamos también versiones y tipos de métricas para no mezclar ejercicios distintos.
    final groups = <Object, List<Session>>{};
    for (final session in area.recordedSessions) {
      final version = switch (session.metrics) {
        PraxiasMetrics(:final tracingVersion, :final connectionVersion) => (
          tracingVersion,
          connectionVersion,
        ),
        _ => (null, null),
      };
      final key = (
        session.gameType,
        session.nivel,
        session.metrics.runtimeType,
        version,
      );
      groups.putIfAbsent(key, () => []).add(session);
    }
    return groups.values.map(PracticeReportGroup.new).toList()..sort((a, b) {
      final game = a.title.compareTo(b.title);
      return game != 0
          ? game
          : a.first.nivel.value.compareTo(b.first.nivel.value);
    });
  }

  String evolution(DomainSummary area) =>
      area.trend == ProgressTrend.insufficient
      ? 'Registro inicial disponible para futuras comparaciones.'
      : '${area.statusText} en ${area.comparableSessions} partidas comparables del mismo juego, nivel y versión.';

  /// Contenido estructurado para maquetar tablas sin interpretar texto libre.
  List<Map<String, Object>> pdfSections({
    String observations = '',
    ProgressReport? narrative,
  }) => [
    {
      'title': 'Resumen general',
      'body':
          'Período: ${reportDate(now.subtract(const Duration(days: 28)))} al ${reportDate(now)}.\n\n$overview',
      'observations': observations.trim().isEmpty
          ? 'Sin observaciones añadidas.'
          : observations.trim(),
    },
    for (final area in summary.domains)
      {
        'title': reportAreaName(area.domain),
        'body':
            '${area.sessions} ${area.sessions == 1 ? 'sesión registrada' : 'sesiones registradas'}.',
        'rows': [
          for (final group in groupsFor(area))
            {
              'game': group.title,
              'level': group.first.nivel.label,
              'count': '${group.sessions.length}',
              'results': group.results.join('\n'),
            },
        ],
        'note': 'Promedios por partida del mismo ejercicio y nivel. Cada resultado indica cuántos registros tienen una medida válida.',
        'context': area.sessions > 0
            ? evolution(area)
            : 'Sin prácticas en este período.',
      },
    if (narrative != null && narrative.source != 'dispositivo')
      {
        'title': 'Resumen complementario',
        'body': narrative.text.replaceAll(reportDisclaimer, '').trim(),
      },
  ];

  String pdfText({String observations = '', ProgressReport? narrative}) => [
    'INFORME DE ACTIVIDAD Y RESULTADOS',
    'Período: ${reportDate(now.subtract(const Duration(days: 28)))} al ${reportDate(now)}.',
    '',
    'RESUMEN GENERAL',
    overview,
    '',
    'RESULTADOS POR ÁREA',
    for (final area in summary.domains) ...[
      reportAreaName(area.domain),
      '${area.sessions} ${area.sessions == 1 ? 'sesión registrada' : 'sesiones registradas'}.',
      for (final group in groupsFor(area)) ...[
        '${group.label} · ${group.sessions.length} ${group.sessions.length == 1 ? 'práctica' : 'prácticas'}',
        ...group.results,
      ],
      if (area.sessions > 0) evolution(area),
      '',
    ],
    'Los promedios describen las partidas de cada ejercicio y nivel; no se comparan con otras personas.',
    '',
    if (narrative != null && narrative.source != 'dispositivo') ...[
      'RESUMEN COMPLEMENTARIO',
      narrative.text.replaceAll(reportDisclaimer, '').trim(),
      '',
    ],
    'OBSERVACIONES DE LA PERSONA',
    observations.trim().isEmpty
        ? 'Sin observaciones añadidas.'
        : observations.trim(),
    '',
    reportDisclaimer,
  ].join('\n');
}
