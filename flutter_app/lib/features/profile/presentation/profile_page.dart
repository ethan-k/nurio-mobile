import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

import '../../../l10n/l10n.dart';
import '../../auth/presentation/auth_controller.dart';

enum ProfileSettingDestination {
  editProfile,
  notifications,
  tickets,
  payments,
  walletCredits,
  referrals,
  eventHistory,
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.authController,
    required this.onOpenLogin,
    required this.onOpenSetting,
  });

  final AuthController authController;
  final Future<void> Function() onOpenLogin;
  final ValueChanged<ProfileSettingDestination> onOpenSetting;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    widget.authController.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    widget.authController.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = widget.authController;

    if (auth.isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Text(
            l10n.profileTitle,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _AccountCard(authController: auth, onOpenLogin: widget.onOpenLogin),
          const SizedBox(height: 14),
          _SettingsList(
            enabled: auth.isAuthenticated,
            onOpenSetting: widget.onOpenSetting,
          ),
          if (auth.isAuthenticated) ...[
            const SizedBox(height: 16),
            GFButton(
              onPressed: () => auth.logout(),
              text: l10n.signOut,
              color: const Color(0xFFEF4444),
              fullWidthButton: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.authController, required this.onOpenLogin});

  final AuthController authController;
  final Future<void> Function() onOpenLogin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (!authController.isAuthenticated) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.profileSignedOutDescription),
              const SizedBox(height: 10),
              GFButton(
                onPressed: () => onOpenLogin(),
                text: l10n.signIn,
                fullWidthButton: true,
              ),
            ],
          ),
        ),
      );
    }

    final account = authController.account!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              account.displayName.isEmpty
                  ? l10n.profileAccountFallbackName
                  : account.displayName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(account.email),
          ],
        ),
      ),
    );
  }
}

class _SettingsList extends StatelessWidget {
  const _SettingsList({required this.enabled, required this.onOpenSetting});

  final bool enabled;
  final ValueChanged<ProfileSettingDestination> onOpenSetting;

  @override
  Widget build(BuildContext context) {
    final items = <_SettingItem>[
      const _SettingItem(
        ProfileSettingDestination.editProfile,
        Icons.person_outline,
      ),
      const _SettingItem(
        ProfileSettingDestination.notifications,
        Icons.notifications_none,
      ),
      const _SettingItem(
        ProfileSettingDestination.tickets,
        Icons.confirmation_num_outlined,
      ),
      const _SettingItem(
        ProfileSettingDestination.payments,
        Icons.credit_card_outlined,
      ),
      const _SettingItem(
        ProfileSettingDestination.walletCredits,
        Icons.account_balance_wallet_outlined,
      ),
      const _SettingItem(
        ProfileSettingDestination.referrals,
        Icons.group_outlined,
      ),
      const _SettingItem(ProfileSettingDestination.eventHistory, Icons.history),
    ];

    return Card(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            ListTile(
              leading: Icon(items[i].icon),
              title: Text(_titleFor(context, items[i].destination)),
              trailing: const Icon(Icons.chevron_right),
              enabled: enabled,
              onTap: enabled ? () => onOpenSetting(items[i].destination) : null,
            ),
        ],
      ),
    );
  }

  String _titleFor(
    BuildContext context,
    ProfileSettingDestination destination,
  ) {
    final l10n = context.l10n;
    switch (destination) {
      case ProfileSettingDestination.editProfile:
        return l10n.settingEditProfile;
      case ProfileSettingDestination.notifications:
        return l10n.settingNotifications;
      case ProfileSettingDestination.tickets:
        return l10n.settingTickets;
      case ProfileSettingDestination.payments:
        return l10n.settingPaymentHistory;
      case ProfileSettingDestination.walletCredits:
        return l10n.settingWalletCredits;
      case ProfileSettingDestination.referrals:
        return l10n.settingReferrals;
      case ProfileSettingDestination.eventHistory:
        return l10n.settingEventHistory;
    }
  }
}

class _SettingItem {
  const _SettingItem(this.destination, this.icon);

  final ProfileSettingDestination destination;
  final IconData icon;
}
