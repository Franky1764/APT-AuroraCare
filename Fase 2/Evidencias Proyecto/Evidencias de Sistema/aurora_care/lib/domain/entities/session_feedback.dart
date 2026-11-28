import 'cognitive_metrics.dart';

/// Describe observaciones de una partida, sin convertirlas en score clínico
/// ni compararlas con otras personas o con sesiones de distinta dificultad.
class SessionFeedback {
  const SessionFeedback(this.items, {this.explanations = const {}});
  final Map<String, String> items;
  final Map<String, String> explanations;

  factory SessionFeedback.fromMetrics(
    CognitiveMetrics metrics, {
    String? gameType,
  }) {
    final items = <String, String>{};
    final explanations = <String, String>{};
    void percentage(String label, double value) {
      if (value.isFinite && value >= 0 && value <= 100) {
        items[label] = '${value.toStringAsFixed(0)} %';
      }
    }

    switch (metrics) {
      case PhoneListMetrics():
        items['Elementos encontrados'] =
            '${metrics.completedSearches} de ${metrics.totalSearches}';
        items['Selecciones realizadas'] = '${metrics.selectionAttempts}';
        items['Desplazamientos de la lista'] = '${metrics.scrollGestures}';
        items['Búsquedas con apoyo'] = '${metrics.searchesWithHelp}';
        explanations['Búsquedas con apoyo'] = 'Son las búsquedas en que eligió que la aplicación mostrara dónde estaba el elemento. Se cuentan por separado; no son una penalización.';
        explanations['Desplazamientos de la lista'] = 'Se cuentan los gestos que inició para mover la lista. El desplazamiento automático del botón de apoyo no se incluye.';
      case PhoneZoomMetrics():
        items['Acciones completadas'] =
            '${metrics.completedActions} de ${metrics.totalActions}';
        items['Gestos logrados con dos dedos'] = '${metrics.successfulPinches}';
        items['Intentos con dos dedos'] = '${metrics.pinchAttempts}';
        items['Acciones con un botón'] = '${metrics.assistedActions}';
        if (metrics.maxScaleReached.isFinite && metrics.maxScaleReached >= 1) {
          items['Tamaño máximo de la imagen'] =
              '${metrics.maxScaleReached.toStringAsFixed(1).replaceAll('.', ',')} veces';
        }
        explanations['Tamaño máximo de la imagen'] = 'Indica cuánto amplió la imagen respecto de su tamaño inicial. Describe esta práctica; no es una puntuación.';
        explanations['Acciones con un botón'] = 'Son las ampliaciones o reducciones realizadas con el botón de apoyo, por separado de los gestos con dos dedos.';
      case PhoneDragMetrics():
        items['Imágenes colocadas'] =
            '${metrics.completedActions} de ${metrics.totalActions}';
        items['Arrastres logrados'] = '${metrics.successfulDrags}';
        items['Intentos de arrastre'] = '${metrics.dragAttempts}';
        items['Veces que soltó fuera del destino'] =
            '${metrics.dropsOutsideTarget}';
        items['Colocaciones con un botón'] = '${metrics.assistedActions}';
        explanations['Intentos de arrastre'] = 'Se cuentan los intentos que comenzaron manteniendo presionada la imagen y terminaron al levantar el dedo. Las pausas y las interrupciones no cuentan como intentos fallidos.';
        explanations['Colocaciones con un botón'] = 'Son las veces que utilizó el botón de apoyo. Se registran por separado de los arrastres.';
      case PhoneSwipeMetrics():
        items['Cambios de imagen completados'] =
            '${metrics.completedActions} de ${metrics.totalActions}';
        items['Deslizamientos logrados'] = '${metrics.successfulSwipes}';
        items['Gestos intentados'] = '${metrics.gestureAttempts}';
        items['Cambios con un botón'] = '${metrics.assistedActions}';
        explanations['Gestos intentados'] = 'Se cuentan los movimientos que realizó sobre la imagen. Puede repetirlos con calma; los intentos no son una penalización.';
        explanations['Cambios con un botón'] = 'Son las veces que eligió cambiar la imagen con el botón de apoyo. Se registran por separado de los deslizamientos.';
      case PhoneTouchMetrics():
        items['Acciones completadas'] =
            '${metrics.completedTargets} de ${metrics.totalTargets}';
        items['Toques realizados'] =
            '${metrics.touchesOnTarget + metrics.touchesOutsideTarget}';
        items['Toques fuera del elemento'] = '${metrics.touchesOutsideTarget}';
        explanations['Toques realizados'] =
            'Se cuentan los toques registrados dentro del área de práctica.';
        explanations['Toques fuera del elemento'] = 'Son los toques dentro del área de práctica que quedaron fuera del botón o la imagen. Puede practicar a su ritmo; no son una penalización.';
      case PraxiasMetrics():
        percentage('Precisión del recorrido', metrics.precisionPct);
        if (metrics.connectionVersion == 'connect-dots-v2') {
          final attempts = metrics.connectionAttempts;
          items['Figuras completadas'] =
              '${attempts.where((a) => a.completed).map((a) => a.figure).toSet().length}';
          items['Intentos registrados'] = '${attempts.length}';
          items['Tiempo de práctica'] = metrics.tiempoSegundos == 0
              ? 'Menos de 1 segundo'
              : '${metrics.tiempoSegundos} segundos';
          items['Toques en otros puntos'] = '${metrics.correcciones}';
          explanations['Toques en otros puntos'] = 'Son los toques en puntos que todavía no correspondían a la secuencia. Levantar el dedo y pausar no se cuentan como toques fuera de orden.';
          items['Demostraciones consultadas'] =
              '${attempts.fold(0, (sum, a) => sum + a.demonstrationViews)}';
          explanations['Precisión del recorrido'] =
              'Describe cuánto del recorrido realizado quedó cerca del tramo entre los puntos, '
              'considerando el último intento completado de cada figura. No es una puntuación clínica.';
          explanations['Tiempo de práctica'] =
              'Es el tiempo real desde que comenzó a unir los puntos. Incluye los intentos repetidos '
              'y excluye las pausas, las demostraciones y la espera entre figuras. No se usa para exigir rapidez.';
          explanations['Intentos registrados'] = 'Volver a empezar es parte de la práctica. Se conservan los intentos anteriores sin penalizarlos.';
          explanations['Demostraciones consultadas'] = 'Ver cómo hacerlo no completa puntos ni mejora artificialmente la precisión del recorrido.';
        }
        if (metrics.tracingVersion == 'tracing-practice-v2') {
          final completed = metrics.tracingAttempts
              .where((attempt) => attempt.completed)
              .map((attempt) => attempt.figure)
              .toSet();
          items['Figuras completadas'] = '${completed.length}';
          items['Intentos realizados'] = '${metrics.tracingAttempts.length}';
        }
      case MemoriaMetrics():
        percentage('Aciertos registrados', metrics.tasaAciertoPct);
        if (metrics.intentos >= 0) {
          items['Intentos registrados'] = '${metrics.intentos}';
        }
      case AtencionMetrics():
        if (metrics.tiempoRespuestaMs > 0) {
          const label = 'Tiempo promedio para responder';
          // Se conserva la medida original en milisegundos; solo cambia la
          // presentación. Un tiempo positivo nunca se muestra como cero.
          final seconds = (metrics.tiempoRespuestaMs / 1000)
              .toStringAsFixed(1)
              .replaceAll('.', ',');
          items[label] = metrics.tiempoRespuestaMs < 100
              ? 'Menos de 0,1 segundos'
              : '$seconds segundos';
          explanations[label] = switch (gameType) {
            'toca_correcto' => 'Es el tiempo promedio que tardó en tocar la figura indicada desde que apareció. Se cuentan las veces en que tocó esa figura correctamente.',
            'contador_objetos' => 'Es el tiempo promedio que tardó en elegir cuántas figuras había, desde que aparecieron las opciones de respuesta.',
            'secuencias_colores' => 'Es el tiempo promedio entre sus respuestas al repetir los colores. También incluye la espera desde que comenzó su turno hasta el primer toque.',
            _ => 'Es el tiempo promedio de las respuestas registradas en esta partida.',
          };
        }
        percentage('Errores registrados', metrics.tasaErrorPct);
    }
    return SessionFeedback(
      Map.unmodifiable(items),
      explanations: Map.unmodifiable(explanations),
    );
  }
}
