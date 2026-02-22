import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

import '../../../l10n/l10n.dart';
import '../../shared/presentation/api_gap_card.dart';

class PassPackagesPage extends StatelessWidget {
  const PassPackagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final packages = <_SamplePackage>[
      _SamplePackage(
        name: l10n.passPackageOneName,
        description: l10n.passPackageOneDescription,
        price: l10n.passPackageOnePrice,
      ),
      _SamplePackage(
        name: l10n.passPackageThreeName,
        description: l10n.passPackageThreeDescription,
        price: l10n.passPackageThreePrice,
      ),
      _SamplePackage(
        name: l10n.passPackageFiveName,
        description: l10n.passPackageFiveDescription,
        price: l10n.passPackageFivePrice,
      ),
    ];

    return Scaffold(
      appBar: GFAppBar(title: Text(l10n.passPackagesTitle), centerTitle: false),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.passPackagesIntro,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            ...packages.map((pkg) {
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
              featureLabel: l10n.passPackagePurchaseFeatureLabel,
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
                  SnackBar(content: Text(l10n.passPackagesApiNotExposed)),
                );
              },
              text: l10n.passPackagesPurchaseButton,
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
