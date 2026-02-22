# Nurio Flutter App

Customer-facing mobile app for Nurio, implemented as a Flutter shell over existing web product routes.

## Scope

Included:
- Customer event discovery and attendance flows
- Orders, pass purchases, wallet flows, payment summary and PortOne completion redirects
- Profile/settings, tickets, payment history, wallet credits, referrals, event history

Excluded:
- Admin routes/features
- Tutor/tutoring routes/features

## Core Files

- `lib/ui/nurio_shell_page.dart`: primary WebView shell, deep links, external redirects, permissions, bottom navigation
- `lib/navigation/customer_route_policy.dart`: route allow/block policy
- `lib/config/app_config.dart`: base URL and app config

## Run

```bash
flutter pub get
flutter run
```

Base URL override:

```bash
flutter run --dart-define=NURIO_BASE_URL=https://nurio.kr
```

## Validation

```bash
flutter analyze
flutter test
```
