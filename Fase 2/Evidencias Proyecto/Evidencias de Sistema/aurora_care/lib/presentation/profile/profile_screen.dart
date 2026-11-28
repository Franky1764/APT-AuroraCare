// lib/presentation/profile/profile_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/router/navigation_session.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/music_route_scope.dart';
import '../../core/audio/sound_effect.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/accessibility_providers.dart';
import '../../core/providers/sound_providers.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/auth_repository_impl.provider.dart';
import '../../data/sources/practice_feedback_platform.dart';
import '../home/home_flow.dart';
import '../caregiver_dashboard/caregiver_connection_provider.dart';
import '../onboarding/mode_selection_screen.dart';
import '../onboarding/welcome_flow.dart';
import '../shared/app_header_bar.dart';
import '../shared/current_mode_provider.dart';
import '../shared/change_usage_mode_provider.dart';
import 'caregiver_link_screen.dart';
import 'help_support_screen.dart';
import 'profile_portrait.dart';
import 'theme_selection_screen.dart';
import '../reports/progress_report_screen.dart';
import '../caregiver_dashboard/shared_practice_provider.dart';

/// Pantalla de perfil del adulto mayor.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.userName = 'Rosa García'});

  final String userName;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _updatingNotifications = false;

  Future<void> _tryVibration() async {
    final feedback = ref.read(practiceFeedbackPlatformProvider);
    final enabled = await feedback.touchFeedbackEnabled();
    if (!mounted) return;
    if (enabled == false) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Activar la vibración táctil'),
          content: const Text(
            'En los ajustes del teléfono, busque «Vibración táctil» '
            'o «Respuesta táctil». Al volver, puede probarla aquí.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                feedback.openSoundSettings();
              },
              child: const Text('Abrir ajustes de sonido'),
            ),
          ],
        ),
      );
      return;
    }
    await ref.read(vibrationLevelProvider.notifier).pulse();
  }

  Future<void> _setNotifications(bool value) async {
    setState(() => _updatingNotifications = true);
    try {
      final allowed = await ref
          .read(notificationsEnabledProvider.notifier)
          .set(value);
      if (!allowed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Si desea recibir avisos, permita las notificaciones de AuroraCare en Ajustes.',
            ),
            action: SnackBarAction(
              label: 'Abrir Ajustes',
              onPressed: () =>
                  ref.read(practiceFeedbackPlatformProvider).openSettings(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingNotifications = false);
    }
  }

  Future<void> _editPortrait() async {
    final account = ref.read(navigationSessionProvider).session?.uid;
    if (account == null) return;
    final selection = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Su foto de perfil', style: AppTextStyles.heading),
              const SizedBox(height: 6),
              Text(
                'Elija una imagen que le guste. Se guarda en este teléfono.',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, _PortraitAction.photo),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Elegir una foto'),
              ),
              const SizedBox(height: 16),
              Text('O elija un avatar', style: AppTextStyles.cardTitle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final avatar in ProfileAvatar.values)
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, avatar),
                      icon: Icon(avatar.icon),
                      label: Text(avatar.label),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, _PortraitAction.initial),
                child: const Text('Usar mi inicial'),
              ),
            ],
          ),
        ),
      ),
    );
    if (selection == null ||
        !mounted ||
        ref.read(navigationSessionProvider).session?.uid != account) {
      return;
    }
    final portrait = ref.read(profilePortraitProvider.notifier);
    try {
      if (selection == _PortraitAction.photo) {
        final allowed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('¿Abrir la galería?'),
            content: const Text(
              'AuroraCare solo podrá acceder a la foto que usted elija. '
              'Su foto de perfil se guardará en este teléfono.',
              textAlign: TextAlign.justify,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Abrir galería'),
              ),
            ],
          ),
        );
        if (allowed != true ||
            !mounted ||
            ref.read(navigationSessionProvider).session?.uid != account) {
          return;
        }
        await portrait.choosePhoto();
      } else {
        await portrait.chooseAvatar(
          selection is ProfileAvatar ? selection : null,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos cambiar su imagen. Inténtelo de nuevo.'),
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    final router = GoRouter.maybeOf(context);
    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cerrar la sesión. Inténtalo de nuevo.'),
        ),
      );
      return;
    }
    if (!mounted) return;
    unawaited(ref.read(soundServiceProvider).stopMusic());
    ref.read(navigationSessionProvider.notifier).clear();
    if (router != null) {
      router.go(AppRoutes.welcome);
      return;
    }
    // Las pantallas aisladas conservan el callback de navegación tradicional.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => buildWelcomeFlow()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.userName.isEmpty
        ? ''
        : widget.userName[0].toUpperCase();
    final isLargeText = ref.watch(textScaleProvider) > 1.0;
    final temaActual = ref.watch(themeProvider);
    final soundsEnabled = ref.watch(soundsEnabledProvider);
    final soundLevel = ref.watch(soundLevelProvider);
    final vibrationLevel = ref.watch(vibrationLevelProvider);
    final musicEnabled = ref.watch(musicEnabledProvider);
    final notificationsEnabled = ref.watch(notificationsEnabledProvider);
    final currentMode = ref.watch(currentModeProvider);
    if (currentMode == 3 &&
        ref.watch(navigationSessionProvider).session != null) {
      ref.watch(syncSharedPracticeProvider);
    }

    return MusicRouteScope(
      track: MusicTrack.menu,
      child: Scaffold(
        appBar: AppHeaderBar(
          showBackButton: true,
          onLogoTap: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => buildHomeScreen(widget.userName)),
          ),
          onBellTap: null,
        ),
        // El tamaño de texto grande ("A+") ahora es global: el toggle escribe
        // en textScaleProvider, y main.dart aplica el TextScaler a toda la
        // app vía MaterialApp.builder.
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text('Mi perfil', style: AppTextStyles.heading),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Tooltip(
                          message: 'Cambiar foto o avatar',
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _editPortrait,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ProfilePortrait(initial: initial, radius: 32),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: CircleAvatar(
                                    radius: 12,
                                    backgroundColor: AppColors.primaryLight,
                                    child: Icon(
                                      Icons.edit_outlined,
                                      size: 14,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            widget.userName,
                            style: AppTextStyles.cardTitle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tamaño de texto',
                            style: AppTextStyles.body,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _TextSizeToggle(
                          isLargeText: isLargeText,
                          onChanged: (value) {
                            ref
                                .read(textScaleProvider.notifier)
                                .set(value ? 1.3 : 1.0);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ThemeSelectionScreen(),
                        ),
                      );
                    },
                    child: Semantics(
                      button: true,
                      label:
                          'Tema, actual: ${temaActual.nombre}. Toque para cambiar.',
                      child: ExcludeSemantics(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Tema', style: AppTextStyles.body),
                                      Text(
                                        temaActual.nombre,
                                        style: AppTextStyles.bodySecondary,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _MuestraDeColores(paleta: temaActual.paleta),
                                const SizedBox(width: 8),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: SwitchListTile(
                    secondary: Icon(
                      Icons.volume_up_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text('Sonidos', style: AppTextStyles.body),
                    subtitle: const Text(
                      'Efectos de sonido durante los ejercicios.',
                    ),
                    value: soundsEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: (value) async {
                      await ref.read(soundsEnabledProvider.notifier).set(value);
                      if (value && mounted) {
                        await ref
                            .read(soundServiceProvider)
                            .play(SoundEffect.acierto1);
                      }
                    },
                  ),
                ),
                if (soundsEnabled) ...[
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: DropdownButtonFormField<int>(
                        initialValue: soundLevel,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Volumen de los efectos',
                        ),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('Bajo')),
                          DropdownMenuItem(value: 2, child: Text('Medio')),
                          DropdownMenuItem(value: 3, child: Text('Alto')),
                        ],
                        onChanged: (value) async {
                          if (value == null) return;
                          await ref
                              .read(soundLevelProvider.notifier)
                              .set(value);
                          if (mounted && ref.read(soundsEnabledProvider)) {
                            await ref
                                .read(soundServiceProvider)
                                .play(SoundEffect.acierto1);
                          }
                        },
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<int>(
                          initialValue: vibrationLevel,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Vibración en los ejercicios',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 0,
                              child: Text('Desactivada'),
                            ),
                            DropdownMenuItem(value: 1, child: Text('Suave')),
                            DropdownMenuItem(value: 2, child: Text('Fuerte')),
                          ],
                          onChanged: (value) async {
                            if (value == null) return;
                            await ref
                                .read(vibrationLevelProvider.notifier)
                                .set(value);
                            if (mounted && value != 0) await _tryVibration();
                          },
                        ),
                        if (vibrationLevel != 0)
                          TextButton(
                            onPressed: _tryVibration,
                            child: const Text('Probar vibración'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: SwitchListTile(
                    secondary: Icon(
                      Icons.music_note_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text('Música de fondo', style: AppTextStyles.body),
                    subtitle: const Text(
                      'Música suave mientras usa la aplicación.',
                    ),
                    value: musicEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: (value) async {
                      final sound = ref.read(soundServiceProvider);
                      await ref.read(musicEnabledProvider.notifier).set(value);
                      sound.setMusicEnabled(value);
                      if (value && mounted) {
                        await sound.playMusic(MusicTrack.menu);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: SwitchListTile(
                    secondary: Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.primary,
                    ),
                    title: Text('Notificaciones', style: AppTextStyles.body),
                    subtitle: const Text(
                      'Avisos de desafíos, práctica e informes. Puede desactivarlos cuando quiera.',
                    ),
                    value: notificationsEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: _updatingNotifications
                        ? null
                        : _setNotifications,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ModeSelectionScreen(
                            onModeSelected: (mode) =>
                                ref.read(changeUsageModeProvider)(mode),
                            isChangeMode: true,
                            initialMode: currentMode,
                            userName: widget.userName,
                          ),
                        ),
                      );
                    },
                    child: ListTile(
                      title: Text('Mi modo de uso', style: AppTextStyles.body),
                      subtitle: Text(
                        currentMode == 3
                            ? 'Jugar, ver mi progreso y conectar con un '
                                  'cuidador'
                            : 'Jugar y ver mi progreso',
                        style: AppTextStyles.bodySecondary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
                ),
                if (currentMode == 2 || currentMode == 3) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: const Text('Mi informe de progreso'),
                      subtitle: const Text('Consultar y guardar como PDF'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        final router = GoRouter.maybeOf(context);
                        if (router != null) {
                          router.push(AppRoutes.progressReport);
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ProgressReportScreen(),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
                if (currentMode == 3) ...[
                  const SizedBox(height: 12),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        final router = GoRouter.maybeOf(context);
                        if (router != null) {
                          router.push(AppRoutes.caregiverLink);
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const CaregiverLinkScreen(),
                            ),
                          );
                        }
                      },
                      child: ListTile(
                        title:
                            ref.watch(navigationSessionProvider).session == null
                            ? const Text('Vincular Cuidador')
                            : ref
                                  .watch(linkedCaregiverIdentityProvider)
                                  .when(
                                    data: (identity) => Text(
                                      identity.linked
                                          ? 'Cuidador vinculado'
                                          : 'Vincular Cuidador',
                                      style: AppTextStyles.body,
                                    ),
                                    loading: () =>
                                        const Text('Consultando cuidador…'),
                                    error: (_, _) =>
                                        const Text('Consultar vínculo'),
                                  ),
                        subtitle:
                            ref.watch(navigationSessionProvider).session == null
                            ? null
                            : ref
                                  .watch(linkedCaregiverIdentityProvider)
                                  .maybeWhen(
                                    data: (identity) => identity.linked
                                        ? Text(
                                            identity.name ?? 'Nombre pendiente. Pida a su cuidador que abra AuroraCare.',
                                          )
                                        : null,
                                    error: (_, _) => const Text(
                                      'No pudimos comprobar el vínculo.',
                                    ),
                                    orElse: () => null,
                                  ),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
                    title: Text('Mis datos y privacidad', style: AppTextStyles.body),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.privacy),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const HelpSupportScreen(),
                      ),
                    ),
                    child: ListTile(
                      title: Text('Ayuda y soporte', style: AppTextStyles.body),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Mismo estilo que el botón "Cerrar sesión" de
                // CaregiverSettingsScreen (presentation/caregiver_dashboard/),
                // para mantener consistencia visual entre ambos perfiles.
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    backgroundColor: AppColors.errorBackground,
                    side: BorderSide(color: AppColors.error, width: 2),
                  ),
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TextSizeToggle extends StatelessWidget {
  const _TextSizeToggle({required this.isLargeText, required this.onChanged});

  final bool isLargeText;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToggleOption(
          label: 'A',
          isSelected: !isLargeText,
          onTap: () => onChanged(false),
        ),
        const SizedBox(width: 8),
        _ToggleOption(
          label: 'A+',
          isSelected: isLargeText,
          onTap: () => onChanged(true),
        ),
      ],
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.primary : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(
              color: isSelected
                  ? AppColors.textOnPrimary
                  : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Muestra pequeña de los colores de un tema: el color primario como fondo
/// y el acento en una esquina, solo para que la persona reconozca el tema
/// visualmente. La opción nunca depende solo de esto para indicar cuál
/// está elegida — eso lo hacen el ícono de check y el texto "Seleccionado".
class _MuestraDeColores extends StatelessWidget {
  const _MuestraDeColores({required this.paleta});

  final AppPalette paleta;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: paleta.primary,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: paleta.accent,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _PortraitAction { photo, initial }
