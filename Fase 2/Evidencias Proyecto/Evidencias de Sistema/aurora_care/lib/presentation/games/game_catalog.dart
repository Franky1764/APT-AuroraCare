// lib/presentation/games/game_catalog.dart
import 'package:aurora_care/presentation/games/praxias/colorear_contorno/colorear_contorno_definition.dart';
import 'package:flutter/material.dart';

import 'atencion/contador_objetos/contador_objetos_definition.dart';
import 'atencion/secuencias_colores/secuencias_colores_definition.dart';
import 'atencion/toca_correcto/toca_correcto_definition.dart';
import 'memoria/memorice_clasico/memorice_clasico_definition.dart';
import 'memoria/memorice_secuencias/memorice_secuencias_definition.dart';
import 'memoria/que_cambio/que_cambio_definition.dart';
import 'memoria/recuerde_numero/recuerde_numero_definition.dart';
import 'praxias/conecta_puntos/conecta_puntos_definition.dart';
import 'praxias/trazado_guiado/trazado_guiado_definition.dart';
import 'praxias/toque_preciso/toque_preciso_definition.dart';
import 'praxias/deslizar_imagenes/deslizar_imagenes_definition.dart';
import 'praxias/arrastrar_elementos/arrastrar_elementos_definition.dart';
import 'praxias/buscar_en_lista/buscar_en_lista_definition.dart';
import 'praxias/ampliar_imagen/ampliar_imagen_definition.dart';
import 'shared/game_definition.dart';

/// Los tres dominios con juegos (Respiración no entra: no es un juego con
/// métricas y tiene su propia tarjeta en el Home).
enum GameDomain { memoria, atencion, praxias }

extension GameDomainInfo on GameDomain {
  /// Clave interna: la misma que usa GameDefinition.domain, la API y Firestore.
  String get key => name;

  /// Id con que el Home avisa que se tocó la tarjeta de este dominio.
  String get homeId => name;

  /// Nombre en la interfaz. 'praxias' se muestra como Motricidad.
  String get label {
    switch (this) {
      case GameDomain.memoria:
        return 'Memoria';
      case GameDomain.atencion:
        return 'Atención';
      case GameDomain.praxias:
        return 'Motricidad';
    }
  }

  IconData get icon {
    switch (this) {
      case GameDomain.memoria:
        return Icons.spa;
      case GameDomain.atencion:
        return Icons.grid_view;
      case GameDomain.praxias:
        return Icons.gesture;
    }
  }
}

/// Catálogo de juegos por dominio. Para sumar un juego nuevo basta con
/// agregar su GameDefinition a la lista de su dominio.
///
/// Dueños: Memoria – Benjamín, Atención – Eduardo, Motricidad – Daniela.
final Map<GameDomain, List<GameDefinition>> gameCatalog = {
  GameDomain.memoria: const [
    memoriceClasicoDefinition,
    memoriceSecuenciasDefinition,
    queCambioDefinition,
    recuerdeNumeroDefinition,
  ],
  GameDomain.atencion: const [
    secuenciasColoresDefinition,
    tocaCorrectoDefinition,
    contadorObjetosDefinition,
  ],
  GameDomain.praxias: const [
    trazadoGuiadoDefinition,
    conectaPuntosDefinition,
    colorearContornoDefinition,
    phoneTouchDefinition,
    phoneSwipeDefinition,
    phoneDragDefinition,
    phoneListDefinition,
    phoneZoomDefinition,
  ],
};

List<GameDefinition> juegosDeDominio(GameDomain domain) =>
    gameCatalog[domain] ?? const [];

/// Dominio al que corresponde el id de una tarjeta del Home, o null si el id
/// no es de un dominio (por ejemplo 'respiracion').
GameDomain? dominioPorHomeId(String id) {
  for (final d in GameDomain.values) {
    if (d.homeId == id) return d;
  }
  return null;
}
