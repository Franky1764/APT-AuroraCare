import 'package:flutter/material.dart';

import 'caregiver_report_screen.dart';
import 'caregiver_week_data.dart';

/// Detalle de actividad de un área (H67). Ya no usa datos de ejemplo:
/// muestra la misma pantalla de detalle del reporte, que lee
/// `caregiver_summaries` del vínculo activo.
class ActivityDetailScreen extends StatelessWidget {
  const ActivityDetailScreen({super.key, required this.areaKey});

  /// 'memoria', 'atencion' o 'praxias'.
  final String areaKey;

  @override
  Widget build(BuildContext context) {
    final (key, label, icon) = caregiverArea(areaKey);
    return CaregiverAreaDetailScreen(areaKey: key, label: label, icon: icon);
  }
}
