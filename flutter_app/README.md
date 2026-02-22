# Nurio Flutter App

Customer-facing mobile app for Nurio, implemented as a full Flutter app with native feature modules and web fallback for unsupported backend APIs.

## Scope

Included:
- Native customer shell, auth, events browsing, event details, and profile/settings hub
- Hybrid web fallback for orders, pass purchases, wallet flows, and PortOne completion redirects
- Profile/settings deep links for tickets, payment history, wallet credits, referrals, event history

Excluded:
- Admin routes/features
- Tutor/tutoring routes/features

## Core Files

- `lib/features/shell/presentation/app_shell_page.dart`: main native app shell
- `lib/features/events/`: native events models/repository/controller/pages
- `lib/features/auth/`: native API auth + login
- `lib/features/profile/`: native profile/settings hub
- `lib/features/home/`: native dashboard and quick actions
- `lib/features/web/presentation/web_flow_page.dart`: web fallback wrapper
- `lib/ui/nurio_shell_page.dart`: hardened in-app web flow (deep links, modals, redirects, payment app handling)
- `lib/navigation/customer_route_policy.dart`: route allow/block policy and legacy modal parity
- `lib/core/network/api_client.dart`: API transport
- `lib/core/storage/auth_token_storage.dart`: token persistence

## UI Framework

- Uses `getwidget` (`GFAppBar`, `GFButton`, `GFIconButton`) to simplify shared UI component management.

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
