// lib/presentation/breathing/breathing_duration_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/accessibility_providers.dart';
import '../../core/theme/app_text_styles.dart';
import '../shared/app_header_bar.dart';
import 'breathing_session_screen.dart';

/// Elección de duración de la respiración guiada (F5). 100% visual: sin
/// backend, sin score. La duración elegida se recuerda entre sesiones
/// (preferencia de uso, no una métrica cognitiva).
class BreathingDurationScreen extends ConsumerStatefulWidget {
  const BreathingDurationScreen({super.key, required this.userName});

  final String userName;

  @override
  ConsumerState<BreathingDurationScreen> createState() =>
      _BreathingDurationScreenState();
}

class _DurationOption {
  const _DurationOption({
    required this.minutes,
    required this.title,
    required this.subtitle,
  });

  final int minutes;
  final String title;
  final String subtitle;
}

class _BreathingDurationScreenState
    extends ConsumerState<BreathingDurationScreen> {
  static const List<_DurationOption> _options = [
    _DurationOption(minutes: 2, title: '2 minutos', subtitle: 'Corto'),
    _DurationOption(minutes: 5, title: '5 minutos', subtitle: 'Recomendado'),
    _DurationOption(minutes: 10, title: '10 minutos', subtitle: 'Largo'),
  ];

  late int _selectedMinutes;

  @override
  void initState() {
    super.initState();
    _selectedMinutes = ref
        .read(preferencesLocalSourceProvider)
        .getBreathingMinutes();
  }

  void _handleStart() {
    ref
        .read(preferencesLocalSourceProvider)
        .setBreathingMinutes(_selectedMinutes);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BreathingSessionScreen(
          minutes: _selectedMinutes,
          userName: widget.userName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeaderBar(showBackButton: true),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      '¿Cuánto tiempo quiere respirar?',
                      style: AppTextStyles.heading,
                    ),
                    const SizedBox(height: 24),
                    for (final option in _options) ...[
                      _DurationCard(
                        isSelected: _selectedMinutes == option.minutes,
                        title: option.title,
                        subtitle: option.subtitle,
                        onTap: () {
                          setState(() => _selectedMinutes = option.minutes);
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _handleStart,
                      child: const Text('Comenzar'),
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

class _DurationCard extends StatelessWidget {
  const _DurationCard({
    required this.isSelected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool isSelected;
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

    return Semantics(
      label: isSelected ? '$title, $subtitle, seleccionado' : '$title, $subtitle',
      button: true,
      selected: isSelected,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Card(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.cardTitle),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppTextStyles.bodySecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
