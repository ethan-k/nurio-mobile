import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

import '../../../config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/auth_token_storage.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/login_page.dart';
import '../../commerce/presentation/event_checkout_page.dart';
import '../../commerce/presentation/pass_packages_page.dart';
import '../../commerce/presentation/payment_history_page.dart';
import '../../commerce/presentation/tickets_page.dart';
import '../../commerce/presentation/wallet_credits_page.dart';
import '../../events/data/events_repository.dart';
import '../../events/models/event_summary.dart';
import '../../events/presentation/event_detail_page.dart';
import '../../events/presentation/events_controller.dart';
import '../../events/presentation/events_page.dart';
import '../../home/presentation/home_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../../settings/presentation/edit_profile_page.dart';
import '../../settings/presentation/event_history_page.dart';
import '../../settings/presentation/notifications_page.dart';
import '../../settings/presentation/referrals_page.dart';

enum ShellTab { home, events, profile }

class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key, required this.config});

  final AppConfig config;

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  late final ApiClient _apiClient;
  late final AuthController _authController;
  late final EventsController _eventsController;

  ShellTab _tab = ShellTab.home;

  @override
  void initState() {
    super.initState();

    _apiClient = ApiClient(baseUri: widget.config.baseUri);

    final authRepository = AuthRepository(
      apiClient: _apiClient,
      storage: AuthTokenStorage(),
    );
    _authController = AuthController(repository: authRepository)
      ..addListener(_onAuthControllerChanged);

    _eventsController = EventsController(
      repository: EventsRepository(apiClient: _apiClient),
    )..addListener(_onEventsControllerChanged);

    _boot();
  }

  @override
  void dispose() {
    _authController
      ..removeListener(_onAuthControllerChanged)
      ..dispose();
    _eventsController
      ..removeListener(_onEventsControllerChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    await _authController.initialize();
    await _eventsController.loadInitial();
  }

  void _onAuthControllerChanged() {
    _apiClient.accessToken = _authController.accessToken;
    if (mounted) {
      setState(() {});
    }
  }

  void _onEventsControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openLogin() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LoginPage(authController: _authController),
      ),
    );
  }

  void _openEvent(EventSummary event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventDetailPage(
          event: event,
          onOpenCheckout: () => _openCheckout(event),
          onOpenPassPackages: _openPassPackages,
        ),
      ),
    );
  }

  Future<void> _openCheckout(EventSummary event) async {
    if (!_authController.isAuthenticated) {
      await _openLogin();
      if (!_authController.isAuthenticated || !mounted) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventCheckoutPage(
          event: event,
          isAuthenticated: _authController.isAuthenticated,
          onOpenLogin: _openLogin,
          onOpenPassPackages: _openPassPackages,
        ),
      ),
    );
  }

  void _openPassPackages() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PassPackagesPage()));
  }

  void _openTickets() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TicketsPage()));
  }

  void _openPayments() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PaymentHistoryPage()));
  }

  void _openWalletCredits() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WalletCreditsPage()));
  }

  void _openReferrals() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ReferralsPage()));
  }

  void _openEventHistory() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const EventHistoryPage()));
  }

  void _openNotifications() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
  }

  void _openEditProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditProfilePage(
          account: _authController.account,
          onOpenLogin: _openLogin,
        ),
      ),
    );
  }

  void _openProfileSetting(ProfileSettingDestination destination) {
    switch (destination) {
      case ProfileSettingDestination.editProfile:
        _openEditProfile();
        break;
      case ProfileSettingDestination.notifications:
        _openNotifications();
        break;
      case ProfileSettingDestination.tickets:
        _openTickets();
        break;
      case ProfileSettingDestination.payments:
        _openPayments();
        break;
      case ProfileSettingDestination.walletCredits:
        _openWalletCredits();
        break;
      case ProfileSettingDestination.referrals:
        _openReferrals();
        break;
      case ProfileSettingDestination.eventHistory:
        _openEventHistory();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_tab) {
      ShellTab.home => HomePage(
        account: _authController.account,
        events: _eventsController.events,
        onOpenEvents: () {
          setState(() {
            _tab = ShellTab.events;
          });
        },
        onOpenEvent: _openEvent,
        onOpenPassPackages: _openPassPackages,
        onOpenTickets: _openTickets,
        onOpenPayments: _openPayments,
      ),
      ShellTab.events => EventsPage(
        controller: _eventsController,
        onOpenEvent: _openEvent,
      ),
      ShellTab.profile => ProfilePage(
        authController: _authController,
        onOpenLogin: _openLogin,
        onOpenSetting: _openProfileSetting,
      ),
    };

    return Scaffold(
      appBar: GFAppBar(
        title: const Text('Nurio'),
        centerTitle: false,
        actions: [
          GFIconButton(
            icon: Icon(
              _authController.isAuthenticated
                  ? Icons.verified_user_outlined
                  : Icons.login_outlined,
            ),
            onPressed: _authController.isAuthenticated ? null : _openLogin,
            tooltip: _authController.isAuthenticated ? 'Signed in' : 'Sign in',
            type: GFButtonType.transparent,
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (index) {
          setState(() {
            _tab = ShellTab.values[index];
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
