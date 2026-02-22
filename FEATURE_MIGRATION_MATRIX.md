# Customer Feature Migration Matrix (Rails -> Flutter)

## Investigation Sources
- `/Users/ws/es/business/nurioworkspace/nurio/config/routes.rb`
- `/Users/ws/es/business/nurioworkspace/nurio/app/controllers/orders_controller.rb`
- `/Users/ws/es/business/nurioworkspace/nurio/app/controllers/payments/portone_controller.rb`
- `/Users/ws/es/business/nurioworkspace/nurio/app/javascript/controllers/portone_payment_controller.js`

## Scope Decision
- Included: customer-facing product routes and flows.
- Excluded: admin namespace and tutoring/tutor product surfaces.

## Covered in Flutter (`flutter_app/`)
Coverage strategy: customer routes are supported through the in-app Flutter WebView shell, with explicit route guards blocking out-of-scope routes.

### Legacy Hotwire Navigation Parity
- Modal presentation behavior from `shared/path-configuration.json` is implemented in Flutter for:
  - auth/signup flows
  - onboarding wizard
  - order/pass purchase + payment summary routes
  - new/edit and review-creation routes
- Pull-to-refresh remains enabled for customer routes and disabled for blocked scopes.
- `window.open` and external payment app redirects are handled via popup interception and external app launch with `intent://` fallback URL support.

### Discovery and Core Navigation
- `GET /`
- `GET /home`
- `GET /events`, `GET /events/:id`, `GET /events/:id/ical`
- `GET /event_series`, `GET /event_series/:id`

### Auth and Onboarding
- `POST /google_one_tap/callback`
- Rodauth auth endpoints under `/auth/*`
- `GET /signup`
- `GET/PATCH /onboarding`
- `GET/PATCH/POST /onboardings/wizard`
- `GET /onboardings/completion`

### Event Participation
- `POST /events/:event_id/attendance/attend`
- `POST /events/:event_id/attendance/attend_with_pass`
- `DELETE /events/:event_id/attendance/cancel`
- `POST /events/:event_id/registrations`
- `POST /events/:event_id/attendance/check_in`
- `POST /events/:event_id/attendance/check_out`
- Participant summary and learning-note routes under `/events/:event_id/participant_summary` and `/events/:event_id/learning_note`

### Orders and Payments
- `GET /orders/new`, `POST /orders`, `GET /orders/:id`
- `GET /orders/:id/payment_summary`
- `POST /orders/:id/pay_with_wallet`
- `POST /orders/:id/reserve_wallet_for_split`
- `GET|POST /payments/portone/complete`
- Ticket confirmation: `GET /tickets/:id/confirmation`

### Passes and Wallet-Backed Flows
- `GET /pass_packages`
- `POST /pass_packages/:id/purchase`
- `GET /pass_packages/:id/payment_summary`
- `POST /pass_packages/:id/pay_with_wallet`
- `POST /pass_packages/:id/reserve_wallet_for_split`

### Social and Progress Features
- `POST/DELETE /saved_events`
- `GET/POST/DELETE /saved_locations`
- `GET /connections` (+ patch actions)
- `GET /learning_notes`
- `POST/GET /voice_checks`
- `GET/POST /ai_practice`

### Profile and Settings
- `GET /profile`, `PATCH /profile`
- `GET/PATCH /settings/profile`
- `GET /settings/notifications`
- `GET /settings/payment_methods`
- `GET /settings/payments`
- `GET /settings/tickets` (+ refund action)
- `GET /settings/wallet_credits`
- `GET /settings/referrals`
- `GET /settings/event_history`
- `GET/DELETE /settings/account`
- `GET /settings/passkeys`

### Notifications and Push
- `POST/DELETE/GET /push_subscriptions`
- `GET/PATCH /account_notifications`

### Public Policy/Info Pages
- `/study-sessions`, `/refund-policy`, `/terms-of-service`, `/privacy-policy`, `/faq`

## Explicitly Blocked in Flutter
- `/admin/*`
- `/tutoring*`, `/tutors*`, `tutors.<domain>`
- Tutoring API namespace routes under `/api/v1/tutors*`, `/api/v1/bookings*`, `/api/v1/slot_holds*`, `/api/v1/credits*`, `/api/v1/tutor*`

## Flutter Implementation Points
- Route guard: `flutter_app/lib/navigation/customer_route_policy.dart`
- Shell web container: `flutter_app/lib/ui/nurio_shell_page.dart`
- Platform permissions + app links:
  - `flutter_app/android/app/src/main/AndroidManifest.xml`
  - `flutter_app/ios/Runner/Info.plist`
