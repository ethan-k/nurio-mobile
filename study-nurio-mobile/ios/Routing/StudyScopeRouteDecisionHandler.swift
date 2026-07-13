import Foundation
import HotwireNative
import UIKit

final class StudyScopeRouteDecisionHandler: RouteDecisionHandler {
    let name = "study-scope"

    func matches(location: URL, configuration: Navigator.Configuration) -> Bool {
        StudyScopePolicy.isBlocked(location)
    }

    func handle(location: URL, configuration: Navigator.Configuration, navigator: Navigator) -> Router.Decision {
        UIApplication.shared.open(location)
        return .cancel
    }
}
