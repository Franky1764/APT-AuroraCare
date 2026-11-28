import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../domain/repositories/session_analyzer.dart';
import 'api_session_analyzer.dart';

/// Dirección explícita por entorno: nunca se envían métricas a un host supuesto.
final sessionApiBaseUrlProvider = Provider<String>(
  (ref) => const String.fromEnvironment('AURORACARE_API_BASE_URL'),
);

final sessionAnalyzerProvider = Provider<SessionAnalyzer>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return ApiSessionAnalyzer(client, ref.watch(sessionApiBaseUrlProvider));
});
