import Foundation
import HotwireNative
import UIKit

final class TutorScopeRouteDecisionHandler: RouteDecisionHandler {
    let name = "tutor-scope"

    func matches(location: URL, configuration: Navigator.Configuration) -> Bool {
        TutorScopePolicy.isBlocked(location)
    }

    func handle(location: URL, configuration: Navigator.Configuration, navigator: Navigator) -> Router.Decision {
        UIApplication.shared.open(location)
        return .cancel
    }
}
