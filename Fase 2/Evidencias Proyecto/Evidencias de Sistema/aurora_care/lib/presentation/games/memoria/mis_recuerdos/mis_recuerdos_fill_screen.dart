// lib/presentation/games/memoria/mis_recuerdos/mis_recuerdos_fill_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/sound_effect.dart';
import '../../../../core/providers/accessibility_providers.dart';
import '../../../../core/providers/sound_providers.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../data/repositories/memories_repository_impl.provider.dart';
import '../../../../domain/entities/memory_category.dart';
import '../../../../domain/entities/memory_question.dart';
import 'mis_recuerdos_button_style.dart';
import 'mis_recuerdos_providers.dart';
import 'mis_recuerdos_rules.dart';

/// Llenado de una categoría: respuestas a las preguntas sugeridas
/// (omitir/deshacer, guardado por lotes) y administración de preguntas
/// propias (agregar/editar/borrar, inmediato). 100% local — no pasa por
/// GameShell/FinishSession.
class MisRecuerdosFillScreen extends ConsumerStatefulWidget {
  const MisRecuerdosFillScreen({
    super.key,
    required this.categoria,
    required this.uid,
  });

  final MemoryCategory categoria;
  final String uid;

  @override
  ConsumerState<MisRecuerdosFillScreen> createState() =>
      _MisRecuerdosFillScreenState();
}

