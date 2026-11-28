// lib/presentation/profile/theme_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_palettes.dart';
import '../../core/providers/accessibility_providers.dart';
import '../../core/theme/app_text_styles.dart';

/// Pantalla "Elegir tema": se abre desde la fila "Tema" del perfil.
class ThemeSelectionScreen extends ConsumerWidget {
  const ThemeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final temaActual = ref.watch(themeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Elegir tema')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final opcion in AppPalettes.todas) ...[
                _ThemeCard(
                  opcion: opcion,
                  isSelected: opcion.id == temaActual.id,
                ),
                if (opcion != AppPalettes.todas.last)
                  const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeCard extends ConsumerWidget {
  const _ThemeCard({required this.opcion, required this.isSelected});

  final AppThemeOption opcion;
  final bool isSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void elegir() => ref.read(themeProvider.notifier).set(opcion);

    return Semantics(
      button: true,
      selected: isSelected,
      label: isSelected
          ? '${opcion.nombre}. ${opcion.descripcion}. Seleccionado.'
          : '${opcion.nombre}. ${opcion.descripcion}.',
      onTap: elegir,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          onTap: elegir,
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(opcion.nombre, style: AppTextStyles.cardTitle),
                            const SizedBox(height: 4),
                            Text(
                              opcion.descripcion,
                              style: AppTextStyles.bodySecondary,
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, color: AppColors.primary),
                    ],
                  ),
                  if (isSelected) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Seleccionado',
                      style: AppTextStyles.bodySecondary.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _VistaPreviaTema(paleta: opcion.paleta),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vista previa con los colores REALES de [paleta] (no de AppColors, que
/// solo expone la paleta activa): un botón de muestra, un acierto y un
/// error, sobre el fondo de esa paleta. Es puramente decorativa — el
/// nombre, la descripción y el estado "Seleccionado" ya están en texto
/// normal más arriba, por eso el padre la excluye de Semantics.
class _VistaPreviaTema extends StatelessWidget {
  const _VistaPreviaTema({required this.paleta});

  final AppPalette paleta;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: paleta.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: paleta.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: paleta.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Text(
                  'Practicar',
                  // Igual que AppTextStyles.tag: única excepción bajo 18sp
                  // ya documentada, por espacio físico de la muestra.
                  style: AppTextStyles.tag.copyWith(color: paleta.textOnPrimary),
                ),
              ),
            ),
            _ChipDeMuestra(
              texto: 'Bien',
              icono: Icons.check_circle,
              color: paleta.success,
              fondo: paleta.successBackground,
            ),
            _ChipDeMuestra(
              texto: 'Error',
              icono: Icons.cancel,
              color: paleta.error,
              fondo: paleta.errorBackground,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipDeMuestra extends StatelessWidget {
  const _ChipDeMuestra({
    required this.texto,
    required this.icono,
    required this.color,
    required this.fondo,
  });

  final String texto;
  final IconData icono;
  final Color color;
  final Color fondo;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 16, color: color),
            const SizedBox(width: 4),
            Text(texto, style: AppTextStyles.tag.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
