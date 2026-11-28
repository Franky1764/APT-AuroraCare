// lib/presentation/caregiver_dashboard/caregiver_unlink.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/firebase_providers.dart';

/// El cuidador deja de ser cuidador de su familiar.
///
/// Marca el vínculo `caregiver_links/{token}` como 'revoked' e indica que
/// fue el cuidador quien lo terminó (`revokedBy: 'caregiver'`). El adulto
/// mayor lo detecta y recibe un aviso (ver elder_caregiver_departure.dart).
/// No borra prácticas ni perfiles: solo termina el vínculo.
final caregiverUnlinkProvider = Provider<CaregiverUnlink>(
  (ref) => CaregiverUnlink(
    ref.watch(firestoreProvider),
    () => ref.read(firebaseAuthProvider).currentUser?.uid,
    () => ref.read(sharedPreferencesProvider),
  ),
);

class CaregiverUnlink {
  CaregiverUnlink(this._firestore, this._uid, this._prefs);
  final FirebaseFirestore _firestore;
  final String? Function() _uid;
  final SharedPreferences Function() _prefs;

  Future<void> unlink() async {
    final uid = _uid();
    if (uid == null) throw StateError('Se necesita iniciar sesión');
    final pointer = await _firestore
        .collection('caregiver_link_state')
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    final token = pointer.data()?['token'] as String?;
    if (token == null) return;
    final linkRef = _firestore.collection('caregiver_links').doc(token);
    await _firestore.runTransaction((transaction) async {
      final link = (await transaction.get(linkRef)).data();
      if (link == null ||
          link['status'] != 'active' ||
          link['caregiverUID'] != uid) {
        return;
      }
      transaction.update(linkRef, {
        'status': 'revoked',
        'revokedBy': 'caregiver',
        'revokedAt': FieldValue.serverTimestamp(),
      });
    });
    if (_uid() != uid) return;
    // Fue el propio cuidador: no le avisamos «El vínculo terminó».
    await _prefs().remove('caregiver_alerts_link_$uid');
  }
}

/// Pide confirmación y desvincula. Devuelve true si se terminó el vínculo.
Future<bool> confirmCaregiverUnlink(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.link_off_rounded, color: AppColors.error, size: 36),
      title: const Text('¿Dejar de ser cuidador?'),
      content: const Text(
        'Ya no verá la actividad de práctica de su familiar. '
        'Le avisaremos a su familiar que usted terminó el vínculo.\n\n'
        'Si más adelante quiere volver, su familiar puede mostrarle '
        'un código QR nuevo.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sí, desvincularme'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref
        .read(caregiverUnlinkProvider)
        .unlink()
        .timeout(const Duration(seconds: 10));
    messenger.showSnackBar(
      const SnackBar(content: Text('Usted ya no está vinculado a su familiar.')),
    );
    return true;
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'No pudimos terminar el vínculo. Revise su conexión e inténtelo de nuevo.',
        ),
      ),
    );
    return false;
  }
}
