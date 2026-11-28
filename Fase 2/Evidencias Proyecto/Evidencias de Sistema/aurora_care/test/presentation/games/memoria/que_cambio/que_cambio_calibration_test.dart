import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/domain/entities/cognitive_metrics.dart';
import 'package:aurora_care/domain/entities/game_level.dart';
import 'package:aurora_care/presentation/games/memoria/que_cambio/que_cambio_controller.dart';

/// Fija los valores de calibración de ¿Qué cambió? (planilla de Daniela):
/// columnas/diferencias por nivel, y el rango real de intentos/errores
/// (mínimo = diferencias, máximo = columnas × 3 filas).
void main() {
  test('columnas y diferencias por nivel: 3/4/5 (filas siempre 3)', () {
    expect(queCambioColumnasFacil, 3);
    expect(queCambioColumnasIntermedio, 4);
    expect(queCambioColumnasAvanzado, 5);
    expect(queCambioFilas, 3);
    expect(queCambioDiferenciasFacil, 3);
    expect(queCambioDiferenciasIntermedio, 4);
    expect(queCambioDiferenciasAvanzado, 5);
  });

  for (final caso in [
    (GameLevel.facil, 3, 9),
    (GameLevel.intermedio, 4, 12),
    (GameLevel.avanzado, 5, 15),
  ]) {
    final (nivel, minimo, maximo) = caso;

    test(
      '${nivel.label}: intentos mínimo $minimo (solo se tocan las '
      'diferencias, a la primera)',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final provider = queCambioControllerProvider(nivel);
        final notifier = container.read(provider.notifier);

        final diferencias = container.read(provider).diferenciaIndices;
        for (final i in diferencias) {
          notifier.tapCelda(i);
        }

        final metrics = container.read(provider).metrics!;
        expect(metrics, isA<MemoriaMetrics>());
        expect(metrics.intentos, minimo);
        expect(metrics.errores, 0);
        expect(metrics.tasaAciertoPct, 100.0);
      },
    );

    test(
      '${nivel.label}: intentos máximo $maximo (se tocan todas las '
      'celdas, dejando las diferencias al final)',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final provider = queCambioControllerProvider(nivel);
        final notifier = container.read(provider.notifier);

        final estadoInicial = container.read(provider);
        final diferencias = estadoInicial.diferenciaIndices;
        final total = estadoInicial.original.length;
        expect(total, maximo); // columnas * queCambioFilas

        final orden = [
          ...List.generate(
            total,
            (i) => i,
          ).where((i) => !diferencias.contains(i)),
          ...diferencias,
        ];
        for (final i in orden) {
          notifier.tapCelda(i);
        }

        final metrics = container.read(provider).metrics!;
        expect(metrics.intentos, maximo);
        expect(metrics.errores, maximo - diferencias.length);
      },
    );

    test(
      '${nivel.label}: errores máximo $maximo (nunca se toca una '
      'diferencia; se declara terminado)',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final provider = queCambioControllerProvider(nivel);
        final notifier = container.read(provider.notifier);

        final estadoInicial = container.read(provider);
        final diferencias = estadoInicial.diferenciaIndices;
        final noDiferencias = List.generate(
          estadoInicial.original.length,
          (i) => i,
        ).where((i) => !diferencias.contains(i));
        for (final i in noDiferencias) {
          notifier.tapCelda(i);
        }
        notifier.declararTerminado();

        final metrics = container.read(provider).metrics!;
        expect(metrics.errores, maximo);
        expect(metrics.tasaAciertoPct, 0.0);
      },
    );
  }
}
