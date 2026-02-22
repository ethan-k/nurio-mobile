import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:getwidget/getwidget.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../navigation/customer_route_policy.dart';
import '../navigation/nav_destination.dart';

class NurioShellPage extends StatefulWidget {
  const NurioShellPage({
    super.key,
    required this.config,
    this.initialUri,
    this.showBottomNavigation = true,
  });

  final AppConfig config;
  final Uri? initialUri;
  final bool showBottomNavigation;

  @override
  State<NurioShellPage> createState() => _NurioShellPageState();
}

class _NurioShellPageState extends State<NurioShellPage> {
  final AppLinks _appLinks = AppLinks();

  InAppWebViewController? _controller;
  StreamSubscription<Uri>? _deepLinkSubscription;
  late final PullToRefreshController _pullToRefreshController;
  late final CustomerRoutePolicy _routePolicy;

  double _progress = 0;
  String? _loadError;

  NavDestination _selectedDestination = NavDestination.events;

  @override
  void initState() {
    super.initState();

    _routePolicy = CustomerRoutePolicy(baseUri: widget.config.baseUri);
    _selectedDestination = _routePolicy.destinationFor(_startUri);

    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(color: Colors.black87),
      onRefresh: _handlePullToRefresh,
    );

    if (widget.showBottomNavigation) {
      unawaited(_initDeepLinks());
    }
  }

  @override
  void dispose() {
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  Uri get _startUri => widget.initialUri ?? widget.config.startUri;

  Future<void> _initDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _openIncomingUri(initialUri);
      }
    } catch (_) {
      // Ignore malformed initial link values.
    }

    _deepLinkSubscription = _appLinks.uriLinkStream.listen((uri) {
      unawaited(_openIncomingUri(uri));
    }, onError: (_) {});
  }

  Future<void> _openIncomingUri(Uri uri) async {
    final normalizedUri = _normalizeUri(uri);

    if (_routePolicy.shouldOpenExternally(normalizedUri)) {
      await _launchExternal(normalizedUri);
      return;
    }

    if (!_routePolicy.isAllowedInternal(normalizedUri)) {
      _showBlockedRouteMessage(normalizedUri);
      await _navigateToDestination(NavDestination.events);
      return;
    }

    if (_routePolicy.shouldPresentAsModal(normalizedUri)) {
      await _openModalRoute(normalizedUri);
      return;
    }

    await _loadUri(normalizedUri);
  }

  Uri _normalizeUri(Uri rawUri) {
    final normalized = widget.config.resolveUri(rawUri);

    if (normalized.host.toLowerCase() ==
        'www.${widget.config.baseUri.host.toLowerCase()}') {
      return normalized.replace(host: widget.config.baseUri.host);
    }

    return normalized;
  }

  Future<void> _handlePullToRefresh() async {
    final controller = _controller;
    if (controller == null) {
      _pullToRefreshController.endRefreshing();
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      await controller.reload();
    } else {
      final current = await controller.getUrl();
      if (current != null) {
        await controller.loadUrl(urlRequest: URLRequest(url: current));
      } else {
        await controller.reload();
      }
    }
  }

  Future<void> _loadUri(Uri uri) async {
    final controller = _controller;

    if (controller == null) {
      setState(() {
        _selectedDestination = _routePolicy.destinationFor(uri);
      });
      return;
    }

    await _setPullToRefreshEnabled(uri);
    await controller.loadUrl(urlRequest: URLRequest(url: WebUri.uri(uri)));
  }

  Future<void> _navigateToDestination(NavDestination destination) async {
    final uri = switch (destination) {
      NavDestination.home => widget.config.homeUri,
      NavDestination.events => widget.config.eventsUri,
      NavDestination.profile => widget.config.profileUri,
    };

    await _loadUri(uri);
  }

  Future<void> _onDestinationTapped(NavDestination destination) async {
    if (_selectedDestination == destination) {
      await _controller?.reload();
      return;
    }

    setState(() {
      _selectedDestination = destination;
    });

    await _navigateToDestination(destination);
  }

  Future<NavigationActionPolicy> _handleNavigation(
    NavigationAction navigationAction,
  ) async {
    final requestUri = navigationAction.request.url;

    if (requestUri == null) {
      return NavigationActionPolicy.ALLOW;
    }

    final normalizedUri = _normalizeUri(requestUri);

    if (_routePolicy.shouldOpenExternally(normalizedUri)) {
      await _launchExternal(normalizedUri);
      return NavigationActionPolicy.CANCEL;
    }

    if (!_routePolicy.isAllowedInternal(normalizedUri)) {
      _showBlockedRouteMessage(normalizedUri);
      return NavigationActionPolicy.CANCEL;
    }

    final isMainFrame = navigationAction.isForMainFrame;
    if (isMainFrame && _routePolicy.shouldPresentAsModal(normalizedUri)) {
      unawaited(_openModalRoute(normalizedUri));
      return NavigationActionPolicy.CANCEL;
    }

    return NavigationActionPolicy.ALLOW;
  }

  Future<PermissionResponse> _handlePermissionRequest(
    PermissionRequest request,
  ) async {
    final permissionsToRequest = <Permission>{};

    if (request.resources.contains(PermissionResourceType.CAMERA) ||
        request.resources.contains(
          PermissionResourceType.CAMERA_AND_MICROPHONE,
        )) {
      permissionsToRequest.add(Permission.camera);
    }

    if (request.resources.contains(PermissionResourceType.MICROPHONE) ||
        request.resources.contains(
          PermissionResourceType.CAMERA_AND_MICROPHONE,
        )) {
      permissionsToRequest.add(Permission.microphone);
    }

    if (request.resources.contains(PermissionResourceType.GEOLOCATION)) {
      permissionsToRequest.add(Permission.locationWhenInUse);
    }

    if (permissionsToRequest.isNotEmpty) {
      final statuses = await Future.wait(
        permissionsToRequest.map((permission) => permission.request()),
      );
      final granted = statuses.every(
        (status) => status.isGranted || status.isLimited,
      );

      if (!granted) {
        return PermissionResponse(
          resources: request.resources,
          action: PermissionResponseAction.DENY,
        );
      }
    }

    return PermissionResponse(
      resources: request.resources,
      action: PermissionResponseAction.GRANT,
    );
  }

  Future<void> _launchExternal(Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched) {
      return;
    }

    final fallbackUri = _extractIntentFallbackUri(uri);
    if (fallbackUri != null) {
      final fallbackLaunched = await launchUrl(
        fallbackUri,
        mode: LaunchMode.externalApplication,
      );
      if (fallbackLaunched) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to open external link: $uri')),
    );
  }

  Uri? _extractIntentFallbackUri(Uri uri) {
    if (uri.scheme.toLowerCase() != 'intent') {
      return null;
    }

    final full = uri.toString();
    const marker = 'S.browser_fallback_url=';
    final markerIndex = full.indexOf(marker);
    if (markerIndex == -1) {
      return null;
    }

    final start = markerIndex + marker.length;
    final end = full.indexOf(';', start);
    if (end == -1 || end <= start) {
      return null;
    }

    final raw = full.substring(start, end);
    final decoded = Uri.decodeComponent(raw);
    return Uri.tryParse(decoded);
  }

  Future<void> _setPullToRefreshEnabled(Uri uri) {
    return _pullToRefreshController.setEnabled(
      _routePolicy.isPullToRefreshEnabled(uri),
    );
  }

  void _showBlockedRouteMessage(Uri uri) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Blocked unsupported route: ${uri.path.isEmpty ? uri.toString() : uri.path}',
        ),
      ),
    );
  }

  Future<void> _openModalRoute(Uri uri) async {
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      clipBehavior: Clip.antiAlias,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.94,
          child: _ModalWebViewSheet(
            initialUri: uri,
            routePolicy: _routePolicy,
            onPermissionRequest: _handlePermissionRequest,
            onOpenExternal: _launchExternal,
            onOpenInRoot: (nextUri) async {
              Navigator.of(context).pop();
              await _loadUri(nextUri);
            },
            onBlockedRoute: _showBlockedRouteMessage,
          ),
        );
      },
    );
  }

  Future<bool> _handleBackPressed() async {
    final controller = _controller;

    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }

        final canExit = await _handleBackPressed();
        if (canExit && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: GFAppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          title: Text(widget.config.appTitle),
          centerTitle: false,
          actions: [
            GFIconButton(
              tooltip: 'Refresh',
              onPressed: () => _controller?.reload(),
              type: GFButtonType.transparent,
              color: Theme.of(context).colorScheme.primary,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                initialSettings: InAppWebViewSettings(
                  isInspectable: kDebugMode,
                  javaScriptEnabled: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  iframeAllow: 'camera; microphone; geolocation',
                  iframeAllowFullscreen: true,
                  supportZoom: false,
                  useShouldOverrideUrlLoading: true,
                  useOnDownloadStart: true,
                ),
                initialUrlRequest: URLRequest(url: WebUri.uri(_startUri)),
                pullToRefreshController: _pullToRefreshController,
                onWebViewCreated: (controller) {
                  _controller = controller;
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  return _handleNavigation(navigationAction);
                },
                onCreateWindow: (controller, createWindowAction) async {
                  final popupUri = createWindowAction.request.url;
                  if (popupUri == null) {
                    return false;
                  }

                  final normalizedUri = _normalizeUri(popupUri);
                  if (_routePolicy.shouldOpenExternally(normalizedUri)) {
                    await _launchExternal(normalizedUri);
                    return true;
                  }

                  if (!_routePolicy.isAllowedInternal(normalizedUri)) {
                    _showBlockedRouteMessage(normalizedUri);
                    return true;
                  }

                  if (_routePolicy.shouldPresentAsModal(normalizedUri)) {
                    await _openModalRoute(normalizedUri);
                    return true;
                  }

                  await _loadUri(normalizedUri);
                  return true;
                },
                onLoadStart: (controller, url) {
                  final normalizedUri = url == null ? null : _normalizeUri(url);

                  if (normalizedUri != null) {
                    unawaited(_setPullToRefreshEnabled(normalizedUri));
                  }

                  setState(() {
                    _loadError = null;
                    if (normalizedUri != null) {
                      _selectedDestination = _routePolicy.destinationFor(
                        normalizedUri,
                      );
                    }
                  });
                },
                onLoadStop: (controller, url) {
                  _pullToRefreshController.endRefreshing();

                  final normalizedUri = url == null ? null : _normalizeUri(url);

                  setState(() {
                    _loadError = null;
                    _progress = 1;
                    if (normalizedUri != null) {
                      _selectedDestination = _routePolicy.destinationFor(
                        normalizedUri,
                      );
                    }
                  });
                },
                onReceivedError: (controller, request, error) {
                  _pullToRefreshController.endRefreshing();
                  if (request.isForMainFrame == true) {
                    setState(() {
                      _loadError = error.description;
                    });
                  }
                },
                onReceivedHttpError: (controller, request, errorResponse) {
                  _pullToRefreshController.endRefreshing();
                  final statusCode = errorResponse.statusCode ?? 0;
                  if (request.isForMainFrame == true && statusCode >= 400) {
                    setState(() {
                      _loadError = 'HTTP $statusCode';
                    });
                  }
                },
                onProgressChanged: (controller, progress) {
                  if (progress >= 100) {
                    _pullToRefreshController.endRefreshing();
                  }

                  setState(() {
                    _progress = progress / 100;
                  });
                },
                onUpdateVisitedHistory: (controller, url, isReload) {
                  if (url == null) {
                    return;
                  }

                  final normalizedUri = _normalizeUri(url);
                  unawaited(_setPullToRefreshEnabled(normalizedUri));

                  setState(() {
                    _selectedDestination = _routePolicy.destinationFor(
                      normalizedUri,
                    );
                  });
                },
                onPermissionRequest: (controller, request) async {
                  return _handlePermissionRequest(request);
                },
                onDownloadStartRequest:
                    (controller, downloadStartRequest) async {
                      await _launchExternal(downloadStartRequest.url);
                    },
              ),
              if (_progress < 1)
                LinearProgressIndicator(
                  value: _progress,
                  minHeight: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              if (_loadError != null)
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: Material(
                    color: Colors.transparent,
                    child: Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Could not load this page. ${_loadError ?? ''}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            GFButton(
                              size: GFSize.SMALL,
                              color: Theme.of(context).colorScheme.primary,
                              onPressed: () {
                                _controller?.reload();
                              },
                              text: 'Retry',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: widget.showBottomNavigation
            ? NavigationBar(
                selectedIndex: _selectedDestination.index,
                destinations: NavDestination.values
                    .map(
                      (destination) => NavigationDestination(
                        icon: Icon(destination.icon),
                        label: destination.label,
                      ),
                    )
                    .toList(),
                onDestinationSelected: (index) {
                  final destination = NavDestination.values[index];
                  unawaited(_onDestinationTapped(destination));
                },
              )
            : null,
      ),
    );
  }
}

class _ModalWebViewSheet extends StatefulWidget {
  const _ModalWebViewSheet({
    required this.initialUri,
    required this.routePolicy,
    required this.onPermissionRequest,
    required this.onOpenExternal,
    required this.onOpenInRoot,
    required this.onBlockedRoute,
  });

  final Uri initialUri;
  final CustomerRoutePolicy routePolicy;
  final Future<PermissionResponse> Function(PermissionRequest request)
  onPermissionRequest;
  final Future<void> Function(Uri uri) onOpenExternal;
  final Future<void> Function(Uri uri) onOpenInRoot;
  final void Function(Uri uri) onBlockedRoute;

  @override
  State<_ModalWebViewSheet> createState() => _ModalWebViewSheetState();
}

class _ModalWebViewSheetState extends State<_ModalWebViewSheet> {
  InAppWebViewController? _controller;
  double _progress = 0;

  Future<void> _promoteIfNeeded(Uri uri) async {
    if (widget.routePolicy.shouldPresentAsModal(uri)) {
      return;
    }

    if (widget.routePolicy.isAllowedInternal(uri)) {
      await widget.onOpenInRoot(uri);
    }
  }

  Future<NavigationActionPolicy> _handleNavigation(
    NavigationAction navigationAction,
  ) async {
    final requestUri = navigationAction.request.url;
    if (requestUri == null) {
      return NavigationActionPolicy.ALLOW;
    }

    if (widget.routePolicy.shouldOpenExternally(requestUri)) {
      await widget.onOpenExternal(requestUri);
      return NavigationActionPolicy.CANCEL;
    }

    if (!widget.routePolicy.isAllowedInternal(requestUri)) {
      widget.onBlockedRoute(requestUri);
      return NavigationActionPolicy.CANCEL;
    }

    final isMainFrame = navigationAction.isForMainFrame;
    if (isMainFrame && !widget.routePolicy.shouldPresentAsModal(requestUri)) {
      await widget.onOpenInRoot(requestUri);
      return NavigationActionPolicy.CANCEL;
    }

    return NavigationActionPolicy.ALLOW;
  }

  Future<bool> _onBackPressed() async {
    final controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }

        final canClose = await _onBackPressed();
        if (canClose && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Column(
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              children: [
                GFIconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                  type: GFButtonType.transparent,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    'Nurio',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (_progress < 1)
                  SizedBox(
                    width: 72,
                    child: LinearProgressIndicator(value: _progress),
                  )
                else
                  GFIconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _controller?.reload(),
                    tooltip: 'Refresh',
                    type: GFButtonType.transparent,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
          ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri.uri(widget.initialUri)),
              initialSettings: InAppWebViewSettings(
                isInspectable: kDebugMode,
                javaScriptEnabled: true,
                javaScriptCanOpenWindowsAutomatically: true,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                iframeAllow: 'camera; microphone; geolocation',
                iframeAllowFullscreen: true,
                supportZoom: false,
                useShouldOverrideUrlLoading: true,
                useOnDownloadStart: true,
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
              },
              shouldOverrideUrlLoading: (controller, action) async {
                return _handleNavigation(action);
              },
              onCreateWindow: (controller, createWindowAction) async {
                final popupUri = createWindowAction.request.url;
                if (popupUri == null) {
                  return false;
                }

                if (widget.routePolicy.shouldOpenExternally(popupUri)) {
                  await widget.onOpenExternal(popupUri);
                  return true;
                }

                if (!widget.routePolicy.isAllowedInternal(popupUri)) {
                  widget.onBlockedRoute(popupUri);
                  return true;
                }

                if (!widget.routePolicy.shouldPresentAsModal(popupUri)) {
                  await widget.onOpenInRoot(popupUri);
                  return true;
                }

                await _controller?.loadUrl(
                  urlRequest: URLRequest(url: WebUri.uri(popupUri)),
                );
                return true;
              },
              onLoadStart: (controller, url) {
                if (url != null) {
                  unawaited(_promoteIfNeeded(url));
                }
              },
              onProgressChanged: (controller, progress) {
                setState(() {
                  _progress = progress / 100;
                });
              },
              onPermissionRequest: (controller, request) async {
                return widget.onPermissionRequest(request);
              },
              onDownloadStartRequest: (controller, downloadStartRequest) async {
                await widget.onOpenExternal(downloadStartRequest.url);
              },
            ),
          ),
        ],
      ),
    );
  }
}
