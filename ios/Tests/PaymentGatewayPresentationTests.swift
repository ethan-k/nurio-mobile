import HotwireNative
import UIKit
import WebKit
import XCTest
@testable import Nurio

final class PaymentGatewayPresentationTests: XCTestCase {
    func testGatewayDetectionRejectsUnrelatedHostsAndMerchantCheckout() {
        for value in ["https://mobile.inicis.com/smart/payment", "https://ksmobile.inicis.com/payment"] {
            XCTAssertTrue(PaymentGatewayPresentation.isGatewayURL(URL(string: value)!))
        }
        for value in ["https://inicis.com.example.org/payment", "http://ksmobile.inicis.com/payment", "https://nurio.kr/orders/new", "nurio://", "https://example.com"] {
            XCTAssertFalse(PaymentGatewayPresentation.isGatewayURL(URL(string: value)!))
        }
    }

    func testCompletionDetectionRequiresExactMerchantOriginAndPath() {
        let base = URL(string: "https://nurio.kr")!
        XCTAssertTrue(PaymentGatewayPresentation.isCompletionURL(URL(string: "https://nurio.kr/payments/portone/complete?paymentId=test")!, baseURL: base))
        for value in ["https://example.com/payments/portone/complete", "https://nurio.kr:444/payments/portone/complete", "http://nurio.kr/payments/portone/complete", "https://nurio.kr/orders/new"] {
            XCTAssertFalse(PaymentGatewayPresentation.isCompletionURL(URL(string: value)!, baseURL: base))
        }
    }

    func testProviderNavigationKeepsProviderPagesInWebViewAndOpensPaymentApps() {
        let base = URL(string: "https://nurio.kr")!
        for value in ["https://m.pay.naver.com/o/payment", "https://nid.naver.com/nidlogin.login", "https://mobile.shinhancard.com/pay", "http://pg.example.com/step"] {
            XCTAssertEqual(PaymentGatewayPresentation.providerNavigation(for: URL(string: value)!, baseURL: base), .stayInWebView, value)
        }
        for value in ["shinhan-sr-ansimclick://pay?x=1", "supersol://pay", "naversearchthirdlogin://pay", "kakaotalk://kakaopay/pg", "ispmobile://TID=1"] {
            XCTAssertEqual(PaymentGatewayPresentation.providerNavigation(for: URL(string: value)!, baseURL: base), .openApp, value)
        }
        for value in ["https://nurio.kr/orders/1", "https://www.nurio.kr/orders/1", "nurio://payment-complete?paymentId=1", "nurio://", "about:blank", "about:srcdoc", "data:text/html,x", "blob:https://ksmobile.inicis.com/abc", "javascript:void(0)"] {
            XCTAssertNil(PaymentGatewayPresentation.providerNavigation(for: URL(string: value)!, baseURL: base), value)
        }
    }

