// lib/presentation/onboarding/mode_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/usage_mode_exceptions.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/exceptions/caregiver_revocation_unavailable.dart';
import '../shared/current_mode_provider.dart';

/// Pantalla de selección de modo de uso (F3 — onboarding, SCRUM-119).
/// Quedan solo 2 modos (el Modo 1 "Solo jugar" fue eliminado por decisión
/// del equipo). También se usa para cambiar de modo desde el perfil
/// (isChangeMode: true).
class ModeSelectionScreen extends ConsumerStatefulWidget {
  const ModeSelectionScreen({
    super.key,
    required this.userName,
    this.initialMode,
    this.onModeSelected,
    this.isChangeMode = false,
  });

  /// Nombre real propagado desde RegisterScreen/LoginScreen, que viaja
  /// hacia HomeScreen cuando onModeSelected completa el guardado.
  final String userName;

  /// Modo (2 o 3) que se muestra resaltado al abrir la pantalla.
  /// Cualquier otro valor (incluido null) se trata como Modo 2.
  final int? initialMode;
  final Future<void> Function(int mode)? onModeSelected;

  /// true cuando se abre desde el perfil para cambiar de modo, en vez del
  /// flujo de onboarding post-registro.
  final bool isChangeMode;

  static int normalizeMode(int? mode) => mode == 3 ? 3 : 2;

  @override
  ConsumerState<ModeSelectionScreen> createState() =>
      _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends ConsumerState<ModeSelectionScreen> {
  late int _selectedMode;
  bool _isSaving = false;
  String? _errorMessage;
  int? _pendingMode;

  @override
  void initState() {
    super.initState();
    _selectedMode = ModeSelectionScreen.normalizeMode(widget.initialMode);
  }

  /// Confirma la selección únicamente después de completar el guardado.
  Future<void> _handleModeTap(int mode) async {
    // Evita doble toque o cambiar de modo mientras se guarda el anterior.
    if (_isSaving) return;

    setState(() {
      _pendingMode = mode;
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      if (widget.onModeSelected != null) {
        await widget.onModeSelected!(mode);
      } else {
        throw StateError('Falta conectar el guardado del modo');
      }
      if (!mounted) return;
      setState(() {
        _selectedMode = mode;
        _isSaving = false;
      });
      ref.read(currentModeProvider.notifier).state = mode;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        if (e is UsageModeProfilePending) _selectedMode = e.mode;
        _errorMessage = e is UsageModeProfilePending
            ? 'Su modo fue actualizado. Falta cargar su seguimiento. '
                  'Sus partidas se conservan. Puede reintentar.'
            : e is UsageModeSaveAfterRevocationFailed
            ? 'La invitación y el vínculo anteriores fueron retirados. '
                  'Su modo no pudo actualizarse. Puede reintentar.'
            : e is CaregiverRevocationUnavailable
            ? 'Por ahora no podemos confirmar la desvinculación del cuidador. '
                  'Su modo actual se mantiene.'
            : 'No se pudo guardar su modo. Su progreso se conserva. Intente de nuevo.';
      });
    }
  }

