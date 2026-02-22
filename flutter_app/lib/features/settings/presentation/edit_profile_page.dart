import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

import '../../../l10n/l10n.dart';
import '../../auth/models/account_summary.dart';
import '../../shared/presentation/api_gap_card.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    super.key,
    required this.account,
    required this.onOpenLogin,
  });

  final AccountSummary? account;
  final Future<void> Function() onOpenLogin;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _displayNameController;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.account?.displayName ?? '',
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final l10n = context.l10n;

    return Scaffold(
      appBar: GFAppBar(title: Text(l10n.editProfileTitle), centerTitle: false),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (account == null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l10n.editProfileSignInRequired),
                      const SizedBox(height: 10),
                      GFButton(
                        onPressed: () => widget.onOpenLogin(),
                        text: l10n.signIn,
                        fullWidthButton: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _displayNameController,
              enabled: account != null,
              decoration: InputDecoration(
                labelText: l10n.displayNameLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              enabled: false,
              decoration: InputDecoration(
                labelText: l10n.emailLabel,
                border: const OutlineInputBorder(),
                hintText: account?.email ?? l10n.editProfileSignInHint,
              ),
            ),
            const SizedBox(height: 12),
            GFButton(
              onPressed: account == null
                  ? null
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.profileUpdateApiNotExposed),
                        ),
                      );
                    },
              text: l10n.saveProfile,
              fullWidthButton: true,
            ),
            const SizedBox(height: 12),
            ApiGapCard(
              featureLabel: l10n.profileEditingFeatureLabel,
              legacyRoutes: const [
                'GET /settings/profile/edit',
                'PATCH /settings/profile',
              ],
              requiredApiEndpoints: const [
                'GET /api/v1/profile',
                'PATCH /api/v1/profile',
              ],
            ),
          ],
        ),
      ),
    );
  }
}
