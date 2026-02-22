import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

import '../../auth/presentation/auth_controller.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.authController,
    required this.onOpenLogin,
    required this.onOpenWebPath,
  });

  final AuthController authController;
  final Future<void> Function() onOpenLogin;
  final ValueChanged<String> onOpenWebPath;

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
    final auth = widget.authController;

    if (auth.isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Text(
            'Profile & Settings',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _AccountCard(authController: auth, onOpenLogin: widget.onOpenLogin),
          const SizedBox(height: 14),
          _SettingsList(
            enabled: auth.isAuthenticated,
            onOpenWebPath: widget.onOpenWebPath,
          ),
          if (auth.isAuthenticated) ...[
            const SizedBox(height: 16),
            GFButton(
              onPressed: () => auth.logout(),
              text: 'Sign Out',
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
    if (!authController.isAuthenticated) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Sign in to access tickets, wallet credits, and payment history.',
              ),
              const SizedBox(height: 10),
              GFButton(
                onPressed: () => onOpenLogin(),
                text: 'Sign In',
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
                  ? 'Nurio Member'
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
  const _SettingsList({required this.enabled, required this.onOpenWebPath});

  final bool enabled;
  final ValueChanged<String> onOpenWebPath;

  @override
  Widget build(BuildContext context) {
    final items = <_SettingItem>[
      const _SettingItem(
        'Edit Profile',
        '/settings/profile/edit',
        Icons.person_outline,
      ),
      const _SettingItem(
        'Notifications',
        '/settings/notifications',
        Icons.notifications_none,
      ),
      const _SettingItem(
        'Tickets',
        '/settings/tickets',
        Icons.confirmation_num_outlined,
      ),
      const _SettingItem(
        'Payment History',
        '/settings/payments',
        Icons.credit_card_outlined,
      ),
      const _SettingItem(
        'Wallet Credits',
        '/settings/wallet_credits',
        Icons.account_balance_wallet_outlined,
      ),
      const _SettingItem(
        'Referrals',
        '/settings/referrals',
        Icons.group_outlined,
      ),
      const _SettingItem(
        'Event History',
        '/settings/event_history',
        Icons.history,
      ),
    ];

    return Card(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            ListTile(
              leading: Icon(items[i].icon),
              title: Text(items[i].title),
              trailing: const Icon(Icons.chevron_right),
              enabled: enabled,
              onTap: enabled ? () => onOpenWebPath(items[i].path) : null,
            ),
        ],
      ),
    );
  }
}

class _SettingItem {
  const _SettingItem(this.title, this.path, this.icon);

  final String title;
  final String path;
  final IconData icon;
}
