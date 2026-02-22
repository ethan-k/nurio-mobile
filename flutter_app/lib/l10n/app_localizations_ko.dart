// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appName => '누리오';

  @override
  String get tabHome => '홈';

  @override
  String get tabEvents => '이벤트';

  @override
  String get tabProfile => '프로필';

  @override
  String get tooltipSignedIn => '로그인됨';

  @override
  String get tooltipSignIn => '로그인';

  @override
  String get homeGuestName => '게스트';

  @override
  String homeWelcome(Object name) {
    return '$name님, 환영합니다';
  }

  @override
  String get homeSubtitle => '이벤트를 둘러보고, 티켓을 관리하고, 결제를 계속 진행하세요.';

  @override
  String get homeUpcomingEvents => '다가오는 이벤트';

  @override
  String get homeSeeAll => '전체 보기';

  @override
  String get homeNoEventsLoaded => '불러온 이벤트가 아직 없습니다.';

  @override
  String get homeActionBrowseEvents => '이벤트 둘러보기';

  @override
  String get homeActionPassPackages => '패스 패키지';

  @override
  String get homeActionTickets => '티켓';

  @override
  String get homeActionPayments => '결제';

  @override
  String get eventsSearchHint => '이벤트, 장소, 호스트 검색';

  @override
  String get eventsNoResults => '검색 결과가 없습니다.';

  @override
  String get eventsReachedEnd => '마지막 항목입니다.';

  @override
  String get eventsStatusFull => '마감';

  @override
  String eventsSpotsLeft(int count) {
    return '$count자리 남음';
  }

  @override
  String get eventDetailTitle => '이벤트 상세';

  @override
  String get eventDetailStatusFull => '현재 이 이벤트는 마감되었습니다';

  @override
  String eventDetailSpotsRemaining(int count) {
    return '$count자리 남음';
  }

  @override
  String get eventDetailCheckoutButton => '티켓 구매 / 결제 진행';

  @override
  String get eventDetailPassPackagesButton => '패스 패키지 보기';

  @override
  String get eventDetailNativeOnlyNote =>
      '결제와 체크아웃은 Flutter 네이티브 화면에서 동작합니다. 이 앱은 WebView 폴백을 사용하지 않습니다.';

  @override
  String get profileTitle => '프로필 및 설정';

  @override
  String get signIn => '로그인';

  @override
  String get signOut => '로그아웃';

  @override
  String get profileSignedOutDescription => '티켓, 지갑 크레딧, 결제 내역을 이용하려면 로그인하세요.';

  @override
  String get profileAccountFallbackName => '누리오 멤버';

  @override
  String get settingEditProfile => '프로필 수정';

  @override
  String get settingNotifications => '알림';

  @override
  String get settingTickets => '티켓';

  @override
  String get settingPaymentHistory => '결제 내역';

  @override
  String get settingWalletCredits => '지갑 크레딧';

  @override
  String get settingReferrals => '추천';

  @override
  String get settingEventHistory => '이벤트 이력';

  @override
  String get loginTitle => '로그인';

  @override
  String get loginDescription => '티켓, 결제, 프로필 기능을 사용하려면 로그인하세요.';

  @override
  String get loginEmailLabel => '이메일';

  @override
  String get loginPasswordLabel => '비밀번호';

  @override
  String get loginEmailInvalid => '올바른 이메일을 입력하세요';

  @override
  String get loginPasswordRequired => '비밀번호를 입력하세요';

  @override
  String get loginSigningIn => '로그인 중...';

  @override
  String get loginFailed => '로그인에 실패했습니다';

  @override
  String get loginNativeOnlyNote =>
      '이 Flutter 앱은 네이티브 전용이며 WebView 폴백을 사용하지 않습니다.';

  @override
  String get checkoutTitle => '체크아웃';

  @override
  String get checkoutSignInRequired => '주문 생성 및 결제를 진행하려면 로그인이 필요합니다.';

  @override
  String get checkoutFeatureLabel => '체크아웃 및 결제';

  @override
  String get checkoutWalletButton => '지갑 크레딧으로 결제';

  @override
  String get checkoutCardButton => '카드 결제 (PortOne)';

  @override
  String get checkoutBrowsePassPackagesButton => '패스 패키지 둘러보기';

  @override
  String get checkoutPaymentMethodWallet => '지갑 결제';

  @override
  String get checkoutPaymentMethodCard => 'PortOne 카드 결제';

  @override
  String checkoutBackendGap(Object paymentMethod) {
    return '현재 $paymentMethod을(를) 실행할 수 없습니다. 모바일 체크아웃 API 엔드포인트가 백엔드에 추가되어야 합니다.';
  }

  @override
  String get passPackagesTitle => '패스 패키지';

  @override
  String get passPackagesIntro => '이벤트 계획에 맞는 패스 패키지를 선택하세요.';

  @override
  String get passPackagePurchaseFeatureLabel => '패스 패키지 구매';

  @override
  String get passPackagesPurchaseButton => '패스 패키지 구매';

  @override
  String get passPackagesApiNotExposed => '패스 구매 API가 아직 모바일에 공개되지 않았습니다.';

  @override
  String get passPackageOneName => '1회 이벤트 패스';

  @override
  String get passPackageOneDescription => '유연한 일정에 맞춘 1회 이벤트 입장권입니다.';

  @override
  String get passPackageOnePrice => '7,000원';

  @override
  String get passPackageThreeName => '3회 번들';

  @override
  String get passPackageThreeDescription => '정기 참가자에게 유리한 회차당 가격입니다.';

  @override
  String get passPackageThreePrice => '18,000원';

  @override
  String get passPackageFiveName => '5회 번들';

  @override
  String get passPackageFiveDescription => '자주 참여하는 사용자에게 가장 좋은 혜택입니다.';

  @override
  String get passPackageFivePrice => '28,000원';

  @override
  String get ticketsTitle => '티켓';

  @override
  String get ticketsHeader => '내 티켓';

  @override
  String get ticketsDescription =>
      '티켓은 완료된 주문 및 환불 내역과 연결됩니다. 이 네이티브 화면은 준비되어 있으며 고객 티켓 API를 기다리고 있습니다.';

  @override
  String get ticketsFeatureLabel => '티켓';

  @override
  String get paymentHistoryTitle => '결제 내역';

  @override
  String get paymentsHeader => '결제';

  @override
  String get paymentsDescription =>
      '주문 및 패스 결제 내역은 결제 히스토리 API가 준비되면 네이티브 화면에서 제공됩니다.';

  @override
  String get paymentHistoryFeatureLabel => '결제 내역';

  @override
  String get walletCreditsTitle => '지갑 크레딧';

  @override
  String get walletBalanceHeader => '지갑 잔액';

  @override
  String get walletCreditsDescription =>
      '지갑 잔액, 원장, 만료 정보는 모바일 API 응답을 통해 이 화면에 표시됩니다.';

  @override
  String get walletCreditsFeatureLabel => '지갑 크레딧';

  @override
  String get editProfileTitle => '프로필 수정';

  @override
  String get editProfileSignInRequired => '프로필을 수정하려면 로그인이 필요합니다.';

  @override
  String get editProfileSignInHint => '로그인이 필요합니다';

  @override
  String get displayNameLabel => '표시 이름';

  @override
  String get emailLabel => '이메일';

  @override
  String get saveProfile => '프로필 저장';

  @override
  String get profileUpdateApiNotExposed => '프로필 수정 API가 아직 모바일에 공개되지 않았습니다.';

  @override
  String get profileEditingFeatureLabel => '프로필 수정';

  @override
  String get notificationsTitle => '알림';

  @override
  String get notificationsEventRemindersTitle => '이벤트 리마인더';

  @override
  String get notificationsEventRemindersSubtitle =>
      '다가오는 이벤트 알림 및 체크인 알림을 받습니다.';

  @override
  String get notificationsPaymentUpdatesTitle => '결제 업데이트';

  @override
  String get notificationsPaymentUpdatesSubtitle => '주문/결제 완료 및 환불 업데이트를 받습니다.';

  @override
  String get notificationsMarketingTitle => '마케팅 알림';

  @override
  String get notificationsMarketingSubtitle => '캠페인 및 패스 패키지 프로모션 알림을 받습니다.';

  @override
  String get savePreferences => '설정 저장';

  @override
  String get notificationsSyncApiNotExposed => '알림 설정 동기화 API가 아직 공개되지 않았습니다.';

  @override
  String get notificationPreferencesFeatureLabel => '알림 설정';

  @override
  String get referralsTitle => '추천';

  @override
  String get referralsHeader => '추천 프로그램';

  @override
  String get referralsDescription => '추천 코드를 공유하고 초대한 멤버로부터 적립된 지갑 크레딧을 확인하세요.';

  @override
  String get referralsFeatureLabel => '추천';

  @override
  String get eventHistoryTitle => '이벤트 이력';

  @override
  String get eventHistoryHeader => '참여 이력';

  @override
  String get eventHistoryDescription =>
      '이전 이벤트, 참여 기록, 리뷰 링크는 모바일 이력 API가 준비되면 여기에 표시됩니다.';

  @override
  String get eventHistoryFeatureLabel => '이벤트 이력';

  @override
  String apiGapNativeFeature(Object featureLabel) {
    return '네이티브 $featureLabel';
  }

  @override
  String get apiGapBody =>
      '이 화면은 네이티브로 구현되어 있으며 WebView 폴백을 사용하지 않습니다. 전체 데이터 조회 및 변경을 위해서는 백엔드 모바일 JSON API 엔드포인트가 추가로 필요합니다.';

  @override
  String get apiGapLegacyRoutesTitle => '기존 웹 라우트';

  @override
  String get apiGapRequiredApiTitle => '필요한 모바일 API 엔드포인트';

  @override
  String get retry => '다시 시도';
}
