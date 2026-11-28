import 'package:flutter/material.dart';

/// Imagen de práctica: un ícono con su nombre para el lector de pantalla y
/// para la consigna ("Lleve la flor al recuadro").
class DragImage {
  const DragImage(this.name, this.label, this.icon);

  /// Nombre sin artículo: "flor".
  final String name;

  /// Nombre con artículo: "la flor".
  final String label;
  final IconData icon;
}

/// Imágenes que pueden aparecer. Cada partida sortea cuatro distintas.
const dragImagePool = [
  DragImage('flor', 'la flor', Icons.local_florist_rounded),
  DragImage('sol', 'el sol', Icons.wb_sunny_rounded),
  DragImage('luna', 'la luna', Icons.nightlight_round),
  DragImage('árbol', 'el árbol', Icons.park_rounded),
  DragImage('nube', 'la nube', Icons.cloud_rounded),
  DragImage('casa', 'la casa', Icons.home_rounded),
  DragImage('estrella', 'la estrella', Icons.star_rounded),
  DragImage('corazón', 'el corazón', Icons.favorite_rounded),
  DragImage('taza', 'la taza', Icons.coffee_rounded),
  DragImage('paraguas', 'el paraguas', Icons.umbrella_rounded),
  DragImage('libro', 'el libro', Icons.menu_book_rounded),
  DragImage('bicicleta', 'la bicicleta', Icons.pedal_bike_rounded),
  DragImage('campana', 'la campana', Icons.notifications_rounded),
  DragImage('regalo', 'el regalo', Icons.card_giftcard_rounded),
  DragImage('cámara', 'la cámara', Icons.photo_camera_rounded),
  DragImage('reloj', 'el reloj', Icons.schedule_rounded),
];

/// Dónde empieza la imagen y dónde está el destino. Son variantes de la misma
/// disposición espejada, para que el recorrido cambie de dirección sin que
/// los elementos se encimen.
class DragLayout {
  const DragLayout(this.source, this.target);
  final Alignment source;
  final Alignment target;
}

const dragLayouts = [
  DragLayout(Alignment(-.75, -.65), Alignment(.7, .45)),
  DragLayout(Alignment(.75, -.65), Alignment(-.7, .45)),
  DragLayout(Alignment(-.75, .65), Alignment(.7, -.45)),
  DragLayout(Alignment(.75, .65), Alignment(-.7, -.45)),
];
