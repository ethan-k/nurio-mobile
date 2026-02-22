import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

import '../../shared/presentation/api_gap_card.dart';

class PassPackagesPage extends StatelessWidget {
  const PassPackagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GFAppBar(title: const Text('Pass Packages'), centerTitle: false),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Choose the pass package that fits your event plans.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            ..._samplePackages.map((pkg) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pkg.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(pkg.description),
                        const SizedBox(height: 8),
                        Text(
                          pkg.price,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            ApiGapCard(
              featureLabel: 'Pass Package Purchase',
              legacyRoutes: const [
                'GET /pass_packages',
                'POST /pass_packages/:id/purchase',
                'GET /pass_packages/:id/payment_summary',
                'POST /pass_packages/:id/pay_with_wallet',
              ],
              requiredApiEndpoints: const [
                'GET /api/v1/pass_packages',
                'POST /api/v1/pass_packages/:id/orders',
                'GET /api/v1/pass_packages/:id/payment_summary',
                'POST /api/v1/pass_packages/:id/pay_with_wallet',
              ],
            ),
            const SizedBox(height: 10),
            GFButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Pass purchase API is not exposed yet for mobile.',
                    ),
                  ),
                );
              },
              text: 'Purchase Pass Package',
              fullWidthButton: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _SamplePackage {
  const _SamplePackage({
    required this.name,
    required this.description,
    required this.price,
  });

  final String name;
  final String description;
  final String price;
}

const List<_SamplePackage> _samplePackages = <_SamplePackage>[
  _SamplePackage(
    name: '1-Event Pass',
    description: 'Single event entry for flexible scheduling.',
    price: 'KRW 7,000',
  ),
  _SamplePackage(
    name: '3-Event Bundle',
    description: 'Lower per-event price for regular attendees.',
    price: 'KRW 18,000',
  ),
  _SamplePackage(
    name: '5-Event Bundle',
    description: 'Best value bundle for frequent participation.',
    price: 'KRW 28,000',
  ),
];