    @MainActor
    func testPresentedGatewayKeepsProviderPagesAndOpensCardAppsFromAnyFrame() async throws {
        let originalFactory = Hotwire.config.makeCustomWebView
        defer { Hotwire.config.makeCustomWebView = originalFactory }
        var views: [GatewayRouteWebView] = []
        Hotwire.config.makeCustomWebView = { configuration in
            let view = GatewayRouteWebView(frame: .zero, configuration: configuration)
            views.append(view)
            return view
        }
        let delegate = SceneController()
        let configuration = Navigator.Configuration(name: "provider-hop-test", startLocation: AppEnvironment.baseURL)
        let navigator = Navigator(configuration: configuration, delegate: delegate)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = navigator.rootViewController
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        navigator.route(AppEnvironment.baseURL.appendingPathComponent("orders/123/payment_summary"))
        views[0].reportedURL = URL(string: "https://ksmobile.inicis.com/smart/payment")!
        let presentation = PaymentGatewayPresentation()
        var opened: [URL] = []
        presentation.openExternalURL = { opened.append($0) }
        let handler = PaymentGatewayWebViewPolicyDecisionHandler(presentation: presentation)
        let gatewayMain = GatewayFrameInfo(isMainFrame: true, webView: views[0])
        let gatewaySubframe = GatewayFrameInfo(isMainFrame: false, webView: views[0])
        let coveredMain = GatewayFrameInfo(isMainFrame: true, webView: views[1])
        let naverPayURL = URL(string: "https://m.pay.naver.com/o/payment")!
        let naverPay = GatewayProviderNavigationAction(url: naverPayURL, frame: gatewayMain, navigationType: .other)
        XCTAssertFalse(handler.matches(navigationAction: naverPay, configuration: configuration), "Outside a gateway, external pages keep Hotwire's default routing")

        presentation.presentGateway(navigator: navigator)
        try await Task.sleep(nanoseconds: 600_000_000)
        XCTAssertNotNil(presentation.gatewayController)

        XCTAssertTrue(handler.matches(navigationAction: naverPay, configuration: configuration))
        XCTAssertEqual(handler.handle(navigationAction: naverPay, configuration: configuration, navigator: navigator), .allow)
        let naverLogin = GatewayProviderNavigationAction(url: URL(string: "https://nid.naver.com/nidlogin.login")!, frame: gatewayMain, navigationType: .linkActivated)
        XCTAssertTrue(handler.matches(navigationAction: naverLogin, configuration: configuration))
        XCTAssertEqual(handler.handle(navigationAction: naverLogin, configuration: configuration, navigator: navigator), .allow)

        let superSol = URL(string: "shinhan-sr-ansimclick://pay?srCode=fixture")!
        let cardApp = GatewayProviderNavigationAction(url: superSol, frame: gatewaySubframe, navigationType: .other)
        XCTAssertTrue(handler.matches(navigationAction: cardApp, configuration: configuration))
        XCTAssertEqual(handler.handle(navigationAction: cardApp, configuration: configuration, navigator: navigator), .cancel)
        XCTAssertEqual(opened, [superSol])

        let coveredHop = GatewayProviderNavigationAction(url: naverPayURL, frame: coveredMain, navigationType: .other)
        XCTAssertFalse(handler.matches(navigationAction: coveredHop, configuration: configuration), "Web views behind the sheet keep Hotwire's default routing")
        let merchantPage = GatewayProviderNavigationAction(url: AppEnvironment.baseURL.appendingPathComponent("orders/123"), frame: gatewayMain, navigationType: .other)
        XCTAssertFalse(handler.matches(navigationAction: merchantPage, configuration: configuration), "Merchant pages keep the existing gateway return routing")

        let completion = URL(string: "/payments/portone/complete?paymentId=fixture", relativeTo: AppEnvironment.baseURL)!.absoluteURL
        let completionHop = GatewayProviderNavigationAction(url: completion, frame: gatewayMain, navigationType: .other)
        XCTAssertTrue(handler.matches(navigationAction: completionHop, configuration: configuration))
        XCTAssertEqual(handler.handle(navigationAction: completionHop, configuration: configuration, navigator: navigator), .cancel)
        for _ in 0..<40 where presentation.gatewayController != nil {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertNil(presentation.gatewayController, "The payment result still dismisses the sheet")
        XCTAssertEqual(opened, [superSol])
        withExtendedLifetime(delegate) {}
    }

    @MainActor
    func testNativePaymentReturnUsesExistingCheckoutRecoveryOnlyOnce() async {
        let originalFactory = Hotwire.config.makeCustomWebView
        defer { Hotwire.config.makeCustomWebView = originalFactory }
        var views: [GatewayRouteWebView] = []
        Hotwire.config.makeCustomWebView = { configuration in
            let view = GatewayRouteWebView(frame: .zero, configuration: configuration)
            views.append(view)
            return view
        }
        let delegate = SceneController()
        let navigator = Navigator(configuration: .init(name: "gateway-return-test", startLocation: AppEnvironment.baseURL), delegate: delegate)
        views[0].reportedURL = URL(string: "https://gateway.invalid/payment")!
        let destination = URL(string: "/payments/portone/complete?paymentId=fixture", relativeTo: AppEnvironment.baseURL)!.absoluteURL
        let loaded = expectation(description: "Merchant verification and its existing recovery")
        loaded.expectedFulfillmentCount = 2
        views[0].onLoad = { url in
            XCTAssertEqual(url, destination)
            loaded.fulfill()
        }
        let presentation = PaymentGatewayPresentation()
        presentation.routeAppReturn(destination, navigator: navigator)
        await fulfillment(of: [loaded], timeout: 5)
        XCTAssertEqual(views[0].requests, [destination, destination])
        XCTAssertTrue(views[1].requests.isEmpty)
        XCTAssertEqual(presentation.completionURLBeingRouted, destination)
        withExtendedLifetime(delegate) {}
    }

    @MainActor
    func testHotwireResultDismissesGatewayBeforeReplacingItsWebView() async throws {
        try await assertResultDismissesGateway(nativeCallback: false)
    }

    @MainActor
    func testPortOneWebViewCallbackDismissesGatewayAndLoadsServerVerification() async throws {
        try await assertResultDismissesGateway(nativeCallback: true)
    }

    @MainActor
    private func assertResultDismissesGateway(nativeCallback: Bool) async throws {
        let originalFactory = Hotwire.config.makeCustomWebView
        defer { Hotwire.config.makeCustomWebView = originalFactory }
        var views: [GatewayRouteWebView] = []
        Hotwire.config.makeCustomWebView = { configuration in
            let view = GatewayRouteWebView(frame: .zero, configuration: configuration)
            views.append(view)
            return view
        }
        let delegate = SceneController()
        let navigator = Navigator(configuration: .init(name: "sheet-result-test", startLocation: AppEnvironment.baseURL), delegate: delegate)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = navigator.rootViewController
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let checkout = AppEnvironment.baseURL.appendingPathComponent("orders/123/payment_summary")
        navigator.route(checkout)
        let source = try XCTUnwrap(navigator.session.activeVisitable as? VisitableViewController)
        views[0].reportedURL = URL(string: "https://gateway.invalid/payment")!
        let presentation = PaymentGatewayPresentation.shared
        presentation.presentGateway(navigator: navigator)
        try await Task.sleep(nanoseconds: 600_000_000)
        let sheet = try XCTUnwrap(presentation.gatewayController)
        XCTAssertTrue(source.visitableView.superview === sheet.view)

        // appScheme only resumes the pending gateway, it is not a payment result.
        AppRouteCoordinator.shared.handleIncoming(URL(string: "nurio://")!)
        XCTAssertTrue(presentation.gatewayController === sheet)
        let loaded = expectation(description: "Server result loads after sheet dismissal")
        let callback = URL(string: "nurio://payment-complete?paymentId=fixture")!
        let result = nativeCallback ? NativePaymentCallback.completeURL(from: callback, baseURL: AppEnvironment.baseURL)! : AppEnvironment.baseURL.appendingPathComponent("tickets/123/confirmation")
        loaded.expectedFulfillmentCount = 2
        views[0].onLoad = { url in
            guard url == result else { return }
            XCTAssertNil(presentation.gatewayController)
            XCTAssertNil(navigator.rootViewController.presentedViewController)
            loaded.fulfill()
        }
        // A Turbo/redirect proposal bypasses AppRouteCoordinator. Previously this
        // detached the source web view while leaving its now-empty sheet visible.
        let originalHandler = AppRouteCoordinator.shared.navigationHandler
        defer { AppRouteCoordinator.shared.navigationHandler = originalHandler }
        if nativeCallback {
            AppRouteCoordinator.shared.navigationHandler = navigator
            let action = GatewayCallbackNavigationAction(url: callback)
            let handler = PaymentGatewayWebViewPolicyDecisionHandler()
            XCTAssertTrue(handler.matches(navigationAction: action, configuration: .init(name: "sheet-result-test", startLocation: AppEnvironment.baseURL)))
            XCTAssertEqual(handler.handle(navigationAction: action, configuration: .init(name: "sheet-result-test", startLocation: AppEnvironment.baseURL), navigator: navigator), .cancel)
        } else {
            navigator.route(result)
        }
        await fulfillment(of: [loaded], timeout: 5)
        XCTAssertNil(presentation.gatewayController)
        XCTAssertEqual((navigator.rootViewController.topViewController as? VisitableViewController)?.initialVisitableURL, result)
        withExtendedLifetime(delegate) {}
    }

    @MainActor
    func testGatewayModalPreservesSubmittedDocumentAndRestoresCheckoutWithoutReload() async throws {
        let fixture = GatewayFixtureHandler()
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(fixture, forURLScheme: "gateway-fixture")
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 700), configuration: configuration)
        let loaded = expectation(description: "Gateway POST document loaded")
        let navigation = GatewayNavigationProbe { loaded.fulfill() }
        webView.navigationDelegate = navigation
        let source = HotwireWebViewController(url: AppEnvironment.baseURL.appendingPathComponent("orders/new"))
        source.loadViewIfNeeded()
        source.visitableView.activateWebView(webView, forVisitable: source)
        let delegate = GatewayVisitableDelegateProbe()
        source.visitableDelegate = delegate
        let originalWebUIDelegate = GatewayWebUIDelegateProbe()
        webView.uiDelegate = originalWebUIDelegate
        source.visitableView.allowsPullToRefresh = true
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let root = UINavigationController(rootViewController: source)
        window.rootViewController = root
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        var request = URLRequest(url: URL(string: "gateway-fixture://provider/payment")!)
        request.httpMethod = "POST"
        request.httpBody = Data("P_INIT_PAYMENT=fixture-state".utf8)
        webView.load(request)

