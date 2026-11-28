import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key, this.isCaregiver = false});

  final bool isCaregiver;

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _controllers = <String, ExpansibleController>{};
  ExpansibleController? _openQuestion;

  ExpansibleController _controllerFor(String question) =>
      _controllers.putIfAbsent(question, ExpansibleController.new);

  void _onExpansionChanged(ExpansibleController controller, bool expanded) {
    if (expanded) {
      final previous = _openQuestion;
      _openQuestion = controller;
      previous?.collapse();
    } else if (_openQuestion == controller) {
      _openQuestion = null;
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final privacy = [
      (
        '¿Qué datos guarda AuroraCare?',
        'Su cuenta guarda datos como su correo y nombre. Los resultados '
            'de los ejercicios se guardan en este teléfono y pueden '
            'sincronizarse con Firebase bajo un código separado.',
      ),
      (
        '¿Qué información ve un cuidador vinculado?',
        'Al vincular un cuidador por QR, el cuidador puede consultar un resumen '
            'de la actividad, con datos como la fecha de la última práctica '
            'y los resultados por área. Las respuestas personales de '
            '«Mis recuerdos» se guardan en el dispositivo y quedan fuera '
            'del resumen compartido.',
      ),
      (
        '¿Cómo se deja de compartir el progreso?',
        'El adulto mayor puede abrir «Cuidador vinculado» desde «Mi perfil» y elegir '
            '«Desvincular cuidador». Al confirmarlo, el cuidador pierde '
            'el acceso al resumen desde su cuenta. Los informes que ya '
            'haya guardado o compartido quedan en manos de quien los recibió.',
      ),
      (
        '¿Qué recibe OpenAI al redactar el informe?',
        'Cuando se usa OpenAI para redactar el informe, recibe datos '
            'resumidos de las prácticas, como el número de sesiones por área '
            'y sus indicadores de progreso. El nombre, el correo y los '
            'identificadores de cuenta o de sesión quedan fuera del envío.',
      ),
      (
        '¿Qué pasa si comparto un PDF?',
        'Al tocar «Compartir PDF», usted elige la aplicación y la persona '
            'destinataria. Revise el contenido y el destinatario antes de '
            'enviarlo. Quien reciba el archivo podrá guardar una copia.',
      ),
    ];

    final practicalHelp = widget.isCaregiver
        ? const [
            (
              '¿Cómo vinculo a mi familiar?',
              'Pídale que abra «Vincular Cuidador» en su perfil y genere '
                  'un código QR. En su panel, toque «Vincular a un familiar» '
                  'y escanee el código. Si venció, pídale que genere otro.',
            ),
            (
              '¿Cómo activo los avisos?',
              'Abra el perfil o los ajustes del cuidador y active '
                  '«Notificaciones». Si Android le pide permiso, elija '
                  '«Permitir». Si antes lo rechazó, busque AuroraCare '
                  'en los ajustes de notificaciones del teléfono.',
            ),
          ]
        : const [
            (
              '¿Dónde veo o guardo mi informe?',
              'En «Mi perfil», toque «Mi informe de progreso». Elija '
                  '«Guardar PDF» para conservar el archivo en su teléfono '
                  'o «Compartir PDF» para enviarlo a quien usted decida.',
            ),
            (
              '¿Cómo ajusto el sonido o la vibración?',
              'En «Mi perfil», puede apagar los efectos en «Sonidos», '
                  'elegir su volumen y usar «Probar vibración». Si el '
                  'teléfono tiene apagada la respuesta táctil, la app '
                  'ofrece abrir los ajustes de sonido.',
            ),
            (
              '¿Cómo recupero mi contraseña?',
              'En la pantalla de inicio de sesión, toque «Olvidé mi contraseña» '
                  'y escriba el correo con que se registró. '
                  'Si el mensaje tarda en llegar, revise también el correo '
                  'no deseado.',
            ),
          ];

    return Scaffold(
      appBar: AppBar(title: const Text('Ayuda y soporte')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _HelpSection(
              title: 'Privacidad y datos',
              icon: Icons.lock_outline,
              entries: privacy,
              controllerFor: _controllerFor,
              onExpansionChanged: _onExpansionChanged,
            ),
            const SizedBox(height: 20),
            _HelpSection(
              title: 'Cómo usar AuroraCare',
              icon: Icons.help_outline,
              entries: practicalHelp,
              controllerFor: _controllerFor,
              onExpansionChanged: _onExpansionChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({
    required this.title,
    required this.icon,
    required this.entries,
    required this.controllerFor,
    required this.onExpansionChanged,
  });

  final String title;
  final IconData icon;
  final List<(String, String)> entries;
  final ExpansibleController Function(String) controllerFor;
  final void Function(ExpansibleController, bool) onExpansionChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: AppTextStyles.heading)),
          ],
        ),
        const SizedBox(height: 8),
        for (final (question, answer) in entries)
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              controller: controllerFor(question),
              onExpansionChanged: (expanded) =>
                  onExpansionChanged(controllerFor(question), expanded),
              title: Text(question, style: AppTextStyles.cardTitle),
              iconColor: AppColors.primary,
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              children: [Text(answer, style: AppTextStyles.body)],
            ),
          ),
      ],
    );
  }
}
