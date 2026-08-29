import FirebaseCore
import FirebaseCrashlytics
import FirebaseMessaging
import HotwireNative
import KakaoSDKCommon
import OSLog
import UIKit
import UserNotifications

private let kakaoLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.nurio.ios",
    category: "kakao"
)

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        configureFirebase(application)
        configureAppearance()
        configureHotwire()
        configureKakaoSDK()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    private func configureAppearance() {
        UINavigationBar.appearance().scrollEdgeAppearance = .init()
        UINavigationBar.appearance().compactScrollEdgeAppearance = .init()
        UITabBar.appearance().scrollEdgeAppearance = .init()
    }

    private func configureFirebase(_ application: UIApplication) {
        FirebaseApp.configure()
#if DEBUG
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
#endif
        PaymentCrashTelemetry.configure(appSurface: "nurio")
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        UNUserNotificationCenter.current().requestAuthorization(options: [ .alert, .badge, .sound ]) { granted, error in
            if let error {
                NSLog("Nurio push authorization failed: \(error.localizedDescription)")
                return
            }

            NSLog("Nurio push authorization granted: \(granted)")
        }

        application.registerForRemoteNotifications()
    }

    private func configureHotwire() {
        Hotwire.loadPathConfiguration(from: [
            .file(Bundle.main.url(forResource: AppEnvironment.pathConfigurationResourceName, withExtension: "json")!)
        ])

        Hotwire.config.applicationUserAgentPrefix = "Nurio iOS; NurioPaymentReturn/1;"
        Hotwire.config.backButtonDisplayMode = .minimal
        Hotwire.config.showDoneButtonOnModals = true

        Hotwire.registerBridgeComponents([
            SignInWithOAuthComponent.self,
            RegisterDeviceTokenComponent.self,
            PaymentTelemetryComponent.self,
            KeyboardInsetsComponent.self,
        ])

        Hotwire.registerRouteDecisionHandlers([
            CustomerScopeRouteDecisionHandler(),
            OAuthRouteDecisionHandler(),
            AppNavigationRouteDecisionHandler(),
            SafariViewControllerRouteDecisionHandler(),
            SystemNavigationRouteDecisionHandler(),
        ])

        // Cold-boot checkout re-entry when the modal web view is stuck on an
        // external payment gateway. Ours runs first; the rest are the framework
        // defaults, preserved because registering replaces the whole chain.
        Hotwire.registerWebViewPolicyDecisionHandlers([
            CheckoutColdBootWebViewPolicyDecisionHandler(),
            ReloadWebViewPolicyDecisionHandler(),
            NewWindowWebViewPolicyDecisionHandler(),
            ExternalNavigationWebViewPolicyDecisionHandler(),
            LinkActivatedWebViewPolicyDecisionHandler(),
        ])

#if DEBUG
        Hotwire.config.debugLoggingEnabled = true
#endif
    }

    private func configureKakaoSDK() {
        guard let appKey = Bundle.main.object(forInfoDictionaryKey: "KAKAO_APP_KEY") as? String,
              !appKey.isEmpty else {
            kakaoLogger.error("Missing KAKAO_APP_KEY in Info.plist; skipping KakaoSDK initialization.")
            return
        }

        KakaoSDK.initSDK(appKey: appKey)
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken, !fcmToken.isEmpty else { return }

        NativePushTokenStore.shared.update(token: fcmToken)
        NSLog("Nurio FCM registration token received")
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([ .banner, .sound, .badge ])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            PushNotificationResponseRouter.shared.receive(response)
            completionHandler()
        }
    }
}

enum PushNotificationRoute {
    nonisolated static func destinationURL(
        from userInfo: [AnyHashable: Any],
        baseURL: URL
    ) -> URL? {
        for key in [ "path", "url" ] {
            guard let rawValue = userInfo[key] as? String else { continue }

            let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }

            if value.hasPrefix("/") && !value.hasPrefix("//") {
                guard let url = URL(string: value, relativeTo: baseURL)?.absoluteURL else { continue }

                return NativeAppOpenURL.webURL(from: url, baseURL: baseURL)
            }

            if let url = URL(string: value),
               let normalizedURL = NativeAppOpenURL.webURL(from: url, baseURL: baseURL) {
                return normalizedURL
            }
        }

        return nil
    }
}

@MainActor
final class PushNotificationResponseRouter {
    static let shared = PushNotificationResponseRouter()

    private var routeHandler: ((URL) -> Void)?
    private var queuedDestinations: [URL] = []
    private var consumedRequestIdentifiers = Set<String>()

    private init() {}

    func attach(routeHandler: @escaping (URL) -> Void) {
        self.routeHandler = routeHandler

        let destinations = queuedDestinations
        queuedDestinations.removeAll()
        destinations.forEach(routeHandler)
    }

    func detach() {
        routeHandler = nil
    }

    func receive(_ response: UNNotificationResponse) {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }

        let requestIdentifier = response.notification.request.identifier
        if !requestIdentifier.isEmpty {
            guard consumedRequestIdentifiers.insert(requestIdentifier).inserted else { return }
        }

        guard let destination = PushNotificationRoute.destinationURL(
            from: response.notification.request.content.userInfo,
            baseURL: AppEnvironment.baseURL
        ) else { return }

        if let routeHandler {
            routeHandler(destination)
        } else {
            queuedDestinations.append(destination)
        }
    }
}