        let modal = PaymentGatewayViewController(source: source)
        let sheet = UINavigationController(rootViewController: modal)
        sheet.modalPresentationStyle = .pageSheet
        sheet.isModalInPresentation = true
        modal.takeCheckoutView()
        modal.takeCheckoutView()
        await withCheckedContinuation { continuation in
            root.present(sheet, animated: false) { continuation.resume() }
        }
        await fulfillment(of: [loaded], timeout: 10)
        XCTAssertEqual(fixture.requests.count, 1)
        XCTAssertEqual(fixture.requests.first?.httpMethod, "POST")
        try await webView.evaluateJavaScript("window.paymentState = 'still-the-same-transaction'")
        window.layoutIfNeeded()
        XCTAssertFalse(webView.isHidden)
        XCTAssertGreaterThan(webView.bounds.height, 100)
        XCTAssertGreaterThan(webView.bounds.width, 100)
        XCTAssertTrue(webView.window === window)
        XCTAssertTrue(root.presentedViewController === sheet)
        XCTAssertTrue(source.visitableView.superview === modal.view)
        XCTAssertTrue(source.visitableView.webView === webView)
        XCTAssertTrue(webView.uiDelegate === modal)
        XCTAssertTrue(modal.responds(to: #selector(WKUIDelegate.webViewDidClose(_:))))
        webView.uiDelegate?.webViewDidClose?(webView)
        XCTAssertEqual(originalWebUIDelegate.closeCount, 1)
        XCTAssertFalse(source.visitableView.allowsPullToRefresh)
        source.beginAppearanceTransition(false, animated: false)
        source.endAppearanceTransition()
        XCTAssertEqual(delegate.disappearances, 0)
        let presentedState = try await webView.evaluateJavaScript("window.paymentState") as? String
        XCTAssertEqual(presentedState, "still-the-same-transaction")

        await withCheckedContinuation { continuation in
            sheet.dismiss(animated: false) { continuation.resume() }
        }
        modal.restoreCheckoutView()
        modal.restoreCheckoutView()
        XCTAssertTrue(source.visitableView.superview === source.view)
        XCTAssertTrue(source.visitableView.webView === webView)
        XCTAssertTrue(source.visitableDelegate === delegate)
        XCTAssertTrue(webView.uiDelegate === originalWebUIDelegate)
        XCTAssertTrue(source.visitableView.allowsPullToRefresh)
        let restoredState = try await webView.evaluateJavaScript("window.paymentState") as? String
        XCTAssertEqual(restoredState, "still-the-same-transaction")
        XCTAssertEqual(fixture.requests.count, 1, "Presenting/dismissing must not replay the provider POST")
        XCTAssertEqual(navigation.finishedCount, 1, "The gateway document must never reload during presentation")
    }
}

private final class GatewayFixtureHandler: NSObject, WKURLSchemeHandler {
    var requests: [URLRequest] = []
    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        requests.append(urlSchemeTask.request)
        let html = Data("<html><body>Gateway fixture</body></html>".utf8)
        urlSchemeTask.didReceive(URLResponse(url: urlSchemeTask.request.url!, mimeType: "text/html", expectedContentLength: html.count, textEncodingName: "utf-8"))
        urlSchemeTask.didReceive(html)
        urlSchemeTask.didFinish()
    }
    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}
}

