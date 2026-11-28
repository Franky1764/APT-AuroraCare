// lib/presentation/caregiver_dashboard/caregiver_theme_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_palettes.dart';
import '../../core/providers/accessibility_providers.dart';
import '../../core/theme/app_text_styles.dart';
import 'widgets/caregiver_animations.dart';
import 'widgets/caregiver_app_bar.dart';

/// «Tema de colores» del cuidador. Usa los mismos temas y el mismo
/// themeProvider que el adulto mayor (AppPalettes de Dani), pero con una
/// presentación propia: tarjetas con los colores del tema, sin ejemplos.
/// El tema se guarda en este teléfono.
class CaregiverThemeScreen extends ConsumerWidget {
  const CaregiverThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actual = ref.watch(themeProvider);
    return Scaffold(
      appBar: const CaregiverAppBar(),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FadeSlideIn(
                child: Text('Tema de colores', style: AppTextStyles.heading),
              ),
              const SizedBox(height: 6),
              FadeSlideIn(
                index: 1,
                child: Text(
                  'Elija los colores que le resulten más cómodos. '
                  'El cambio se aplica al instante en este teléfono.',
                  style: AppTextStyles.bodySecondary,
                ),
              ),
              const SizedBox(height: 20),
              for (var i = 0; i < AppPalettes.todas.length; i++) ...[
                FadeSlideIn(
                  index: 2 + i,
                  child: _ThemeOptionCard(
                    opcion: AppPalettes.todas[i],
                    selected: AppPalettes.todas[i].id == actual.id,
                    onTap: () => ref
                        .read(themeProvider.notifier)
                        .set(AppPalettes.todas[i]),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({
    required this.opcion,
    required this.selected,
    required this.onTap,
  });

  final AppThemeOption opcion;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = opcion.paleta;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${opcion.nombre}. ${opcion.descripcion}.'
          '${selected ? ' Seleccionado.' : ''}',
      child: ExcludeSemantics(
        child: AnimatedScale(
          scale: selected ? 1.0 : 0.98,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: selected
                    ? [p.primaryLight, p.background]
                    : [AppColors.surface, AppColors.surface],
              ),
              border: Border.all(
                color: selected ? p.primary : AppColors.border,
                width: selected ? 2.5 : 1.5,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: p.primary.withValues(alpha: 0.22),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : const [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _Swatch(paleta: p),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              opcion.nombre,
                              style: AppTextStyles.cardTitle.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              opcion.descripcion,
                              style: AppTextStyles.bodySecondary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: selected
                            ? Icon(
                                Icons.check_circle_rounded,
                                key: const ValueKey('on'),
                                color: p.primary,
                                size: 30,
                              )
                            : Icon(
                                Icons.radio_button_unchecked,
                                key: const ValueKey('off'),
                                color: AppColors.border,
                                size: 30,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Círculo con los colores del tema: principal grande y dos colores de
/// apoyo encima. Solo decoración: el nombre y el check dicen cuál es.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.paleta});

  final AppPalette paleta;

  @override
  Widget build(BuildContext context) {
    Widget dot(Color color, double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );

    return SizedBox(
      width: 64,
      height: 56,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [paleta.primary, paleta.primaryDark],
                ),
              ),
            ),
          ),
          Positioned(right: 0, top: 4, child: dot(paleta.accent, 22)),
          Positioned(right: 6, bottom: 0, child: dot(paleta.success, 18)),
        ],
      ),
    );
  }
}
