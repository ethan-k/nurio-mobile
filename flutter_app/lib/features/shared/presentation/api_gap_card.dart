import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

class ApiGapCard extends StatelessWidget {
  const ApiGapCard({
    super.key,
    required this.featureLabel,
    required this.legacyRoutes,
    required this.requiredApiEndpoints,
  });

  final String featureLabel;
  final List<String> legacyRoutes;
  final List<String> requiredApiEndpoints;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;

    return Card(
      color: const Color(0xFFFFF7ED),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.apiGapNativeFeature(featureLabel),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF9A3412),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.apiGapBody,
              style: textTheme.bodySmall?.copyWith(
                color: const Color(0xFF9A3412),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.apiGapLegacyRoutesTitle,
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            for (final route in legacyRoutes)
              Text('- $route', style: textTheme.bodySmall),
            const SizedBox(height: 10),
            Text(
              l10n.apiGapRequiredApiTitle,
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            for (final endpoint in requiredApiEndpoints)
              Text('- $endpoint', style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