private final class GatewayNavigationProbe: NSObject, WKNavigationDelegate {
    let onFinish: () -> Void
    var finishedCount = 0
    init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finishedCount += 1
        onFinish()
    }
}

private final class GatewayVisitableDelegateProbe: VisitableDelegate {
    var disappearances = 0
    func visitableViewWillAppear(_ visitable: any Visitable) {}
    func visitableViewDidAppear(_ visitable: any Visitable) {}
    func visitableViewWillDisappear(_ visitable: any Visitable) { disappearances += 1 }
    func visitableViewDidDisappear(_ visitable: any Visitable) { disappearances += 1 }
    func visitableDidRequestReload(_ visitable: any Visitable) {}
    func visitableDidRequestRefresh(_ visitable: any Visitable) {}
}

private final class GatewayWebUIDelegateProbe: NSObject, WKUIDelegate {
    var closeCount = 0
    func webViewDidClose(_ webView: WKWebView) { closeCount += 1 }
}

private final class GatewayRouteWebView: WKWebView {
    var reportedURL: URL?
    var requests: [URL] = []
    var onLoad: ((URL) -> Void)?
    override var url: URL? { reportedURL }
    override func load(_ request: URLRequest) -> WKNavigation? {
        if let url = request.url { requests.append(url); onLoad?(url) }
        return nil
    }
}

