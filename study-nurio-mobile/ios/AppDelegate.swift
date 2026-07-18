import FirebaseCore
import FirebaseMessaging
import GoogleSignIn
import HotwireNative
import KakaoSDKAuth
import KakaoSDKCommon
import UIKit
import UserNotifications

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        configureFirebase()
        configureAppearance()
        configureHotwire()
        configureKakaoSDK()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        guard FirebaseApp.app() != nil else { return }
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NSLog("Nurio Study remote notification registration failed")
    }

    func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        if KakaoSDKConfiguration.isKakaoTalkLoginURL(url) {
            return AuthController.handleOpenUrl(url: url)
        }

        return GIDSignIn.sharedInstance.handle(url)
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

    private func configureFirebase() {
        guard let options = FirebaseOptions.defaultOptions(),
              options.projectID == "nurio-prod",
              options.bundleID == Bundle.main.bundleIdentifier else {
            NSLog("Nurio Study Firebase configuration unavailable or mismatched")
            return
        }

        FirebaseApp.configure(options: options)
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
    }

    private func configureHotwire() {
        Hotwire.loadPathConfiguration(from: [
            .file(Bundle.main.url(forResource: AppEnvironment.pathConfigurationResourceName, withExtension: "json")!)
        ])

        Hotwire.config.applicationUserAgentPrefix = "Nurio Study iOS;"
        Hotwire.config.backButtonDisplayMode = .minimal
        Hotwire.config.showDoneButtonOnModals = true

        Hotwire.registerBridgeComponents([
            SignInWithOAuthComponent.self,
            RegisterDeviceTokenComponent.self,
        ])

        Hotwire.registerRouteDecisionHandlers([
            StudyScopeRouteDecisionHandler(),
            OAuthRouteDecisionHandler(),
            AppNavigationRouteDecisionHandler(),
            SafariViewControllerRouteDecisionHandler(),
            SystemNavigationRouteDecisionHandler(),
        ])

        Hotwire.config.debugLoggingEnabled = AppEnvironment.hotwireDebugLoggingEnabled
    }

    private func configureKakaoSDK() {
        guard let appKey = KakaoSDKConfiguration.appKey else { return }

        KakaoSDK.initSDK(appKey: appKey)
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        NativePushTokenStore.shared.update(token: fcmToken)
        NSLog("Nurio Study FCM token refreshed")
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
        let userInfo = response.notification.request.content.userInfo
        AppRouteCoordinator.shared.handleNotification(
            path: userInfo["path"] as? String,
            url: userInfo["url"] as? String
        )
        completionHandler()
    }
}
