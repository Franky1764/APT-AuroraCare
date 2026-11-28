import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_text_styles.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  late final Future<Map<String, dynamic>> _policy = _load();

  Future<Map<String, dynamic>> _load() async => Map<String, dynamic>.from(
    jsonDecode(
      await rootBundle.loadString('assets/privacy/privacy_policy.json'),
    ) as Map,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Política de privacidad')),
    body: SafeArea(
      child: FutureBuilder<Map<String, dynamic>>(
        future: _policy,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('No pudimos abrir la política de privacidad.'),
            );
          }
          final policy = snapshot.data;
          if (policy == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final sections = (policy['sections'] as List)
              .cast<Map<String, dynamic>>();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(policy['title'] as String, style: AppTextStyles.heading),
              const SizedBox(height: 8),
              Text('Versión ${policy['version']} · ${policy['updatedAt']}'),
              const SizedBox(height: 12),
              SelectableText(
                '${policy['responsible']}\n${policy['address']}\n${policy['email']}',
              ),
              const SizedBox(height: 20),
              ExpansionPanelList.radio(
                expandedHeaderPadding: EdgeInsets.zero,
                children: [
                  for (final section in sections)
                    ExpansionPanelRadio(
                      value: section['title'] as String,
                      canTapOnHeader: true,
                      headerBuilder: (context, expanded) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          section['title'] as String,
                          style: AppTextStyles.cardTitle,
                        ),
                      ),
                      body: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final paragraph
                                in section['paragraphs'] as List)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: SelectableText(
                                  paragraph as String,
                                  style: AppTextStyles.body,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}
