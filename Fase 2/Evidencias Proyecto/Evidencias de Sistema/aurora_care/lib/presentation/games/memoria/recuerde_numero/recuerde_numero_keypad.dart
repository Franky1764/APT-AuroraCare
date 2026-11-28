// lib/presentation/games/memoria/recuerde_numero/recuerde_numero_keypad.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/accessibility_providers.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

enum _TeclaTipo { digito, borrar, listo }

enum _TeclaEstilo { normal, secundaria, primaria }

class _Tecla {
  const _Tecla.digito(this.digito)
    : tipo = _TeclaTipo.digito,
      estilo = _TeclaEstilo.normal;
  const _Tecla.borrar()
    : tipo = _TeclaTipo.borrar,
      digito = null,
      estilo = _TeclaEstilo.secundaria;
  const _Tecla.listo()
    : tipo = _TeclaTipo.listo,
      digito = null,
      estilo = _TeclaEstilo.primaria;

  final _TeclaTipo tipo;
  final int? digito;
  final _TeclaEstilo estilo;
}

/// Teclado numérico propio (no el del sistema): 1-9, 0, Borrar y Listo.
/// El tamaño de cada tecla se calcula con el espacio real disponible
/// (LayoutBuilder), con un piso de 48dp. Mientras se muestra el número
/// ([bloqueado]), todas las teclas quedan atenuadas y deshabilitadas.
class RecuerdeNumeroKeypad extends StatelessWidget {
  const RecuerdeNumeroKeypad({
    super.key,
    required this.bloqueado,
    required this.listoHabilitado,
    required this.onDigito,
    required this.onBorrar,
    required this.onListo,
  });

  final bool bloqueado;
  final bool listoHabilitado;
  final void Function(int) onDigito;
  final VoidCallback onBorrar;
  final VoidCallback onListo;

  static const List<List<_Tecla>> _filas = [
    [_Tecla.digito(1), _Tecla.digito(2), _Tecla.digito(3)],
    [_Tecla.digito(4), _Tecla.digito(5), _Tecla.digito(6)],
    [_Tecla.digito(7), _Tecla.digito(8), _Tecla.digito(9)],
    [_Tecla.borrar(), _Tecla.digito(0), _Tecla.listo()],
  ];

  static const double _spacing = 10.0;
  static const int _columnas = 3;
  static const int _filasCount = 4;

  Widget _buildTecla(_Tecla tecla) {
    switch (tecla.tipo) {
      case _TeclaTipo.digito:
        return _TeclaBoton(
          label: '${tecla.digito}',
          estilo: tecla.estilo,
          onTap: bloqueado ? null : () => onDigito(tecla.digito!),
        );
      case _TeclaTipo.borrar:
        return _TeclaBoton(
          label: 'Borrar',
          icon: Icons.backspace_outlined,
          estilo: tecla.estilo,
          onTap: bloqueado ? null : onBorrar,
        );
      case _TeclaTipo.listo:
        final habilitada = !bloqueado && listoHabilitado;
        return _TeclaBoton(
          label: 'Listo',
          estilo: tecla.estilo,
          onTap: habilitada ? onListo : null,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth =
            (constraints.maxWidth - _spacing * (_columnas - 1)) / _columnas;
        final cellHeight =
            (constraints.maxHeight - _spacing * (_filasCount - 1)) /
            _filasCount;
        final rawSize = cellWidth < cellHeight ? cellWidth : cellHeight;
        final size = rawSize.clamp(48.0, 90.0);

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: SizedBox(
                width: size * _columnas + _spacing * (_columnas - 1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var r = 0; r < _filas.length; r++) ...[
                      if (r > 0) const SizedBox(height: _spacing),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var c = 0; c < _filas[r].length; c++) ...[
                            if (c > 0) const SizedBox(width: _spacing),
                            SizedBox(
                              width: size,
                              height: size,
                              child: _buildTecla(_filas[r][c]),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Una tecla, con su propia animación breve de toque (independiente del
/// estado del controller) y vibración táctil — sin fallar si
/// el dispositivo no tiene vibración.
class _TeclaBoton extends ConsumerStatefulWidget {
  const _TeclaBoton({
    required this.label,
    this.icon,
    required this.estilo,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final _TeclaEstilo estilo;
  final VoidCallback? onTap;

  @override
  ConsumerState<_TeclaBoton> createState() => _TeclaBotonState();
}

class _TeclaBotonState extends ConsumerState<_TeclaBoton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).chain(CurveTween(curve: Curves.easeOut)).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    final onTap = widget.onTap;
    if (onTap == null) return;
    _vibrar();
    _controller.forward(from: 0).then((_) {
      if (mounted) _controller.reverse();
    });
    onTap();
  }

  void _vibrar() {
    ref.read(exerciseVibrationProvider)();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    final habilitada = widget.onTap != null;

    final Color background;
    final Color foreground;
    final Color borderColor;
    switch (widget.estilo) {
      case _TeclaEstilo.primaria:
        background = habilitada ? AppColors.primary : AppColors.border;
        foreground = habilitada
            ? AppColors.textOnPrimary
            : AppColors.textSecondary;
        borderColor = background;
      case _TeclaEstilo.secundaria:
        background = AppColors.surface;
        foreground = habilitada ? AppColors.primary : AppColors.textSecondary;
        borderColor = AppColors.border;
      case _TeclaEstilo.normal:
        background = AppColors.surface;
        foreground = habilitada
            ? AppColors.textPrimary
            : AppColors.textSecondary;
        borderColor = AppColors.border;
    }

    return Semantics(
      label: widget.label,
      button: true,
      onTap: widget.onTap,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: habilitada ? 1.0 : 0.45,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: radius,
              onTap: widget.onTap == null ? null : _handleTap,
              child: ScaleTransition(
                scale: _scale,
                child: Container(
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: radius,
                    border: Border.all(color: borderColor, width: 1.5),
                  ),
                  child: Center(
                    child: widget.icon != null
                        ? Icon(widget.icon, color: foreground, size: 24)
                        : FittedBox(
                            child: Text(
                              widget.label,
                              style: AppTextStyles.cardTitle.copyWith(
                                color: foreground,
                              ),
                            ),
                          ),
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
