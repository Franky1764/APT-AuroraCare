// lib/presentation/games/memoria/mis_recuerdos/mis_recuerdos_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../data/repositories/memories_repository_impl.provider.dart';
import '../../../../domain/entities/memory_category.dart';
import 'mis_recuerdos_button_style.dart';
import 'mis_recuerdos_fill_screen.dart';
import 'mis_recuerdos_providers.dart';
import 'mis_recuerdos_quiz_screen.dart';
import 'mis_recuerdos_rules.dart';

/// Entrada de "Mis recuerdos": lista las 3 categorías predeterminadas más
/// las categorías propias de la persona, con su estado y los botones
/// para completar datos o jugar. Debajo de la lista, el botón para crear
/// una categoría propia nueva. [uid] llega resuelto desde
/// DomainGamesScreen (null si no hay sesión iniciada) — esta pantalla y
/// las que abre no dependen de FirebaseAuth directamente.
class MisRecuerdosEntryScreen extends ConsumerStatefulWidget {
  const MisRecuerdosEntryScreen({super.key, required this.uid});

  final String? uid;

  @override
  ConsumerState<MisRecuerdosEntryScreen> createState() =>
      _MisRecuerdosEntryScreenState();
}

class _MisRecuerdosEntryScreenState
    extends ConsumerState<MisRecuerdosEntryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _mostrarAvisoSiHaceFalta(),
    );
  }

  Future<void> _mostrarAvisoSiHaceFalta() async {
    final uid = widget.uid;
    if (uid == null) return;
    final repo = ref.read(memoriesRepositoryProvider);
    final visto = await repo.hasSeenPrivacyNotice(uid);
    if (visto || !mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('Antes de empezar', style: AppTextStyles.heading),
        content: Text(
          'Lo que escriba se guarda solo en este teléfono. No se envía a '
          'ningún servidor ni lo ve ningún cuidador. Si desinstala la '
          'aplicación o borra sus datos, se pierden.',
          textAlign: TextAlign.justify,
          style: AppTextStyles.body,
        ),
        actions: [
          ElevatedButton(
            key: const ValueKey('privacidad_entendido'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    await repo.markPrivacyNoticeSeen(uid);
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _crearCategoria(
    String uid,
    List<MemoryCategory> categoriasActuales,
  ) async {
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => _DialogoCategoria(
        nombresExistentes: categoriasActuales.map((c) => c.name),
      ),
    );
    if (nombre == null || !mounted) return;
    try {
      final categoria = await ref
          .read(memoriesRepositoryProvider)
          .createCategory(uid: uid, name: nombre);
      ref.invalidate(misRecuerdosCategoriesProvider(uid));
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MisRecuerdosFillScreen(categoria: categoria, uid: uid),
        ),
      );
    } catch (_) {
      _mostrarError('No se pudo crear la categoría. Intente de nuevo.');
    }
  }

  Future<void> _renombrarCategoria(
    String uid,
    MemoryCategory categoria,
    List<MemoryCategory> categoriasActuales,
  ) async {
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => _DialogoCategoria(
        nombresExistentes: categoriasActuales
            .where((c) => c.id != categoria.id)
            .map((c) => c.name),
        nombreInicial: categoria.name,
      ),
    );
    if (nombre == null || !mounted) return;
    try {
      await ref
          .read(memoriesRepositoryProvider)
          .renameCategory(uid: uid, categoryId: categoria.id, name: nombre);
      ref.invalidate(misRecuerdosCategoriesProvider(uid));
    } catch (_) {
      _mostrarError('No se pudo guardar. Intente de nuevo.');
    }
  }

  Future<void> _borrarCategoria(String uid, MemoryCategory categoria) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Borrar "${categoria.name}"?', style: AppTextStyles.heading),
        content: Text(
          'Se perderán todas sus preguntas y respuestas de esta categoría. '
          'Esta acción no se puede deshacer.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await ref
          .read(memoriesRepositoryProvider)
          .deleteCategory(uid: uid, categoryId: categoria.id);
      ref.invalidate(misRecuerdosCategoriesProvider(uid));
    } catch (_) {
      _mostrarError('No se pudo borrar. Intente de nuevo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mis recuerdos')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Inicie sesión para usar esta función.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
          ),
        ),
      );
    }

    final categoriasAsync = ref.watch(misRecuerdosCategoriesProvider(uid));

    return Scaffold(
      appBar: AppBar(title: const Text('Mis recuerdos'), centerTitle: true),
      body: SafeArea(
        child: categoriasAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No se pudieron cargar sus categorías.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
            ),
          ),
          data: (categorias) {
            final cantidadPropias = categorias
                .where((c) => !c.isPredefined)
                .length;
            final puedeCrear = puedeCrearMasCategorias(cantidadPropias);
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Complete sus datos y luego juegue a recordarlos.',
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: 16),
                for (final categoria in categorias) ...[
                  _CategoriaCard(
                    categoria: categoria,
                    uid: uid,
                    onRenombrar: categoria.isPredefined
                        ? null
                        : () => _renombrarCategoria(uid, categoria, categorias),
                    onBorrar: categoria.isPredefined
                        ? null
                        : () => _borrarCategoria(uid, categoria),
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: misRecuerdosBotonPadding,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    onPressed: puedeCrear
                        ? () => _crearCategoria(uid, categorias)
                        : null,
                    icon: const Icon(Icons.add),
                    label: const Text(
                      'Crear mi propia categoría',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                if (!puedeCrear) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Llegó al máximo de $maxCategoriasPropias categorías '
                    'propias. Borre alguna para poder crear una nueva.',
                    style: AppTextStyles.bodySecondary,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoriaCard extends ConsumerWidget {
  const _CategoriaCard({
    required this.categoria,
    required this.uid,
    this.onRenombrar,
    this.onBorrar,
  });

  final MemoryCategory categoria;
  final String uid;
  final VoidCallback? onRenombrar;
  final VoidCallback? onBorrar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preguntasAsync = ref.watch(
      misRecuerdosQuestionsProvider((uid, categoria.id)),
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(categoria.name, style: AppTextStyles.cardTitle),
                ),
                if (onRenombrar != null || onBorrar != null)
                  PopupMenuButton<String>(
                    tooltip: 'Más opciones de "${categoria.name}"',
                    onSelected: (valor) {
                      if (valor == 'renombrar') onRenombrar?.call();
                      if (valor == 'borrar') onBorrar?.call();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'renombrar',
                        child: Text('Renombrar'),
                      ),
                      const PopupMenuItem(
                        value: 'borrar',
                        child: Text('Borrar categoría'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            preguntasAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
              error: (_, _) => Text(
                'No se pudo cargar esta categoría.',
                style: AppTextStyles.bodySecondary,
              ),
              data: (preguntas) {
                final jugable = esCategoriaJugable(preguntas);
                final faltan = respondidasFaltantes(preguntas);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      jugable
                          ? 'Listo para jugar'
                          : 'Faltan $faltan respuestas para jugar',
                      style: AppTextStyles.bodySecondary.copyWith(
                        color: jugable
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: misRecuerdosBotonPadding,
                            ),
                            onPressed: jugable
                                ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MisRecuerdosQuizScreen(
                                        categoria: categoria,
                                        uid: uid,
                                      ),
                                    ),
                                  )
                                : null,
                            child: const Text(
                              'Jugar',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: misRecuerdosBotonPadding,
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MisRecuerdosFillScreen(
                                  categoria: categoria,
                                  uid: uid,
                                ),
                              ),
                            ),
                            child: const Text(
                              'Completar mis recuerdos',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo para crear ([nombreInicial] vacío) o renombrar una categoría
/// propia. El contador de caracteres queda visible a propósito (a
/// diferencia de los diálogos de pregunta/respuesta propias): el nombre
/// de la categoría es corto y conviene que la persona vea cuánto le
/// queda mientras escribe.
class _DialogoCategoria extends StatefulWidget {
  const _DialogoCategoria({
    required this.nombresExistentes,
    this.nombreInicial = '',
  });

  final Iterable<String> nombresExistentes;
  final String nombreInicial;

  @override
  State<_DialogoCategoria> createState() => _DialogoCategoriaState();
}

class _DialogoCategoriaState extends State<_DialogoCategoria> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.nombreInicial,
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirmar() {
    final nombre = _controller.text.trim();
    final error = validarNombreCategoria(
      nombre,
      nombresExistentes: widget.nombresExistentes,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(nombre);
  }

  @override
  Widget build(BuildContext context) {
    final esNueva = widget.nombreInicial.isEmpty;
    return AlertDialog(
      title: Text(
        esNueva ? 'Crear mi propia categoría' : 'Renombrar categoría',
        style: AppTextStyles.heading,
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        maxLength: maxLargoNombreCategoria,
        decoration: InputDecoration(
          labelText: 'Nombre de la categoría',
          hintText: 'Ej.: Arte',
          errorText: _error,
        ),
        style: AppTextStyles.body,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _confirmar, child: const Text('Guardar')),
      ],
    );
  }
}