private final class GatewayCallbackNavigationAction: WKNavigationAction {
    private let callbackRequest: URLRequest
    init(url: URL) { callbackRequest = URLRequest(url: url); super.init() }
    override var request: URLRequest { callbackRequest }
}

private final class GatewayProviderNavigationAction: WKNavigationAction {
    private let providerRequest: URLRequest
    private let frame: GatewayFrameInfo
    private let type: WKNavigationType
    init(url: URL, frame: GatewayFrameInfo, navigationType: WKNavigationType) {
        providerRequest = URLRequest(url: url)
        self.frame = frame
        type = navigationType
        super.init()
    }
    override var request: URLRequest { providerRequest }
    override var targetFrame: WKFrameInfo? { frame }
    override var sourceFrame: WKFrameInfo { frame }
    override var navigationType: WKNavigationType { type }
}

private final class GatewayFrameInfo: WKFrameInfo {
    private let isMainFrameValue: Bool
    private weak var owningWebView: WKWebView?
    init(isMainFrame: Bool, webView: WKWebView) {
        isMainFrameValue = isMainFrame
        owningWebView = webView
        super.init()
        // WebKit crashes deallocating a WKFrameInfo it did not create.
        _ = Unmanaged.passRetained(self)
    }
    override var isMainFrame: Bool { isMainFrameValue }
    override var webView: WKWebView? { owningWebView }
}
