// presentation/games/session_result_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/session_analysis.dart';
import '../../domain/usecases/finish_session.dart';
import '../../domain/usecases/finish_session.provider.dart';

/// Estado null = todavía no se ha enviado ninguna sesión. Así una pantalla
/// puede navegar al resultado cuando el estado deja de ser null, sin
/// dispararse por error al construirse (mismo problema que tuvimos en el registro).
class SessionResultNotifier extends AsyncNotifier<SessionResult?> {
  @override
  Future<SessionResult?> build() async => null;

  Future<void> submitSession(Session session) async {
    state = const AsyncLoading();
    final finishSession = ref.read(finishSessionProvider);
    state = await AsyncValue.guard(
      () => finishSession(FinishSessionParams(session)),
    );
  }
}

final sessionResultProvider =
    AsyncNotifierProvider<SessionResultNotifier, SessionResult?>(
  SessionResultNotifier.new,
);