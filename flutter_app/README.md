# Nurio Flutter App

Customer-facing Nurio mobile app implemented as a native Flutter application.

## Scope

Included:
- Native app shell, auth, events browsing, event detail, and profile/settings hub
- Native customer modules for checkout, pass packages, tickets, payments, wallet credits, referrals, and event history
- Customer-only coverage (admin and tutor scopes excluded)

Excluded:
- Admin routes/features
- Tutor/tutoring routes/features
- WebView fallback flows

## Native Architecture

Core entry points:
- `lib/features/shell/presentation/app_shell_page.dart`: main app shell and tab navigation
- `lib/features/events/`: native events models/repository/controller/pages
- `lib/features/auth/`: native API auth and login
- `lib/features/commerce/`: native checkout/payment/tickets/passes modules
- `lib/features/settings/`: native settings/profile/referrals/history modules
- `lib/features/shared/presentation/api_gap_card.dart`: native API-gap status component
- `lib/core/network/api_client.dart`: API transport
- `lib/core/storage/auth_token_storage.dart`: token persistence

## Backend Constraints

Current mobile JSON APIs in Nurio backend are available for auth and event browsing. Additional customer APIs (orders/payment/tickets/wallet/settings history) are still required for full data/mutation support in native screens.

## UI Framework

- Uses `getwidget` (`GFAppBar`, `GFButton`, `GFIconButton`) for shared UI components.

## Internationalization

- Flutter localization (`gen-l10n`) is enabled.
- Supported locales: English (`en`) and Korean (`ko`).
- Localization sources:
  - `lib/l10n/app_en.arb`
  - `lib/l10n/app_ko.arb`

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
flutter build apk --debug
```
