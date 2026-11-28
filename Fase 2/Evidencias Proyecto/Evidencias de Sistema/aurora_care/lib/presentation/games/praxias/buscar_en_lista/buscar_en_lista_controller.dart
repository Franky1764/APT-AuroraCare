import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/cognitive_metrics.dart';
import '../../../../domain/entities/game_level.dart';

final phoneListProvider = StateNotifierProvider.autoDispose
    .family<PhoneListController, PhoneListState, GameLevel>(
      (ref, level) => PhoneListController(level),
    );

class PhoneListState {
  const PhoneListState({
    this.found = 0,
    this.attempts = 0,
    this.otherSelections = 0,
    this.scrolls = 0,
    this.reveals = 0,
    this.assisted = 0,
    this.helpForTarget = false,
    this.paused = false,
    this.finished = false,
    this.wrongSelection = false,
    this.foundItems = const [],
    this.wrongIndex,
    this.wrongTick = 0,
  });
  static const searchCount = 3;
  final int found, attempts, otherSelections, scrolls, reveals, assisted;
  final bool helpForTarget, paused, finished, wrongSelection;

  /// Posiciones de la lista ya encontradas (se marcan con un check).
  final List<int> foundItems;

  /// Última fila tocada por error; [wrongTick] cambia en cada error para
  /// poder repetir el destello aunque sea la misma fila.
  final int? wrongIndex;
  final int wrongTick;
  bool get completed => found == searchCount;
  bool get blocked => completed || paused || finished;
  PhoneListState copyWith({
    int? found,
    int? attempts,
    int? otherSelections,
    int? scrolls,
    int? reveals,
    int? assisted,
    bool? helpForTarget,
    bool? paused,
    bool? finished,
    bool? wrongSelection,
    List<int>? foundItems,
    int? wrongIndex,
    bool clearWrongIndex = false,
    int? wrongTick,
  }) => PhoneListState(
    found: found ?? this.found,
    attempts: attempts ?? this.attempts,
    otherSelections: otherSelections ?? this.otherSelections,
    scrolls: scrolls ?? this.scrolls,
    reveals: reveals ?? this.reveals,
    assisted: assisted ?? this.assisted,
    helpForTarget: helpForTarget ?? this.helpForTarget,
    paused: paused ?? this.paused,
    finished: finished ?? this.finished,
    wrongSelection: wrongSelection ?? this.wrongSelection,
    foundItems: foundItems ?? this.foundItems,
    wrongIndex: clearWrongIndex ? null : (wrongIndex ?? this.wrongIndex),
    wrongTick: wrongTick ?? this.wrongTick,
  );
}

/// La consigna permanece visible; encontrar un elemento no exige recordarlo
/// de memoria ni completar la búsqueda antes de un plazo.
class PhoneListController extends StateNotifier<PhoneListState> {
  PhoneListController(this.level, {math.Random? random})
    : super(const PhoneListState()) {
    final rng = random ?? math.Random();
    // Cada partida mezcla los lugares y sortea qué se busca, para que no se
    // pueda memorizar la práctica.
    final pool = List<String>.of(_allItems)..shuffle(rng);
    _items = pool.take(listLength).toList();
    _targets = _pickTargets(rng);
    _lastFirstTarget = _items[_targets.first];
  }
  final GameLevel level;
  late final List<String> _items;
  late final List<int> _targets;

  /// Primera búsqueda de la partida anterior (solo en memoria): la siguiente
  /// partida empieza con otro lugar.
  static String? _lastFirstTarget;

  @visibleForTesting
  static void resetHistory() => _lastFirstTarget = null;

  /// Desde esta posición el lugar queda fuera de las primeras filas visibles,
  /// así que siempre hay al menos una búsqueda que exige deslizar.
  static const _firstOffscreenIndex = 5;

  List<int> _pickTargets(math.Random rng) {
    final far = [for (var i = _firstOffscreenIndex; i < listLength; i++) i];
    final first = far[rng.nextInt(far.length)];
    final rest = [
      for (var i = 0; i < listLength; i++)
        if (i != first) i,
    ]..shuffle(rng);
    final picked = [first, rest[0], rest[1]]..shuffle(rng);
    if (_items[picked.first] == _lastFirstTarget) {
      final swap = picked.indexWhere((i) => _items[i] != _lastFirstTarget);
      if (swap > 0) {
        final tmp = picked[0];
        picked[0] = picked[swap];
        picked[swap] = tmp;
      }
    }
    return picked;
  }

  static List<String> get allItems => List.unmodifiable(_allItems);
  static const _allItems = [
    'Biblioteca',
    'Plaza',
    'Farmacia',
    'Panadería',
    'Consultorio',
    'Museo',
    'Feria',
    'Parque',
    'Correo',
    'Teatro',
    'Municipalidad',
    'Jardín',
    'Cafetería',
    'Mercado',
    'Terminal',
    'Librería',
  ];
  int get listLength => switch (level) {
    GameLevel.facil => 8,
    GameLevel.intermedio => 12,
    GameLevel.avanzado => 16,
  };
  List<String> get items => List.unmodifiable(_items);
  int get targetIndex => _targets[state.found.clamp(0, 2)];
  String get target => _items[targetIndex];
  void select(int index) {
    if (state.blocked || index < 0 || index >= listLength) return;
    if (index == targetIndex) {
      state = state.copyWith(
        found: state.found + 1,
        attempts: state.attempts + 1,
        assisted: state.assisted + (state.helpForTarget ? 1 : 0),
        helpForTarget: false,
        wrongSelection: false,
        foundItems: [...state.foundItems, index],
        clearWrongIndex: true,
      );
    } else {
      state = state.copyWith(
        attempts: state.attempts + 1,
        otherSelections: state.otherSelections + 1,
        wrongSelection: true,
        wrongIndex: index,
        wrongTick: state.wrongTick + 1,
      );
    }
  }

  void recordScroll() {
    if (!state.blocked) state = state.copyWith(scrolls: state.scrolls + 1);
  }

  void reveal() {
    if (!state.blocked) {
      state = state.copyWith(reveals: state.reveals + 1, helpForTarget: true);
    }
  }

  void pause() => state = state.copyWith(paused: true);
  void resume() => state = state.copyWith(paused: false);
  PhoneListMetrics? finish() {
    if (!state.completed || state.finished) return null;
    state = state.copyWith(finished: true);
    return PhoneListMetrics(
      completedSearches: state.found,
      totalSearches: PhoneListState.searchCount,
      selectionAttempts: state.attempts,
      otherSelections: state.otherSelections,
      scrollGestures: state.scrolls,
      revealRequests: state.reveals,
      searchesWithHelp: state.assisted,
      listLength: listLength,
    );
  }
}
