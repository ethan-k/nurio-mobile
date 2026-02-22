# AGENTS.md

## Product Scope (Required)
- This repository includes a Flutter customer app at `flutter_app/`.
- Implement and maintain customer-facing features only.
- Do not build, expose, or migrate admin features (`/admin/*`).
- Do not build, expose, or migrate tutor features (`/tutoring*`, `/tutors*`, `tutors.<domain>`).

## Native-Only Rule (Required)
- Flutter implementation must be native-only.
- Do not add or reintroduce WebView fallback flows.
- Do not route customer features through in-app browser shells.

## Source of Truth
- Customer feature inventory is defined from `/Users/ws/es/business/nurioworkspace/nurio/config/routes.rb`.
- Payment behavior is defined by:
  - `/Users/ws/es/business/nurioworkspace/nurio/app/controllers/orders_controller.rb`
  - `/Users/ws/es/business/nurioworkspace/nurio/app/controllers/payments/portone_controller.rb`
  - `/Users/ws/es/business/nurioworkspace/nurio/app/javascript/controllers/portone_payment_controller.js`

## Architecture Rules
- Keep customer scope boundaries explicit in native navigation and API integration.
- Never add admin/tutor routes to Flutter feature navigation.
- When backend mobile APIs are missing, keep UX native and show explicit API-gap states.

## Validation Checklist
- `cd flutter_app && flutter analyze`
- `cd flutter_app && flutter test`
- `cd flutter_app && flutter build apk --debug`
- Verify event browse -> event detail -> native checkout page and payment actions remain native-only.