class _MisRecuerdosFillScreenState
    extends ConsumerState<MisRecuerdosFillScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _valoresOriginales = {};
  List<MemoryQuestion> _preguntas = [];
  bool _cargando = true;
  bool _guardando = false;

  bool get _sucio => _controllers.entries.any(
    (e) => e.value.text.trim() != (_valoresOriginales[e.key] ?? ''),
  );

  String get _uid => widget.uid;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    final uid = _uid;
    final repo = ref.read(memoriesRepositoryProvider);
    final preguntas = await repo.loadQuestions(
      uid: uid,
      categoryId: widget.categoria.id,
    );
    if (!mounted) return;
    setState(() {
      _preguntas = preguntas;
      for (final p in preguntas) {
        if (!p.isSuggested) continue;
        final valor = p.answer ?? '';
        final existente = _controllers[p.id];
        // Si el campo tiene texto sin guardar distinto del último valor
        // conocido, NO se sobrescribe: _cargar() se llama tras CUALQUIER
        // acción contra el repositorio (omitir otra pregunta, agregar
        // una propia, etc.), y pisar aquí el texto borraría lo que la
        // persona todavía no guardó en otros campos.
        final sinCambiosLocales =
            existente == null ||
            existente.text.trim() == (_valoresOriginales[p.id] ?? '');
        _valoresOriginales[p.id] = valor;
        if (existente == null) {
          _controllers[p.id] = TextEditingController(text: valor);
        } else if (sinCambiosLocales) {
          existente.text = valor;
        }
      }
      _cargando = false;
    });
    // _cargar() se llama tras cualquier escritura: invalida la copia que
    // observa la lista de categorías (misRecuerdosQuestionsProvider es
    // autoDispose, pero esta misma pantalla de llenado mantiene viva la
    // suscripción de la lista de abajo en la pila mientras está abierta
    // encima — sin esto, "Jugar" y el texto de la tarjeta se quedan con
    // los datos viejos hasta salir de Mis recuerdos y volver a entrar).
    ref.invalidate(misRecuerdosQuestionsProvider((uid, widget.categoria.id)));
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<bool> _confirmarDescartar() async {
    if (!_sucio) return true;
    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Descartar cambios?', style: AppTextStyles.heading),
        content: Text(
          'Tiene respuestas sin guardar. Si sale ahora, se pierden.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Seguir completando'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return salir ?? false;
  }

  Future<void> _guardar() async {
    final uid = _uid;
    setState(() => _guardando = true);
    final repo = ref.read(memoriesRepositoryProvider);
    final errores = <String>[];

    // Junta TODOS los campos modificados para guardarlos en una sola
    // llamada (una sola lectura y una sola escritura del almacenamiento),
    // en vez de una escritura por campo.
    final cambios = <String, String>{};
    for (final p in _preguntas.where((q) => q.isSuggested)) {
      final controller = _controllers[p.id];
      if (controller == null) continue;
      final original = _valoresOriginales[p.id] ?? '';
      final actual = controller.text.trim();
      if (actual == original) continue;
      if (actual.isNotEmpty) {
        final error = validarRespuesta(actual);
        if (error != null) {
          errores.add('${p.askLabel ?? p.quizPrompt}: $error');
          continue;
        }
      }
      // actual puede ser '': la persona vació el campo a propósito, y
      // eso también se guarda (la pregunta vuelve a quedar pendiente).
      cambios[p.id] = actual;
    }

    if (cambios.isNotEmpty) {
      try {
        await repo.saveAnswers(uid: uid, answers: cambios);
        cambios.forEach((id, valor) => _valoresOriginales[id] = valor);
      } catch (_) {
        errores.add('No se pudo guardar. Intente de nuevo.');
      }
    }

    if (!mounted) return;
    setState(() => _guardando = false);
    if (errores.isEmpty) {
      if (ref.read(soundsEnabledProvider)) {
        unawaited(
          ref.read(soundServiceProvider).play(SoundEffect.nivelCompletado),
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sus respuestas se guardaron.')),
      );
    } else {
      _mostrarError(errores.first);
    }
    await _cargar();
  }

  Future<void> _omitir(MemoryQuestion pregunta) async {
    final uid = _uid;
    try {
      await ref
          .read(memoriesRepositoryProvider)
          .omitQuestion(uid: uid, questionId: pregunta.id);
      await _cargar();
    } catch (_) {
      _mostrarError('No se pudo guardar. Intente de nuevo.');
    }
  }

  Future<void> _deshacerOmision(MemoryQuestion pregunta) async {
    final uid = _uid;
    try {
      await ref
          .read(memoriesRepositoryProvider)
          .undoOmit(uid: uid, questionId: pregunta.id);
      await _cargar();
    } catch (_) {
      _mostrarError('No se pudo guardar. Intente de nuevo.');
    }
  }

  Future<void> _agregarPropia() async {
    final resultado = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) => const _DialogoPreguntaPropia(),
    );
    if (resultado == null) return;
    final uid = _uid;
    try {
      await ref
          .read(memoriesRepositoryProvider)
          .addCustomQuestion(
            uid: uid,
            categoryId: widget.categoria.id,
            quizPrompt: resultado.$1,
            answer: resultado.$2,
          );
      await _cargar();
    } catch (_) {
      _mostrarError('No se pudo guardar. Intente de nuevo.');
    }
  }

  Future<void> _editarPropia(MemoryQuestion pregunta) async {
    final resultado = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) => _DialogoPreguntaPropia(
        quizPromptInicial: pregunta.quizPrompt,
        answerInicial: pregunta.answer ?? '',
      ),
    );
    if (resultado == null) return;
    final uid = _uid;
    try {
      await ref
          .read(memoriesRepositoryProvider)
          .editCustomQuestion(
            uid: uid,
            questionId: pregunta.id,
            quizPrompt: resultado.$1,
            answer: resultado.$2,
          );
      await _cargar();
    } catch (_) {
      _mostrarError('No se pudo guardar. Intente de nuevo.');
    }
  }

  Future<void> _borrarPropia(MemoryQuestion pregunta) async {
    if (!puedeBorrarPropia(_preguntas, pregunta.id)) {
      _mostrarError('Una categoría necesita al menos 5 preguntas respondidas');
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Borrar esta pregunta?', style: AppTextStyles.heading),
        content: Text(pregunta.quizPrompt, style: AppTextStyles.body),
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
    final uid = _uid;
    try {
      await ref
          .read(memoriesRepositoryProvider)
          .deleteCustomQuestion(uid: uid, questionId: pregunta.id);
      await _cargar();
    } catch (_) {
      _mostrarError('No se pudo guardar. Intente de nuevo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.categoria.name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final respondidas = respondidasDe(_preguntas).length;
    final sugeridas = _preguntas.where((p) => p.isSuggested).toList();
    final propias = _preguntas.where((p) => !p.isSuggested).toList();

    return PopScope(
      canPop: !_sucio,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final salir = await _confirmarDescartar();
        if (!context.mounted) return;
        if (salir) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.categoria.name)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Semantics(
                liveRegion: true,
                label:
                    'Respondidas: $respondidas, se necesitan '
                    '$minimoRespondidas para jugar',
                child: ExcludeSemantics(
                  child: Text(
                    'Respondidas: $respondidas (se necesitan '
                    '$minimoRespondidas para jugar)',
                    style: AppTextStyles.body,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (final pregunta in sugeridas) ...[
                _PreguntaSugeridaCard(
                  pregunta: pregunta,
                  controller: _controllers[pregunta.id]!,
                  onOmitir: () => _omitir(pregunta),
                  onDeshacer: () => _deshacerOmision(pregunta),
                ),
                const SizedBox(height: 12),
              ],
              const Divider(height: 32),
              Text('Mis propias preguntas', style: AppTextStyles.cardTitle),
              const SizedBox(height: 12),
              for (final pregunta in propias) ...[
                _PreguntaPropiaCard(
                  pregunta: pregunta,
                  onEditar: () => _editarPropia(pregunta),
                  onBorrar: () => _borrarPropia(pregunta),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: misRecuerdosBotonPadding,
                ),
                onPressed: _agregarPropia,
                icon: const Icon(Icons.add),
                label: const Text(
                  'Agregar mi propia pregunta',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: misRecuerdosBotonPadding,
                ),
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : const Text('Guardar', textAlign: TextAlign.center),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreguntaSugeridaCard extends StatelessWidget {
  const _PreguntaSugeridaCard({
    required this.pregunta,
    required this.controller,
    required this.onOmitir,
    required this.onDeshacer,
  });

  final MemoryQuestion pregunta;
  final TextEditingController controller;
  final VoidCallback onOmitir;
  final VoidCallback onDeshacer;

  @override
  Widget build(BuildContext context) {
    final omitida = pregunta.status == MemoryQuestionStatus.omitida;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pregunta.askLabel ?? pregunta.quizPrompt,
              style: AppTextStyles.cardTitle,
            ),
            const SizedBox(height: 8),
            if (omitida)
              Text(
                'Prefiere no responder esta pregunta.',
                style: AppTextStyles.bodySecondary,
              )
            else
              TextField(
                controller: controller,
                textCapitalization: TextCapitalization.words,
                maxLength: maxLargoRespuesta,
                decoration: const InputDecoration(
                  hintText: 'Ej.: María',
                  counterText: '',
                ),
                style: AppTextStyles.body,
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: omitida ? onDeshacer : onOmitir,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(omitida ? 'Deshacer' : 'Prefiero no responder'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreguntaPropiaCard extends StatelessWidget {
  const _PreguntaPropiaCard({
    required this.pregunta,
    required this.onEditar,
    required this.onBorrar,
  });

  final MemoryQuestion pregunta;
  final VoidCallback onEditar;
  final VoidCallback onBorrar;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pregunta.quizPrompt, style: AppTextStyles.cardTitle),
                  const SizedBox(height: 4),
                  Text(
                    pregunta.answer ?? '',
                    style: AppTextStyles.bodySecondary,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onEditar,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar',
            ),
            IconButton(
              onPressed: onBorrar,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Borrar',
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogoPreguntaPropia extends StatefulWidget {
  const _DialogoPreguntaPropia({
    this.quizPromptInicial = '',
    this.answerInicial = '',
  });

  final String quizPromptInicial;
  final String answerInicial;

  @override
  State<_DialogoPreguntaPropia> createState() => _DialogoPreguntaPropiaState();
}

class _DialogoPreguntaPropiaState extends State<_DialogoPreguntaPropia> {
  late final TextEditingController _preguntaController = TextEditingController(
    text: widget.quizPromptInicial,
  );
  late final TextEditingController _respuestaController =
      TextEditingController(text: widget.answerInicial);
  String? _errorPregunta;
  String? _errorRespuesta;

  @override
  void dispose() {
    _preguntaController.dispose();
    _respuestaController.dispose();
    super.dispose();
  }

  void _confirmar() {
    final pregunta = _preguntaController.text.trim();
    final respuesta = _respuestaController.text.trim();
    final errorP = validarPreguntaPropia(pregunta);
    final errorR = validarRespuesta(respuesta);
    if (errorP != null || errorR != null) {
      setState(() {
        _errorPregunta = errorP;
        _errorRespuesta = errorR;
      });
      return;
    }
    Navigator.of(context).pop((pregunta, respuesta));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Mi propia pregunta', style: AppTextStyles.heading),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _preguntaController,
            maxLength: maxLargoPreguntaPropia,
            decoration: InputDecoration(
              labelText: 'Pregunta',
              errorText: _errorPregunta,
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _respuestaController,
            textCapitalization: TextCapitalization.sentences,
            maxLength: maxLargoRespuesta,
            decoration: InputDecoration(
              labelText: 'Respuesta',
              errorText: _errorRespuesta,
              counterText: '',
            ),
          ),
        ],
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
