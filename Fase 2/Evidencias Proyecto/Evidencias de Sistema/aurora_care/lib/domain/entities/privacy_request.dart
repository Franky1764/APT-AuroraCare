enum PrivacyRight {
  access('Acceder a mis datos', 'Acceso'),
  correction('Corregir mis datos', 'Rectificación'),
  deleteHistory(
    'Borrar mi historial y conservar mi cuenta',
    'Borrado de historial',
  ),
  deleteAccount('Eliminar mi cuenta y mis datos', 'Eliminación de cuenta'),
  opposition('Oponerme a un uso de mis datos', 'Oposición'),
  portability('Recibir una copia de mis datos', 'Portabilidad'),
  restriction('Solicitar el bloqueo temporal', 'Bloqueo');

  const PrivacyRight(this.label, this.subject);
  final String label;
  final String subject;
}

class PrivacyRequest {
  const PrivacyRequest({required this.right, required this.details});

  static const contact = 'auroracareprivacidad@gmail.com';
  final PrivacyRight right;
  final String details;

  String get subject =>
      'AuroraCare — Solicitud de ${right.subject.toLowerCase()}';

  String get body => [
    'Solicito ejercer mi derecho de ${right.subject.toLowerCase()} en AuroraCare.',
    if (right == PrivacyRight.deleteHistory)
      'Solicito borrar mi historial de prácticas y conservar mi cuenta.',
    if (right == PrivacyRight.deleteAccount) 'Solicito eliminar mi cuenta y los datos asociados que puedan identificarse.',
    '',
    'Detalle de mi solicitud',
    details.trim(),
    '',
    'Correo de mi cuenta en AuroraCare',
    '',
    'Agradezco confirmar la recepción e informar los pasos para verificar mi identidad.',
  ].join('\n');
}
