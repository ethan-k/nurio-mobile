import Foundation
import HotwireNative
import UIKit

final class LeaderScopeRouteDecisionHandler: RouteDecisionHandler {
    let name = "leader-scope"

    func matches(location: URL, configuration: Navigator.Configuration) -> Bool {
        LeaderScopePolicy.isBlocked(location)
    }

    func handle(location: URL, configuration: Navigator.Configuration, navigator: Navigator) -> Router.Decision {
        UIApplication.shared.open(location)
        return .cancel
    }
}
