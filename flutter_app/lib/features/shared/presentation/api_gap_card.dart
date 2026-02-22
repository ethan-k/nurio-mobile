import 'package:flutter/material.dart';

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

    return Card(
      color: const Color(0xFFFFF7ED),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Native $featureLabel',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF9A3412),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This screen is implemented natively and intentionally does not '
              'fall back to WebView. The backend still needs mobile JSON '
              'endpoints for full data and mutation support.',
              style: textTheme.bodySmall?.copyWith(
                color: const Color(0xFF9A3412),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Legacy web routes',
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            for (final route in legacyRoutes)
              Text('- $route', style: textTheme.bodySmall),
            const SizedBox(height: 10),
            Text(
              'Required mobile API endpoints',
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
