// lib/domain/usecases/finish_session.provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/session_analyzer.provider.dart';
import '../../data/repositories/session_repository_impl.provider.dart';
import 'finish_session.dart';

final finishSessionProvider = Provider<FinishSession>((ref) {
  return FinishSession(
    ref.watch(sessionRepositoryProvider),
    ref.watch(sessionAnalyzerProvider),
  );
});