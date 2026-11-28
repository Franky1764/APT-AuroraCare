import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/firebase_providers.dart';
import '../../core/router/navigation_session.dart';
import '../../core/theme/app_text_styles.dart';

enum ProfileAvatar {
  leaf('Hoja', Icons.spa_outlined),
  sun('Sol', Icons.wb_sunny_outlined),
  heart('Corazón', Icons.favorite_border_rounded),
  star('Estrella', Icons.star_outline_rounded);

  const ProfileAvatar(this.label, this.icon);

  final String label;
  final IconData icon;
}

final profilePortraitProvider =
    NotifierProvider<ProfilePortraitNotifier, String?>(
      ProfilePortraitNotifier.new,
    );

class ProfilePortraitNotifier extends Notifier<String?> {
  static const _picker = MethodChannel('auroracare/profile_photo');

  String _key(String account) => 'profile_portrait_v1_$account';

  @override
  String? build() {
    final account = ref.watch(navigationSessionProvider).session?.uid;
    if (account == null) return null;
    return ref.watch(sharedPreferencesProvider).getString(_key(account));
  }

  Future<void> choosePhoto() async {
    final account = ref.read(navigationSessionProvider).session?.uid;
    if (account == null) return;
    final bytes = await _picker.invokeMethod<Uint8List>('pick');
    if (bytes != null && bytes.isNotEmpty) {
      await _save(account, 'photo:${base64Encode(bytes)}');
    }
  }

  Future<void> chooseAvatar(ProfileAvatar? avatar) async {
    final account = ref.read(navigationSessionProvider).session?.uid;
    if (account != null) {
      await _save(account, avatar == null ? null : 'avatar:${avatar.name}');
    }
  }

  Future<void> _save(String account, String? value) async {
    if (ref.read(navigationSessionProvider).session?.uid != account) return;
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = value == null
        ? await prefs.remove(_key(account))
        : await prefs.setString(_key(account), value);
    if (!saved) throw StateError('No se pudo guardar la foto del perfil');
    if (ref.read(navigationSessionProvider).session?.uid == account) {
      state = value;
    }
  }
}

class ProfilePortrait extends ConsumerWidget {
  const ProfilePortrait({
    super.key,
    required this.initial,
    required this.radius,
  });

  final String initial;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(profilePortraitProvider);
    final avatar = ProfileAvatar.values
        .where((avatar) => selection == 'avatar:${avatar.name}')
        .firstOrNull;
    final fallback = avatar == null
        ? Text(
            initial,
            style: AppTextStyles.cardTitle.copyWith(
              color: AppColors.textOnPrimary,
            ),
          )
        : Icon(avatar.icon, color: AppColors.textOnPrimary, size: radius);
    Widget content = fallback;
    if (selection?.startsWith('photo:') == true) {
      try {
        content = Image.memory(
          base64Decode(selection!.substring(6)),
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        );
      } on FormatException {
        // Si la preferencia antigua es inválida, se muestra la inicial.
      }
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary,
      child: ClipOval(child: content),
    );
  }
}
