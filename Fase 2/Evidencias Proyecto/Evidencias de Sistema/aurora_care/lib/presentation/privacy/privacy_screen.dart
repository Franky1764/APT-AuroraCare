import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/router/app_routes.dart';
import '../../core/router/navigation_session.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/account_role.dart';
import '../../domain/entities/privacy_data.dart';
import '../../domain/entities/privacy_request.dart';
import '../../domain/entities/session_info.dart';
import '../games/shared/game_providers.dart';
import '../games/shared/metrics_consent_providers.dart';
import '../progress/progress_providers.dart';
import '../profile/profile_portrait.dart';
import 'privacy_providers.dart';
import 'privacy_policy_screen.dart';
import 'privacy_request_screen.dart';

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String message,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(message)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _correctName(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    final session = ref.read(navigationSessionProvider).session;
    final editor = TextEditingController(text: name);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Corregir mi nombre'),
        content: TextField(
          controller: editor,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (editor.text.trim().isNotEmpty) {
                Navigator.pop(context, editor.text.trim());
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    // El campo puede seguir animándose durante el cierre del diálogo.
    WidgetsBinding.instance.addPostFrameCallback((_) => editor.dispose());
    if (value == null ||
        !context.mounted ||
        ref.read(navigationSessionProvider).session?.uid != session?.uid) {
      return;
    }
    final saved = await ref
        .read(privacyActionProvider.notifier)
        .run((repository) => repository.correctName(value));
    if (!saved ||
        session == null ||
        ref.read(navigationSessionProvider).session?.uid != session.uid) {
      return;
    }
    ref
        .read(navigationSessionProvider.notifier)
        .restore(
          SessionInfo(
            uid: session.uid,
            email: session.email,
            displayName: value,
            role: session.role,
            consentGiven: session.consentGiven,
            currentMode: session.currentMode,
            disclaimerAccepted: session.disclaimerAccepted,
          ),
        );
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      '¿Retirar mi consentimiento?',
      'Se retirará el acceso de su cuidador al resumen y se detendrá el '
          'guardado de nuevas prácticas. Su historial se conserva. '
          'Para registrar prácticas de nuevo, tendrá que volver a autorizarlo.',
    );
    if (!confirmed || !context.mounted) return;
    final uid = ref.read(navigationSessionProvider).session?.uid;
    await ref
        .read(privacyActionProvider.notifier)
        .run((repository) => repository.withdrawConsent());
    if (uid != null) {
      ref.invalidate(metricsConsentProvider(uid));
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    PrivacyDeletion kind,
  ) async {
    final owner = ref.read(navigationSessionProvider).session?.uid;
    final password = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          kind == PrivacyDeletion.history
              ? '¿Borrar mi historial?'
              : '¿Eliminar mi cuenta?',
        ),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              kind == PrivacyDeletion.history
                  ? 'Se borrarán las prácticas del perfil disponible en este teléfono, '
                        'sus copias en la nube y «Mis recuerdos». Se retirará el vínculo '
                        'con su cuidador. Su cuenta seguirá disponible.'
                  : 'Se eliminarán su cuenta, los vínculos y los datos del perfil '
                        'disponible en este teléfono y sus copias en la nube.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Esta acción es irreversible y necesita conexión. Los PDF '
              'que haya guardado o enviado se conservan fuera de AuroraCare.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Si usó otros dispositivos o hay un historial sin asignar, '
              'contacte al equipo de privacidad para revisar esos datos.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: password,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Confirme su contraseña',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              if (password.text.isNotEmpty) {
                Navigator.pop(context, password.text);
              }
            },
            child: const Text('Confirmar eliminación'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => password.dispose());
    if (value == null ||
        !context.mounted ||
        ref.read(navigationSessionProvider).session?.uid != owner) {
      return;
    }
    final uid = ref.read(navigationSessionProvider).session?.uid;
    final deleted = await ref
        .read(privacyActionProvider.notifier)
        .run((repository) => repository.delete(kind, value));
    if (!deleted) return;
    ref.invalidate(activeProfileProvider);
    ref.invalidate(progressProvider);
    ref.invalidate(profilePortraitProvider);
    if (uid != null) {
      ref.invalidate(metricsConsentProvider(uid));
    }
    if (!context.mounted) return;
    if (kind == PrivacyDeletion.account) {
      ref.read(navigationSessionProvider.notifier).clear();
      context.go(AppRoutes.welcome);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Se borró el historial de este perfil. Su cuenta sigue disponible.',
          ),
        ),
      );
    }
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    PrivacyData data,
  ) async {
    if (!await _confirm(
      context,
      'Guardar una copia de mis datos',
      'El archivo incluye sus datos de cuenta y los resultados disponibles. '
          'Guárdelo en un lugar de confianza. Podrá abrirlo como un archivo JSON.',
    )) {
      return;
    }
    if (!context.mounted) return;
    await ref.read(privacyActionProvider.notifier).run((_) async {
      final saved = await ref.read(privacyActionsProvider).saveData(data.json);
      if (saved && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Su copia se guardó.')));
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(privacyActionProvider);
    final pending = ref.watch(pendingPrivacyDeletionProvider);
    final data = pending == null
        ? ref.watch(privacyDataProvider)
        : const AsyncLoading<PrivacyData>();
    final session = ref.watch(navigationSessionProvider).session;
    final busy = action.isLoading;
    return PopScope(
      canPop: !busy && pending == null,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis datos y privacidad'),
          automaticallyImplyLeading: !busy && pending == null,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Usted decide sobre sus datos',
                style: AppTextStyles.heading,
              ),
              const SizedBox(height: 12),
              const Text(
                'Consulte sus datos, corrija su nombre y gestione '
                'su consentimiento. También puede solicitar acceso, '
                'rectificación, supresión, oposición, portabilidad o bloqueo '
                'al equipo de privacidad.',
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PrivacyPolicyScreen(),
                        ),
                      ),
                icon: const Icon(Icons.policy_outlined),
                label: const Text('Leer la política de privacidad'),
              ),
              if (busy) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
                const Text('Procesando su solicitud…'),
              ],
              if (action.hasError) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    action.error is FirebaseAuthException &&
                            ['wrong-password', 'invalid-credential'].contains(
                              (action.error as FirebaseAuthException).code,
                            )
                        ? 'La contraseña no coincide. Revísela e inténtelo de nuevo.'
                        : 'No pudimos completar la operación. Revise la conexión '
                              'e inténtelo de nuevo. Si continúa, contacte al equipo de privacidad.',
                    style: AppTextStyles.body.copyWith(color: AppColors.error),
                  ),
                ),
              ],
              if (pending != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Hay una eliminación pendiente. Puede reanudarla para terminar '
                  'de borrar los datos.',
                ),
                FilledButton(
                  onPressed: busy ? null : () => _delete(context, ref, pending),
                  child: const Text('Reanudar eliminación'),
                ),
              ] else ...[
                const SizedBox(height: 16),
                data.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'No pudimos consultar sus datos. Revise su conexión.',
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => ref.invalidate(privacyDataProvider),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                  data: (data) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Datos de mi cuenta',
                            style: AppTextStyles.cardTitle,
                          ),
                          const SizedBox(height: 8),
                          SelectableText(data.name),
                          SelectableText(data.email),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => _correctName(context, ref, data.name),
                            child: const Text('Corregir mi nombre'),
                          ),
                          OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () => _export(context, ref, data),
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Descargar mis datos'),
                          ),
                          const Text(
                            'La copia incluye los datos de cuenta y el '
                            'historial disponible en este dispositivo y su perfil en la nube.',
                          ),
                          if (data.hasUnassignedHistory)
                            const Text(
                              'Hay un historial anterior sin titular confirmado. '
                              'El equipo de privacidad puede ayudarle a revisarlo.',
                            ),
                          if (session?.role == AccountRole.elder) ...[
                            const SizedBox(height: 12),
                            Text(
                              data.consent
                                  ? 'Guardado de métricas autorizado'
                                  : 'Guardado de métricas sin autorizar',
                            ),
                            if (data.consent)
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => _withdraw(context, ref),
                                child: const Text('Retirar mi consentimiento'),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (session?.role == AccountRole.elder)
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => _delete(context, ref, PrivacyDeletion.history),
                    child: const Text(
                      'Borrar mi historial y conservar mi cuenta',
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  onPressed: busy
                      ? null
                      : () => _delete(context, ref, PrivacyDeletion.account),
                  child: const Text('Eliminar mi cuenta y mis datos'),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Contactar al equipo de privacidad',
                style: AppTextStyles.cardTitle,
              ),
              const SizedBox(height: 8),
              const SelectableText(
                'Responsable: Daniela Castillo Gallegos\n'
                'Santiago de Chile\n'
                '${PrivacyRequest.contact}',
              ),
              const SizedBox(height: 8),
              for (final right in PrivacyRight.values)
                TextButton(
                  onPressed: busy
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PrivacyRequestScreen(right: right),
                          ),
                        ),
                  child: Text(
                    'Solicitar ${right.subject.toLowerCase()}',
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
