class AppConfig {
  AppConfig._({required this.baseUri, required this.appTitle});

  final Uri baseUri;
  final String appTitle;

  Uri get startUri => resolvePath('/events');
  Uri get homeUri => resolvePath('/home');
  Uri get eventsUri => resolvePath('/events');
  Uri get profileUri => resolvePath('/settings/profile/edit');

  static AppConfig fromEnvironment() {
    final baseUrl = const String.fromEnvironment(
      'NURIO_BASE_URL',
      defaultValue: 'https://nurio.kr',
    );

    final title = const String.fromEnvironment(
      'NURIO_APP_TITLE',
      defaultValue: 'Nurio',
    );

    return AppConfig._(baseUri: _normalizeBaseUri(baseUrl), appTitle: title);
  }

  Uri resolvePath(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return baseUri.resolve(normalizedPath);
  }

  Uri resolveUri(Uri uri) {
    if (uri.hasScheme && uri.host.isNotEmpty) {
      return uri;
    }

    return baseUri.resolveUri(uri);
  }

  static Uri _normalizeBaseUri(String rawValue) {
    final trimmed = rawValue.trim();
    final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final parsed = Uri.parse(withScheme);

    if (parsed.host.isEmpty) {
      throw ArgumentError(
        'NURIO_BASE_URL must include a host. Received: $rawValue',
      );
    }

    return Uri(
      scheme: parsed.scheme,
      userInfo: parsed.userInfo,
      host: parsed.host,
      port: parsed.hasPort ? parsed.port : null,
    );
  }
}
