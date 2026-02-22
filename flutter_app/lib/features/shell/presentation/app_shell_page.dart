import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

import '../../../config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/auth_token_storage.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/login_page.dart';
import '../../events/data/events_repository.dart';
import '../../events/models/event_summary.dart';
import '../../events/presentation/event_detail_page.dart';
import '../../events/presentation/events_controller.dart';
import '../../events/presentation/events_page.dart';
import '../../home/presentation/home_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../../web/presentation/web_flow_page.dart';

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

  void _openWebPath(String path) {
    final uri = widget.config.resolvePath(path);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WebFlowPage(config: widget.config, initialUri: uri),
      ),
    );
  }

  void _openEvent(EventSummary event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventDetailPage(event: event, config: widget.config),
      ),
    );
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
        onOpenWebPath: _openWebPath,
      ),
      ShellTab.events => EventsPage(
        controller: _eventsController,
        onOpenEvent: _openEvent,
      ),
      ShellTab.profile => ProfilePage(
        authController: _authController,
        onOpenLogin: _openLogin,
        onOpenWebPath: _openWebPath,
      ),
    };

    return Scaffold(
      appBar: GFAppBar(
        title: const Text('Nurio'),
        centerTitle: false,
        actions: [
          GFIconButton(
            icon: const Icon(Icons.language),
            onPressed: () => _openWebPath('/events'),
            tooltip: 'Open full web flow',
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
