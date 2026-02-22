// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Nurio';

  @override
  String get tabHome => 'Home';

  @override
  String get tabEvents => 'Events';

  @override
  String get tabProfile => 'Profile';

  @override
  String get tooltipSignedIn => 'Signed in';

  @override
  String get tooltipSignIn => 'Sign in';

  @override
  String get homeGuestName => 'Guest';

  @override
  String homeWelcome(Object name) {
    return 'Welcome, $name';
  }

  @override
  String get homeSubtitle =>
      'Explore events, manage your tickets, and continue checkout.';

  @override
  String get homeUpcomingEvents => 'Upcoming Events';

  @override
  String get homeSeeAll => 'See all';

  @override
  String get homeNoEventsLoaded => 'No events loaded yet.';

  @override
  String get homeActionBrowseEvents => 'Browse Events';

  @override
  String get homeActionPassPackages => 'Pass Packages';

  @override
  String get homeActionTickets => 'Tickets';

  @override
  String get homeActionPayments => 'Payments';

  @override
  String get eventsSearchHint => 'Search events, location, host';

  @override
  String get eventsNoResults => 'No events found.';

  @override
  String get eventsReachedEnd => 'You reached the end.';

  @override
  String get eventsStatusFull => 'Full';

  @override
  String eventsSpotsLeft(int count) {
    return '$count spots left';
  }

  @override
  String get eventDetailTitle => 'Event Details';

  @override
  String get eventDetailStatusFull => 'This event is currently full';

  @override
  String eventDetailSpotsRemaining(int count) {
    return '$count spots remaining';
  }

  @override
  String get eventDetailCheckoutButton => 'Get Tickets / Continue to Payment';

  @override
  String get eventDetailPassPackagesButton => 'View Pass Packages';

  @override
  String get eventDetailNativeOnlyNote =>
      'Checkout and payment run natively in Flutter. No WebView fallback is used in this app.';

  @override
  String get profileTitle => 'Profile & Settings';

  @override
  String get signIn => 'Sign In';

  @override
  String get signOut => 'Sign Out';

  @override
  String get profileSignedOutDescription =>
      'Sign in to access tickets, wallet credits, and payment history.';

  @override
  String get profileAccountFallbackName => 'Nurio Member';

  @override
  String get settingEditProfile => 'Edit Profile';

  @override
  String get settingNotifications => 'Notifications';

  @override
  String get settingTickets => 'Tickets';

  @override
  String get settingPaymentHistory => 'Payment History';

  @override
  String get settingWalletCredits => 'Wallet Credits';

  @override
  String get settingReferrals => 'Referrals';

  @override
  String get settingEventHistory => 'Event History';

  @override
  String get loginTitle => 'Sign In';

  @override
  String get loginDescription =>
      'Sign in to use tickets, payments, and profile features.';

  @override
  String get loginEmailLabel => 'Email';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginEmailInvalid => 'Enter a valid email';

  @override
  String get loginPasswordRequired => 'Enter your password';

  @override
  String get loginSigningIn => 'Signing in...';

  @override
  String get loginFailed => 'Login failed';

  @override
  String get loginNativeOnlyNote =>
      'This Flutter app is native-only and does not fall back to WebView.';

  @override
  String get checkoutTitle => 'Checkout';

  @override
  String get checkoutSignInRequired =>
      'Sign in is required before creating an order or paying.';

  @override
  String get checkoutFeatureLabel => 'Checkout and Payment';

  @override
  String get checkoutWalletButton => 'Pay with Wallet Credits';

  @override
  String get checkoutCardButton => 'Pay with Card (PortOne)';

  @override
  String get checkoutBrowsePassPackagesButton => 'Browse Pass Packages';

  @override
  String get checkoutPaymentMethodWallet => 'wallet payment';

  @override
  String get checkoutPaymentMethodCard => 'PortOne card payment';

  @override
  String checkoutBackendGap(Object paymentMethod) {
    return 'Cannot execute $paymentMethod yet. Mobile checkout API endpoints must be added on the backend.';
  }

  @override
  String get passPackagesTitle => 'Pass Packages';

  @override
  String get passPackagesIntro =>
      'Choose the pass package that fits your event plans.';

  @override
  String get passPackagePurchaseFeatureLabel => 'Pass Package Purchase';

  @override
  String get passPackagesPurchaseButton => 'Purchase Pass Package';

  @override
  String get passPackagesApiNotExposed =>
      'Pass purchase API is not exposed yet for mobile.';

  @override
  String get passPackageOneName => '1-Event Pass';

  @override
  String get passPackageOneDescription =>
      'Single event entry for flexible scheduling.';

  @override
  String get passPackageOnePrice => 'KRW 7,000';

  @override
  String get passPackageThreeName => '3-Event Bundle';

  @override
  String get passPackageThreeDescription =>
      'Lower per-event price for regular attendees.';

  @override
  String get passPackageThreePrice => 'KRW 18,000';

  @override
  String get passPackageFiveName => '5-Event Bundle';

  @override
  String get passPackageFiveDescription =>
      'Best value bundle for frequent participation.';

  @override
  String get passPackageFivePrice => 'KRW 28,000';

  @override
  String get ticketsTitle => 'Tickets';

  @override
  String get ticketsHeader => 'My Tickets';

  @override
  String get ticketsDescription =>
      'Tickets are linked to completed orders and refunds. This native view is ready and awaits customer ticket APIs.';

  @override
  String get ticketsFeatureLabel => 'Tickets';

  @override
  String get paymentHistoryTitle => 'Payment History';

  @override
  String get paymentsHeader => 'Payments';

  @override
  String get paymentsDescription =>
      'Order and pass-package payments are presented in native screens once payment history endpoints are available.';

  @override
  String get paymentHistoryFeatureLabel => 'Payment History';

  @override
  String get walletCreditsTitle => 'Wallet Credits';

  @override
  String get walletBalanceHeader => 'Wallet Balance';

  @override
  String get walletCreditsDescription =>
      'Wallet balance, ledger, and credit expiry will be shown here via mobile API responses.';

  @override
  String get walletCreditsFeatureLabel => 'Wallet Credits';

  @override
  String get editProfileTitle => 'Edit Profile';

  @override
  String get editProfileSignInRequired =>
      'Sign in is required to edit your profile.';

  @override
  String get editProfileSignInHint => 'Sign in required';

  @override
  String get displayNameLabel => 'Display Name';

  @override
  String get emailLabel => 'Email';

  @override
  String get saveProfile => 'Save Profile';

  @override
  String get profileUpdateApiNotExposed =>
      'Profile update API is not exposed yet for mobile.';

  @override
  String get profileEditingFeatureLabel => 'Profile Editing';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsEventRemindersTitle => 'Event reminders';

  @override
  String get notificationsEventRemindersSubtitle =>
      'Upcoming event reminders and check-in notices.';

  @override
  String get notificationsPaymentUpdatesTitle => 'Payment updates';

  @override
  String get notificationsPaymentUpdatesSubtitle =>
      'Order/payment completion and refund updates.';

  @override
  String get notificationsMarketingTitle => 'Marketing updates';

  @override
  String get notificationsMarketingSubtitle =>
      'Campaigns and pass-package promotions.';

  @override
  String get savePreferences => 'Save Preferences';

  @override
  String get notificationsSyncApiNotExposed =>
      'Notification preference sync API is not exposed yet.';

  @override
  String get notificationPreferencesFeatureLabel => 'Notification Preferences';

  @override
  String get referralsTitle => 'Referrals';

  @override
  String get referralsHeader => 'Referral Program';

  @override
  String get referralsDescription =>
      'Share your referral code and track earned wallet credits from invited members.';

  @override
  String get referralsFeatureLabel => 'Referrals';

  @override
  String get eventHistoryTitle => 'Event History';

  @override
  String get eventHistoryHeader => 'Attendance History';

  @override
  String get eventHistoryDescription =>
      'Past events, attendance records, and review links will appear here once mobile history APIs are available.';

  @override
  String get eventHistoryFeatureLabel => 'Event History';

  @override
  String apiGapNativeFeature(Object featureLabel) {
    return 'Native $featureLabel';
  }

  @override
  String get apiGapBody =>
      'This screen is implemented natively and intentionally does not fall back to WebView. The backend still needs mobile JSON endpoints for full data and mutation support.';

  @override
  String get apiGapLegacyRoutesTitle => 'Legacy web routes';

  @override
  String get apiGapRequiredApiTitle => 'Required mobile API endpoints';

  @override
  String get retry => 'Retry';
}
