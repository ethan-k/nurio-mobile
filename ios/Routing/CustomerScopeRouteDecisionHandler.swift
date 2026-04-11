import Foundation
import HotwireNative
import UIKit

final class CustomerScopeRouteDecisionHandler: RouteDecisionHandler {
    let name = "customer-scope"

    func matches(location: URL, configuration: Navigator.Configuration) -> Bool {
        CustomerScopePolicy.isBlocked(location)
    }

    func handle(location: URL, configuration: Navigator.Configuration, navigator: Navigator) -> Router.Decision {
        UIApplication.shared.open(location)
        return .cancel
    }
}
