import 'nav_destination.dart';

class CustomerRoutePolicy {
  CustomerRoutePolicy({required this.baseUri});

  final Uri baseUri;

  static final List<RegExp> _blockedPathPatterns = <RegExp>[
    RegExp(r'^/admin(?:/|$)', caseSensitive: false),
    RegExp(r'^/tutors?(?:/|$)', caseSensitive: false),
    RegExp(r'^/tutoring(?:/|$)', caseSensitive: false),
    RegExp(r'^/english-tutoring(?:/|$)', caseSensitive: false),
    RegExp(r'^/api/v1/tutors?(?:/|$)', caseSensitive: false),
    RegExp(r'^/api/v1/bookings(?:/|$)', caseSensitive: false),
    RegExp(r'^/api/v1/slot_holds(?:/|$)', caseSensitive: false),
    RegExp(r'^/api/v1/credits(?:/|$)', caseSensitive: false),
    RegExp(r'^/api/v1/tutor(?:/|$)', caseSensitive: false),
  ];

  static final List<RegExp> _modalPathPatterns = <RegExp>[
    RegExp(r'^/new$', caseSensitive: false),
    RegExp(r'^/edit$', caseSensitive: false),
    RegExp(r'.*/new$', caseSensitive: false),
    RegExp(r'.*/edit$', caseSensitive: false),
    RegExp(r'^/auth/login(?:/|$)', caseSensitive: false),
    RegExp(r'^/auth/create-account(?:/|$)', caseSensitive: false),
    RegExp(r'^/auth/verify(?:/|$)', caseSensitive: false),
    RegExp(r'^/signup(?:/|$)', caseSensitive: false),
    RegExp(r'^/onboarding(?:/|$)', caseSensitive: false),
    RegExp(r'^/onboardings/wizard(?:/|$)', caseSensitive: false),
    RegExp(r'^/orders/new(?:/|$)', caseSensitive: false),
    RegExp(r'^/orders/[^/]+/payment_summary(?:/|$)', caseSensitive: false),
    RegExp(r'^/pass_packages/[^/]+/purchase(?:/|$)', caseSensitive: false),
    RegExp(
      r'^/pass_packages/[^/]+/payment_summary(?:/|$)',
      caseSensitive: false,
    ),
    RegExp(r'^/events/[^/]+/reviews/new(?:/|$)', caseSensitive: false),
    RegExp(r'^/event_series/[^/]+/reviews/new(?:/|$)', caseSensitive: false),
  ];

  bool isInternal(Uri uri) {
    final scheme = uri.scheme.toLowerCase();

    if (scheme.isEmpty) {
      return true;
    }

    if (scheme != 'http' && scheme != 'https') {
      return false;
    }

    if (uri.host.isEmpty) {
      return true;
    }

    return _isNurioHost(uri.host);
  }

  bool isAllowedInternal(Uri uri) {
    return isInternal(uri) && !isBlocked(uri);
  }

  bool isBlocked(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host.startsWith('admin.') || host.startsWith('tutors.')) {
      return true;
    }

    final path = uri.path.isEmpty ? '/' : uri.path;
    return _blockedPathPatterns.any((pattern) => pattern.hasMatch(path));
  }

  bool shouldOpenExternally(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme.isEmpty) {
      return false;
    }

    if (scheme == 'http' || scheme == 'https') {
      return !isInternal(uri);
    }

    return true;
  }

  bool shouldPresentAsModal(Uri uri) {
    if (!isAllowedInternal(uri)) {
      return false;
    }

    final path = _normalizedPath(uri);
    return _modalPathPatterns.any((pattern) => pattern.hasMatch(path));
  }

  bool isPullToRefreshEnabled(Uri uri) {
    return !isBlocked(uri);
  }

  NavDestination destinationFor(Uri uri) {
    final path = uri.path.toLowerCase();

    if (path == '/' || path.startsWith('/home')) {
      return NavDestination.home;
    }

    if (path.startsWith('/settings') || path.startsWith('/profile')) {
      return NavDestination.profile;
    }

    return NavDestination.events;
  }

  bool _isNurioHost(String host) {
    final normalizedHost = host.toLowerCase();
    final normalizedBaseHost = baseUri.host.toLowerCase();

    return normalizedHost == normalizedBaseHost ||
        normalizedHost == 'www.$normalizedBaseHost' ||
        normalizedHost.endsWith('.$normalizedBaseHost');
  }

  String _normalizedPath(Uri uri) {
    return uri.path.isEmpty ? '/' : uri.path;
  }
}
