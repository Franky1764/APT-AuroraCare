import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../caregiver_history.dart';
import '../caregiver_navigation.dart';
import '../caregiver_week_data.dart';
import '../shared_practice_provider.dart';

/// Panel de avisos del cuidador (H67). Lee el resumen que comparte el
/// adulto mayor en `caregiver_summaries`; sin vínculo, queda vacío.
Future<void> showCaregiverNotifications(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar notificaciones',
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        _NotificationsPanel(hostContext: context),
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.05),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _NotificationsPanel extends ConsumerWidget {
  const _NotificationsPanel({required this.hostContext});

  final BuildContext hostContext;

  void _handleTap(BuildContext panelContext, CaregiverNotice item) {
    Navigator.of(panelContext).pop();

    switch (item.target) {
      case CaregiverNoticeTarget.area:
        CaregiverNavigation.openActivityDetail(hostContext, item.areaKey!);
      case CaregiverNoticeTarget.weeklySummary:
        CaregiverNavigation.openWeeklySummary(hostContext);
      case CaregiverNoticeTarget.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final token = ref.watch(sharedPracticeLinkProvider).valueOrNull;
    final items = token == null
        ? const <CaregiverNotice>[]
        : caregiverNoticesFrom(
            summary: ref.watch(sharedPracticeSummaryProvider(token)).valueOrNull,
            history: ref.watch(caregiverAreaHistoryProvider),
            now: DateTime.now(),
          );

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 8, 16, 16),
          child: Material(
            color: AppColors.surface,
            elevation: 8,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Notificaciones',
                            style: AppTextStyles.heading,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar',
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  if (items.isEmpty)
                    _EmptyNotifications(linked: token != null)
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (itemContext, index) => _NotificationTile(
                          item: items[index],
                          onTap: () => _handleTap(context, items[index]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final CaregiverNotice item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.target == CaregiverNoticeTarget.none ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: item.dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: AppTextStyles.cardTitle),
                    const SizedBox(height: 2),
                    Text(item.body, style: AppTextStyles.bodySecondary),
                    if (item.timeLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.timeLabel,
                        style: AppTextStyles.tag.copyWith(
                          color: AppColors.textSecondary,
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

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications({required this.linked});

  final bool linked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Column(
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 40,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            linked ? 'Sin avisos por ahora' : 'No tienes notificaciones',
            textAlign: TextAlign.center,
            style: AppTextStyles.cardTitle,
          ),
          const SizedBox(height: 4),
          Text(
            linked
                ? 'Cuando su familiar practique, aquí verá sus avisos.'
                : 'Cuando vincules a tu familiar, aquí verás sus avisos.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary,
          ),
        ],
      ),
    );
  }
}
