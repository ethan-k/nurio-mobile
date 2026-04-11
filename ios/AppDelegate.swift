import HotwireNative
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        configureAppearance()
        configureHotwire()
        return true
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

    private func configureHotwire() {
        Hotwire.loadPathConfiguration(from: [
            .file(Bundle.main.url(forResource: AppEnvironment.pathConfigurationResourceName, withExtension: "json")!)
        ])

        Hotwire.config.applicationUserAgentPrefix = "Nurio iOS;"
        Hotwire.config.backButtonDisplayMode = .minimal
        Hotwire.config.showDoneButtonOnModals = true

        Hotwire.registerBridgeComponents([
            SignInWithOAuthComponent.self,
        ])

        Hotwire.registerRouteDecisionHandlers([
            CustomerScopeRouteDecisionHandler(),
            OAuthRouteDecisionHandler(),
            AppNavigationRouteDecisionHandler(),
            SafariViewControllerRouteDecisionHandler(),
            SystemNavigationRouteDecisionHandler(),
        ])

#if DEBUG
        Hotwire.config.debugLoggingEnabled = true
#endif
    }
}
