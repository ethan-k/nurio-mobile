import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Nurio'**
  String get appName;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get tabEvents;

  /// No description provided for @tabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// No description provided for @tooltipSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get tooltipSignedIn;

  /// No description provided for @tooltipSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get tooltipSignIn;

  /// No description provided for @homeGuestName.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get homeGuestName;

  /// No description provided for @homeWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String homeWelcome(Object name);

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Explore events, manage your tickets, and continue checkout.'**
  String get homeSubtitle;

  /// No description provided for @homeUpcomingEvents.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Events'**
  String get homeUpcomingEvents;

  /// No description provided for @homeSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get homeSeeAll;

  /// No description provided for @homeNoEventsLoaded.
  ///
  /// In en, this message translates to:
  /// **'No events loaded yet.'**
  String get homeNoEventsLoaded;

  /// No description provided for @homeActionBrowseEvents.
  ///
  /// In en, this message translates to:
  /// **'Browse Events'**
  String get homeActionBrowseEvents;

  /// No description provided for @homeActionPassPackages.
  ///
  /// In en, this message translates to:
  /// **'Pass Packages'**
  String get homeActionPassPackages;

  /// No description provided for @homeActionTickets.
  ///
  /// In en, this message translates to:
  /// **'Tickets'**
  String get homeActionTickets;

  /// No description provided for @homeActionPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get homeActionPayments;

  /// No description provided for @eventsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search events, location, host'**
  String get eventsSearchHint;

  /// No description provided for @eventsNoResults.
  ///
  /// In en, this message translates to:
  /// **'No events found.'**
  String get eventsNoResults;

  /// No description provided for @eventsReachedEnd.
  ///
  /// In en, this message translates to:
  /// **'You reached the end.'**
  String get eventsReachedEnd;

  /// No description provided for @eventsStatusFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get eventsStatusFull;

  /// No description provided for @eventsSpotsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} spots left'**
  String eventsSpotsLeft(int count);

  /// No description provided for @eventDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Event Details'**
  String get eventDetailTitle;

  /// No description provided for @eventDetailStatusFull.
  ///
  /// In en, this message translates to:
  /// **'This event is currently full'**
  String get eventDetailStatusFull;

  /// No description provided for @eventDetailSpotsRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} spots remaining'**
  String eventDetailSpotsRemaining(int count);

  /// No description provided for @eventDetailCheckoutButton.
  ///
  /// In en, this message translates to:
  /// **'Get Tickets / Continue to Payment'**
  String get eventDetailCheckoutButton;

  /// No description provided for @eventDetailPassPackagesButton.
  ///
  /// In en, this message translates to:
  /// **'View Pass Packages'**
  String get eventDetailPassPackagesButton;

  /// No description provided for @eventDetailNativeOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Checkout and payment run natively in Flutter. No WebView fallback is used in this app.'**
  String get eventDetailNativeOnlyNote;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile & Settings'**
  String get profileTitle;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @profileSignedOutDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign in to access tickets, wallet credits, and payment history.'**
  String get profileSignedOutDescription;

  /// No description provided for @profileAccountFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Nurio Member'**
  String get profileAccountFallbackName;

  /// No description provided for @settingEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get settingEditProfile;

  /// No description provided for @settingNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingNotifications;

  /// No description provided for @settingTickets.
  ///
  /// In en, this message translates to:
  /// **'Tickets'**
  String get settingTickets;

  /// No description provided for @settingPaymentHistory.
  ///
  /// In en, this message translates to:
  /// **'Payment History'**
  String get settingPaymentHistory;

  /// No description provided for @settingWalletCredits.
  ///
  /// In en, this message translates to:
  /// **'Wallet Credits'**
  String get settingWalletCredits;

  /// No description provided for @settingReferrals.
  ///
  /// In en, this message translates to:
  /// **'Referrals'**
  String get settingReferrals;

  /// No description provided for @settingEventHistory.
  ///
  /// In en, this message translates to:
  /// **'Event History'**
  String get settingEventHistory;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginTitle;

  /// No description provided for @loginDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign in to use tickets, payments, and profile features.'**
  String get loginDescription;

  /// No description provided for @loginEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginEmailLabel;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPasswordLabel;

  /// No description provided for @loginEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get loginEmailInvalid;

  /// No description provided for @loginPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get loginPasswordRequired;

  /// No description provided for @loginSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get loginSigningIn;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get loginFailed;

  /// No description provided for @loginNativeOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'This Flutter app is native-only and does not fall back to WebView.'**
  String get loginNativeOnlyNote;

  /// No description provided for @checkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkoutTitle;

  /// No description provided for @checkoutSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in is required before creating an order or paying.'**
  String get checkoutSignInRequired;

  /// No description provided for @checkoutFeatureLabel.
  ///
  /// In en, this message translates to:
  /// **'Checkout and Payment'**
  String get checkoutFeatureLabel;

  /// No description provided for @checkoutWalletButton.
  ///
  /// In en, this message translates to:
  /// **'Pay with Wallet Credits'**
  String get checkoutWalletButton;

  /// No description provided for @checkoutCardButton.
  ///
  /// In en, this message translates to:
  /// **'Pay with Card (PortOne)'**
  String get checkoutCardButton;

  /// No description provided for @checkoutBrowsePassPackagesButton.
  ///
  /// In en, this message translates to:
  /// **'Browse Pass Packages'**
  String get checkoutBrowsePassPackagesButton;

  /// No description provided for @checkoutPaymentMethodWallet.
  ///
  /// In en, this message translates to:
  /// **'wallet payment'**
  String get checkoutPaymentMethodWallet;

  /// No description provided for @checkoutPaymentMethodCard.
  ///
  /// In en, this message translates to:
  /// **'PortOne card payment'**
  String get checkoutPaymentMethodCard;

  /// No description provided for @checkoutBackendGap.
  ///
  /// In en, this message translates to:
  /// **'Cannot execute {paymentMethod} yet. Mobile checkout API endpoints must be added on the backend.'**
  String checkoutBackendGap(Object paymentMethod);

  /// No description provided for @passPackagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Pass Packages'**
  String get passPackagesTitle;

  /// No description provided for @passPackagesIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose the pass package that fits your event plans.'**
  String get passPackagesIntro;

  /// No description provided for @passPackagePurchaseFeatureLabel.
  ///
  /// In en, this message translates to:
  /// **'Pass Package Purchase'**
  String get passPackagePurchaseFeatureLabel;

  /// No description provided for @passPackagesPurchaseButton.
  ///
  /// In en, this message translates to:
  /// **'Purchase Pass Package'**
  String get passPackagesPurchaseButton;

  /// No description provided for @passPackagesApiNotExposed.
  ///
  /// In en, this message translates to:
  /// **'Pass purchase API is not exposed yet for mobile.'**
  String get passPackagesApiNotExposed;

  /// No description provided for @passPackageOneName.
  ///
  /// In en, this message translates to:
  /// **'1-Event Pass'**
  String get passPackageOneName;

  /// No description provided for @passPackageOneDescription.
  ///
  /// In en, this message translates to:
  /// **'Single event entry for flexible scheduling.'**
  String get passPackageOneDescription;

  /// No description provided for @passPackageOnePrice.
  ///
  /// In en, this message translates to:
  /// **'KRW 7,000'**
  String get passPackageOnePrice;

  /// No description provided for @passPackageThreeName.
  ///
  /// In en, this message translates to:
  /// **'3-Event Bundle'**
  String get passPackageThreeName;

  /// No description provided for @passPackageThreeDescription.
  ///
  /// In en, this message translates to:
  /// **'Lower per-event price for regular attendees.'**
  String get passPackageThreeDescription;

  /// No description provided for @passPackageThreePrice.
  ///
  /// In en, this message translates to:
  /// **'KRW 18,000'**
  String get passPackageThreePrice;

  /// No description provided for @passPackageFiveName.
  ///
  /// In en, this message translates to:
  /// **'5-Event Bundle'**
  String get passPackageFiveName;

  /// No description provided for @passPackageFiveDescription.
  ///
  /// In en, this message translates to:
  /// **'Best value bundle for frequent participation.'**
  String get passPackageFiveDescription;

  /// No description provided for @passPackageFivePrice.
  ///
  /// In en, this message translates to:
  /// **'KRW 28,000'**
  String get passPackageFivePrice;

  /// No description provided for @ticketsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tickets'**
  String get ticketsTitle;

  /// No description provided for @ticketsHeader.
  ///
  /// In en, this message translates to:
  /// **'My Tickets'**
  String get ticketsHeader;

  /// No description provided for @ticketsDescription.
  ///
  /// In en, this message translates to:
  /// **'Tickets are linked to completed orders and refunds. This native view is ready and awaits customer ticket APIs.'**
  String get ticketsDescription;

  /// No description provided for @ticketsFeatureLabel.
  ///
  /// In en, this message translates to:
  /// **'Tickets'**
  String get ticketsFeatureLabel;

  /// No description provided for @paymentHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment History'**
  String get paymentHistoryTitle;

  /// No description provided for @paymentsHeader.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get paymentsHeader;

  /// No description provided for @paymentsDescription.
  ///
  /// In en, this message translates to:
  /// **'Order and pass-package payments are presented in native screens once payment history endpoints are available.'**
  String get paymentsDescription;

  /// No description provided for @paymentHistoryFeatureLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment History'**
  String get paymentHistoryFeatureLabel;

  /// No description provided for @walletCreditsTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet Credits'**
  String get walletCreditsTitle;

  /// No description provided for @walletBalanceHeader.
  ///
  /// In en, this message translates to:
  /// **'Wallet Balance'**
  String get walletBalanceHeader;

  /// No description provided for @walletCreditsDescription.
  ///
  /// In en, this message translates to:
  /// **'Wallet balance, ledger, and credit expiry will be shown here via mobile API responses.'**
  String get walletCreditsDescription;

  /// No description provided for @walletCreditsFeatureLabel.
  ///
  /// In en, this message translates to:
  /// **'Wallet Credits'**
  String get walletCreditsFeatureLabel;

  /// No description provided for @editProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfileTitle;

  /// No description provided for @editProfileSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in is required to edit your profile.'**
  String get editProfileSignInRequired;

  /// No description provided for @editProfileSignInHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in required'**
  String get editProfileSignInHint;

  /// No description provided for @displayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayNameLabel;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @saveProfile.
  ///
  /// In en, this message translates to:
  /// **'Save Profile'**
  String get saveProfile;

  /// No description provided for @profileUpdateApiNotExposed.
  ///
  /// In en, this message translates to:
  /// **'Profile update API is not exposed yet for mobile.'**
  String get profileUpdateApiNotExposed;

  /// No description provided for @profileEditingFeatureLabel.
  ///
  /// In en, this message translates to:
  /// **'Profile Editing'**
  String get profileEditingFeatureLabel;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsEventRemindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Event reminders'**
  String get notificationsEventRemindersTitle;

  /// No description provided for @notificationsEventRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upcoming event reminders and check-in notices.'**
  String get notificationsEventRemindersSubtitle;

  /// No description provided for @notificationsPaymentUpdatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment updates'**
  String get notificationsPaymentUpdatesTitle;

  /// No description provided for @notificationsPaymentUpdatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Order/payment completion and refund updates.'**
  String get notificationsPaymentUpdatesSubtitle;

  /// No description provided for @notificationsMarketingTitle.
  ///
  /// In en, this message translates to:
  /// **'Marketing updates'**
  String get notificationsMarketingTitle;

  /// No description provided for @notificationsMarketingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Campaigns and pass-package promotions.'**
  String get notificationsMarketingSubtitle;

  /// No description provided for @savePreferences.
  ///
  /// In en, this message translates to:
  /// **'Save Preferences'**
  String get savePreferences;

  /// No description provided for @notificationsSyncApiNotExposed.
  ///
  /// In en, this message translates to:
  /// **'Notification preference sync API is not exposed yet.'**
  String get notificationsSyncApiNotExposed;

  /// No description provided for @notificationPreferencesFeatureLabel.
  ///
  /// In en, this message translates to:
  /// **'Notification Preferences'**
  String get notificationPreferencesFeatureLabel;

  /// No description provided for @referralsTitle.
  ///
  /// In en, this message translates to:
  /// **'Referrals'**
  String get referralsTitle;

  /// No description provided for @referralsHeader.
  ///
  /// In en, this message translates to:
  /// **'Referral Program'**
  String get referralsHeader;

  /// No description provided for @referralsDescription.
  ///
  /// In en, this message translates to:
  /// **'Share your referral code and track earned wallet credits from invited members.'**
  String get referralsDescription;

  /// No description provided for @referralsFeatureLabel.
  ///
  /// In en, this message translates to:
  /// **'Referrals'**
  String get referralsFeatureLabel;

  /// No description provided for @eventHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Event History'**
  String get eventHistoryTitle;

  /// No description provided for @eventHistoryHeader.
  ///
  /// In en, this message translates to:
  /// **'Attendance History'**
  String get eventHistoryHeader;

  /// No description provided for @eventHistoryDescription.
  ///
  /// In en, this message translates to:
  /// **'Past events, attendance records, and review links will appear here once mobile history APIs are available.'**
  String get eventHistoryDescription;

  /// No description provided for @eventHistoryFeatureLabel.
  ///
  /// In en, this message translates to:
  /// **'Event History'**
  String get eventHistoryFeatureLabel;

  /// No description provided for @apiGapNativeFeature.
  ///
  /// In en, this message translates to:
  /// **'Native {featureLabel}'**
  String apiGapNativeFeature(Object featureLabel);

  /// No description provided for @apiGapBody.
  ///
  /// In en, this message translates to:
  /// **'This screen is implemented natively and intentionally does not fall back to WebView. The backend still needs mobile JSON endpoints for full data and mutation support.'**
  String get apiGapBody;

  /// No description provided for @apiGapLegacyRoutesTitle.
  ///
  /// In en, this message translates to:
  /// **'Legacy web routes'**
  String get apiGapLegacyRoutesTitle;

  /// No description provided for @apiGapRequiredApiTitle.
  ///
  /// In en, this message translates to:
  /// **'Required mobile API endpoints'**
  String get apiGapRequiredApiTitle;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
