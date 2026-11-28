import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/session_info.dart';

/// Estado de acceso en memoria, independiente de las métricas cognitivas.
class NavigationSession {
  const NavigationSession({
    this.initialized = false,
    this.session,
    this.fallbackName = 'Usuario',
  });
  final bool initialized;
  final SessionInfo? session;
  final String fallbackName;

  String get userName {
    final name = session?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final emailPrefix = session?.email.split('@').first.trim();
    return emailPrefix != null && emailPrefix.isNotEmpty
        ? emailPrefix
        : fallbackName;
  }
}

class NavigationSessionNotifier extends Notifier<NavigationSession> {
  @override
  NavigationSession build() => const NavigationSession();

  void restore(SessionInfo? session, {String fallbackName = 'Usuario'}) {
    state = NavigationSession(
      initialized: true,
      session: session,
      fallbackName: fallbackName,
    );
  }

  void acceptDisclaimer() {
    final s = state.session;
    if (s == null) return;
    restore(
      SessionInfo(
        role: s.role,
        uid: s.uid,
        email: s.email,
        displayName: s.displayName,
        consentGiven: s.consentGiven,
        currentMode: s.currentMode,
        disclaimerAccepted: true,
      ),
      fallbackName: state.fallbackName,
    );
  }

  void selectMode(int mode) {
    final s = state.session;
    if (s == null) return;
    restore(
      SessionInfo(
        role: s.role,
        uid: s.uid,
        email: s.email,
        displayName: s.displayName,
        consentGiven: s.consentGiven,
        currentMode: mode,
        disclaimerAccepted: s.disclaimerAccepted,
      ),
      fallbackName: state.fallbackName,
    );
  }

  void clear() => state = const NavigationSession(initialized: true);
}

final navigationSessionProvider =
    NotifierProvider<NavigationSessionNotifier, NavigationSession>(
      NavigationSessionNotifier.new,
    );