  /// Flujo de cambio de modo desde el perfil (isChangeMode: true).
  Future<void> _handleChangeModeTap(int mode) async {
    if (_isSaving) return;
    if (mode == _selectedMode && _errorMessage == null) {
      return; // Ya es el modo activo y no hay una preparación pendiente.
    }

    if (_selectedMode == 3 && mode == 2) {
      final confirmed = await _confirmDowngrade();
      if (!confirmed) return; // Cancelar: cierra sin cambios
    }
    // Subir de 2 a 3: sin aviso.

    setState(() {
      _pendingMode = mode;
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      if (widget.onModeSelected != null) {
        await widget.onModeSelected!(mode);
      } else {
        throw StateError('Falta conectar el guardado del modo');
      }
      if (!mounted) return;
      setState(() {
        _selectedMode = mode;
        _isSaving = false;
      });
      ref.read(currentModeProvider.notifier).state = mode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Su modo fue actualizado.',
            style: AppTextStyles.body.copyWith(color: AppColors.textOnPrimary),
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        if (e is UsageModeProfilePending) _selectedMode = e.mode;
        _errorMessage = e is UsageModeProfilePending
            ? 'Su modo fue actualizado. Falta cargar su seguimiento. '
                  'Sus partidas se conservan. Puede reintentar.'
            : e is UsageModeSaveAfterRevocationFailed
            ? 'La invitación y el vínculo anteriores fueron retirados. '
                  'Su modo no pudo actualizarse. Puede reintentar.'
            : e is CaregiverRevocationUnavailable
            ? 'Por ahora no podemos confirmar la desvinculación del cuidador. '
                  'Su modo actual se mantiene.'
            : 'No se pudo guardar su modo. Su progreso se conserva. Intente de nuevo.';
      });
    }
  }

  Future<bool> _confirmDowngrade() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('¿Volver al modo personal?', style: AppTextStyles.heading),
              const SizedBox(height: 12),
              Text(
                'Conservará todas sus partidas y su progreso. '
                'Se cancelará cualquier invitación pendiente. ',
                textAlign: TextAlign.justify,
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Sí, cambiar'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
    return confirmed ?? false;
  }

  void _retryPending() {
    final mode = _pendingMode;
    if (mode == null) return;
    if (widget.isChangeMode) {
      _handleChangeModeTap(mode);
    } else {
      _handleModeTap(mode);
    }
  }

  void _handleTap(int mode) {
    if (widget.isChangeMode) {
      _handleChangeModeTap(mode);
    } else {
      _handleModeTap(mode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        // Desplazable para que el banner de error no desborde en pantallas bajas.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
                    Text(
                      widget.isChangeMode
                          ? 'Mi modo de uso'
                          : '¿Cómo quiere usar la app?',
                      style: AppTextStyles.heading,
                    ),
                    const SizedBox(height: 24),
                    if (_errorMessage != null) ...[
                      _ErrorBanner(
                        message: _errorMessage!,
                        onRetry: _retryPending,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _ModeCard(
                      key: const ValueKey('mode_card_2'),
                      isSelected: _selectedMode == 2,
                      isLoading: _isSaving && _pendingMode == 2,
                      showCurrentBadge:
                          widget.isChangeMode && _selectedMode == 2,
                      icon: Icons.pie_chart,
                      iconBackgroundColor: AppColors.primaryLight,
                      iconColor: AppColors.primary,
                      title: 'Jugar y ver mi progreso',
                      subtitle: 'Sus partidas y su seguimiento se conservan',
                      onTap: () => _handleTap(2),
                    ),
                    const SizedBox(height: 16),
                    _ModeCard(
                      key: const ValueKey('mode_card_3'),
                      isSelected: _selectedMode == 3,
                      isLoading: _isSaving && _pendingMode == 3,
                      showCurrentBadge:
                          widget.isChangeMode && _selectedMode == 3,
                      icon: Icons.favorite,
                      iconBackgroundColor: AppColors.primary,
                      iconColor: AppColors.textOnPrimary,
                      title:
                          'Jugar, ver mi progreso y conectar con un cuidador',
                      subtitle:
                          'Puede preparar una invitación para su cuidador',
                      onTap: () => _handleTap(3),
                    ),
                    const Spacer(),
                    if (!widget.isChangeMode)
                      Text(
                        'Puede cambiar esto cuando quiera.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySecondary,
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: AppTextStyles.fieldError)),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size(48, 48),
            ),
            child: Text(
              'Reintentar',
              style: AppTextStyles.body.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    super.key,
    required this.isSelected,
    required this.isLoading,
    required this.showCurrentBadge,
    required this.icon,
    required this.iconBackgroundColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool isSelected;
  final bool isLoading;
  final bool showCurrentBadge;
  final IconData icon;
  final Color iconBackgroundColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final themeShape =
        Theme.of(context).cardTheme.shape as RoundedRectangleBorder?;
    final borderRadius =
        (themeShape?.borderRadius as BorderRadius?) ??
        BorderRadius.circular(18);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: isSelected ? AppColors.primaryLight : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 3 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: isLoading
                    ? Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: iconColor,
                          ),
                        ),
                      )
                    : Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.cardTitle),
                    const SizedBox(height: 4),
                    Text(subtitle, style: AppTextStyles.bodySecondary),
                    if (showCurrentBadge) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Modo actual',
                          style: AppTextStyles.tag.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
