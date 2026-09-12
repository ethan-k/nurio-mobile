import Foundation
import HotwireNative
import UIKit

final class CustomerScopeRouteDecisionHandler: RouteDecisionHandler {
    let name = "customer-scope"

    func matches(proposal: VisitProposal, configuration: Navigator.Configuration) -> Bool {
        CustomerScopePolicy.isBlocked(proposal.url)
    }

    func handle(proposal: VisitProposal, configuration: Navigator.Configuration, navigator: any Navigating) -> Router.Decision {
        UIApplication.shared.open(proposal.url)
        return .cancel
    }
}
