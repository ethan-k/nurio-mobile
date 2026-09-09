import HotwireNative
import UIKit
import WebKit
import XCTest
@testable import Nurio

final class NativeImageCacheTests: XCTestCase {
    private var directory: URL!
    private var fixture: NativeImage!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12), format: format)
        let data = renderer.pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
        }
        fixture = NativeImage(data: data, mimeType: "image/png")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        ImageURLProtocol.handler = nil
    }

    func testSchemeRestoresHTTPSAndPreservesTransformationAndEncodedQuery() {
        let source = NativeImageURL.sourceURL(from: URL(string: "nurio-image://cdn.example.com/variants/a%2Fb/image.png?width=640&sig=a%2Bb%3D")!)
        XCTAssertEqual(source?.absoluteString, "https://cdn.example.com/variants/a%2Fb/image.png?width=640&sig=a%2Bb%3D")
        XCTAssertNil(NativeImageURL.sourceURL(from: URL(string: "https://cdn.example.com/image.png")!))
        XCTAssertTrue(NativeImageURL.isAllowed(URL(string: "https://8.8.8.8/image.png")!))
    }

    func testRejectsUnsafeSourcesAndRedirectDestinations() {
        for value in [
            "http://nurio.kr/a.png", "https://localhost/a.png", "https://localhost./a.png",
            "https://foo.local/a.png", "https://foo.localhost/a.png", "https://internal/a.png",
            "https://127.0.0.1/a.png", "https://10.0.0.1/a.png", "https://172.16.0.1/a.png",
            "https://192.168.1.1/a.png", "https://169.254.1.1/a.png", "https://100.64.0.1/a.png",
            "https://[::1]/a.png", "https://[::ffff:127.0.0.1]/a.png", "https://[fc00::1]/a.png",
            "https://2130706433/a.png", "https://0x7f000001/a.png", "https://0177.0.0.1/a.png",
            "https://user:password@nurio.kr/a.png", "https://nurio.kr:8443/a.png"
        ] {
            XCTAssertFalse(NativeImageURL.isAllowed(URL(string: value)!), value)
        }
    }

    func testCacheSurvivesRecreationAndHitNeedsNoNetwork() async throws {
        let downloader = FakeImageDownloader(result: .success(fixture))
        let url = imageURL("a")
        let first = NativeImageCache(directory: directory, downloader: downloader)
        let initial = try await load(first, url)
        XCTAssertEqual(initial, fixture)
        let unavailable = FakeImageDownloader(result: .failure(URLError(.notConnectedToInternet)))
        let restarted = NativeImageCache(directory: directory, downloader: unavailable)
        let cached = try await load(restarted, url)
        XCTAssertEqual(cached, fixture)
        XCTAssertEqual(downloader.requestedURLs, [url])
        XCTAssertTrue(unavailable.requestedURLs.isEmpty)
        XCTAssertEqual(try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
    }

    func testChangedImageVersionAndTransformationUseSeparateFiles() async throws {
        let downloader = FakeImageDownloader(result: .success(fixture))
        let cache = NativeImageCache(directory: directory, downloader: downloader)
        for suffix in ["a?width=640&v=1", "a?width=640&v=2", "a?width=1280&v=2"] {
            _ = try await load(cache, imageURL(suffix))
        }
        XCTAssertEqual(downloader.requestedURLs.count, 3)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 3)
    }

    func testFailedAndUndecodableDownloadsAreNotSavedAndCanRetry() async throws {
        let downloader = FakeImageDownloader(result: .failure(URLError(.timedOut)))
        let cache = NativeImageCache(directory: directory, downloader: downloader)
        await expectFailure(cache, imageURL("a"))
        downloader.result = .success(NativeImage(data: Data("<html>oops</html>".utf8), mimeType: "image/png"))
        await expectFailure(cache, imageURL("a"))
        downloader.result = .success(fixture)
        let recovered = try await load(cache, imageURL("a"))
        XCTAssertEqual(recovered, fixture)
        XCTAssertEqual(downloader.requestedURLs.count, 3)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 1)
    }

    func testCorruptDiskEntryIsEvictedAndDownloadedAgain() async throws {
        let downloader = FakeImageDownloader(result: .success(fixture))
        let cache = NativeImageCache(directory: directory, downloader: downloader)
        _ = try await load(cache, imageURL("a"))
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        try Data("partial file".utf8).write(to: XCTUnwrap(files.first))
        let recovered = try await load(cache, imageURL("a"))
        XCTAssertEqual(recovered, fixture)
        XCTAssertEqual(downloader.requestedURLs.count, 2)
    }

    func testConcurrentConsumersShareOneDownload() async throws {
        let downloader = FakeImageDownloader(result: .success(fixture), delay: 0.05)
        let cache = NativeImageCache(directory: directory, downloader: downloader)
        async let first = load(cache, imageURL("a"))
        async let second = load(cache, imageURL("a"))
        let images = try await [first, second]
        XCTAssertEqual(images, [fixture, fixture])
        XCTAssertEqual(downloader.requestedURLs.count, 1)
    }

    func testDownloadConcurrencyIsBounded() async throws {
        let downloader = FakeImageDownloader(result: .success(fixture), delay: 0.05)
        let cache = NativeImageCache(directory: directory, downloader: downloader, concurrentDownloads: 2)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<10 {
                let url = imageURL("\(index)")
                group.addTask { _ = try await self.load(cache, url) }
            }
            try await group.waitForAll()
        }
        XCTAssertEqual(downloader.maximumActive, 2)
    }

    func testLRUEvictsOldImageAndKeepsRecentlyReadImage() async throws {
        let downloader = FakeImageDownloader(result: .success(fixture))
        let initial = NativeImageCache(directory: directory, downloader: downloader)
        _ = try await load(initial, imageURL("a"))
        let aFile = directory.appendingPathComponent(NativeImageCache.digest(Data(imageURL("a").absoluteString.utf8)))
        let size = try XCTUnwrap(try FileManager.default.attributesOfItem(atPath: aFile.path)[.size] as? Int)
        let cache = NativeImageCache(directory: directory, byteLimit: size * 2 + 10, downloader: downloader)
        _ = try await load(cache, imageURL("b"))
        let bFile = directory.appendingPathComponent(NativeImageCache.digest(Data(imageURL("b").absoluteString.utf8)))
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1)], ofItemAtPath: bFile.path)
        _ = try await load(cache, imageURL("a"))
        _ = try await load(cache, imageURL("c"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: aFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: bFile.path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 2)
    }

    func testValidationRejectsTruncatedRasterNonimageAndOversizeData() throws {
        XCTAssertTrue(NativeImageCache.isValid(fixture))
        XCTAssertFalse(NativeImageCache.isValid(NativeImage(data: fixture.data.prefix(30), mimeType: "image/png")))
        XCTAssertFalse(NativeImageCache.isValid(NativeImage(data: fixture.data, mimeType: "text/html")))
        XCTAssertFalse(NativeImageCache.isValid(NativeImage(data: Data(repeating: 0, count: NativeImageCache.maximumImageBytes + 1), mimeType: "image/png")))
        let jpeg = try XCTUnwrap(UIImage(data: fixture.data)?.jpegData(compressionQuality: 0.8))
        XCTAssertTrue(NativeImageCache.isValid(NativeImage(data: jpeg, mimeType: "image/jpeg")))
        XCTAssertFalse(NativeImageCache.isValid(NativeImage(data: jpeg.prefix(jpeg.count / 2), mimeType: "image/jpeg")))
        XCTAssertFalse(NativeImageCache.isValid(NativeImage(data: jpeg.dropLast(2), mimeType: "image/jpeg")))
        XCTAssertFalse(NativeImageCache.isValid(NativeImage(data: fixture.data.dropLast(12), mimeType: "image/png")))
    }

    func testStaticSVGIsCompleteAndHasNoActiveOrExternalContent() {
        func valid(_ text: String) -> Bool {
            NativeImageCache.isValid(NativeImage(data: Data(text.utf8), mimeType: "image/svg+xml"))
        }
        XCTAssertTrue(valid("<svg xmlns='http://www.w3.org/2000/svg' width='10' height='10'><path d='M0 0h10v10H0z'/></svg>"))
        XCTAssertFalse(valid("<svg><path"))
        XCTAssertFalse(valid("<html/>"))
        XCTAssertFalse(valid("<!DOCTYPE svg [<!ENTITY x SYSTEM 'https://example.com'>]><svg>&x;</svg>"))
        XCTAssertFalse(valid("<svg><script>alert(1)</script></svg>"))
        XCTAssertFalse(valid("<svg><use href='https://example.com/a.svg'/></svg>"))
    }

    func testSVGAllowsLocalPaintReferencesButRejectsExternalAndIncompleteReferences() {
        func valid(_ style: String) -> Bool {
            let svg = "<svg xmlns='http://www.w3.org/2000/svg'><style>path { fill: \(style); }</style></svg>"
            return NativeImageCache.isValid(NativeImage(data: Data(svg.utf8), mimeType: "image/svg+xml"))
        }
        for reference in ["url(#gradient)", "url(  #mask-1  )", "url( '#clip' )", ##"url( "#gradient" )"##, "URL( #mask )"] {
            XCTAssertTrue(valid(reference), reference)
        }
        for reference in ["url(https://example.com/image.svg)", "url( '//example.com/image.svg' )",
                          "url(#mask", "url('#mask\")", "url(#mask) url(https://example.com)",
                          "u&#114;l(https://example.com)", "@import 'https://example.com/style.css'"] {
            XCTAssertFalse(valid(reference), reference)
        }
        let processingInstruction = "<?xml-stylesheet href='https://example.com/style.css'?><svg/>"
        XCTAssertFalse(NativeImageCache.isValid(NativeImage(data: Data(processingInstruction.utf8), mimeType: "image/svg+xml")))
    }

    func testDownloaderRejectsHTTPFailurePartialAndNonImageResponses() async {
        for (status, mime) in [(500, "image/png"), (206, "image/png"), (200, "text/html")] {
            ImageURLProtocol.handler = { _ in (status, ["Content-Type": mime], self.fixture.data) }
            do {
                _ = try await download()
                XCTFail("Unexpected success for \(status), \(mime)")
            } catch {}
        }
    }

    func testRedirectRequestsStripHeadersAndStopAfterFiveHops() {
        let initial = imageURL("initial")
        let redirect = HTTPURLResponse(url: initial, statusCode: 302, httpVersion: nil, headerFields: nil)!
        let task = URLSession.shared.dataTask(with: initial)
        var failures = 0
        let download = NativeImageDownload(url: initial, configuration: .ephemeral) { result in
            if case .failure = result { failures += 1 }
        }
        var destination = URLRequest(url: URL(string: "https://cdn.example.com/image.png?sig=abc")!)
        destination.setValue("session=private", forHTTPHeaderField: "Cookie")
        destination.setValue("Bearer private", forHTTPHeaderField: "Authorization")
        for _ in 0..<5 {
            download.urlSession(.shared, task: task, willPerformHTTPRedirection: redirect, newRequest: destination) { request in
                XCTAssertEqual(request?.url, destination.url)
                XCTAssertNil(request?.value(forHTTPHeaderField: "Cookie"))
                XCTAssertNil(request?.value(forHTTPHeaderField: "Authorization"))
                XCTAssertEqual(request?.httpShouldHandleCookies, false)
            }
        }
        download.urlSession(.shared, task: task, willPerformHTTPRedirection: redirect, newRequest: destination) { request in
            XCTAssertNil(request)
        }
        XCTAssertEqual(failures, 1)
        task.cancel()
    }

    func testDownloaderUsesNoCookiesCredentialsOrURLCache() async throws {
        ImageURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertFalse(request.httpShouldHandleCookies)
            XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            return (200, ["Content-Type": "image/png"], self.fixture.data)
        }
        let response = try await download()
        XCTAssertEqual(response, fixture)
    }

    func testDownloaderRejectsOversizedDeclaredAndStreamingResponses() async {
        ImageURLProtocol.handler = { _ in
            (200, ["Content-Type": "image/png", "Content-Length": "\(NativeImageCache.maximumImageBytes + 1)"], Data())
        }
        do { _ = try await download(); XCTFail("Oversized response accepted") } catch {}
        ImageURLProtocol.handler = { _ in
            (200, ["Content-Type": "image/png"], Data(repeating: 0, count: NativeImageCache.maximumImageBytes + 1))
        }
        do { _ = try await download(); XCTFail("Oversized stream accepted") } catch {}
    }

    @MainActor
    func testStoppedSchemeTaskReceivesNoCallbacksWhileOtherConsumerCompletes() async {
        let downloader = FakeImageDownloader(result: .success(fixture), delay: 0.05)
        let cache = NativeImageCache(directory: directory, downloader: downloader)
        let handler = NativeImageSchemeHandler(cache: cache)
        let webView = WKWebView()
        let completed = expectation(description: "active consumer completed")
        let stopped = FakeImageSchemeTask { XCTFail("Stopped task received a callback") }
        let active = FakeImageSchemeTask {}
        active.onFinish = { completed.fulfill() }
        handler.webView(webView, start: stopped)
        handler.webView(webView, start: active)
        handler.webView(webView, stop: stopped)
        await fulfillment(of: [completed], timeout: 3)
        XCTAssertEqual(active.imageData, fixture.data)
        XCTAssertEqual(downloader.requestedURLs.count, 1)
    }

    @MainActor
    func testRealWebViewDecodesImageThenRecreatedWebViewLoadsOfflineFromDisk() async {
        await assertWebViewDiskReuse(fixture)
    }

    @MainActor
    func testRealWebViewDecodesStaticSVGAndReusesItOffline() async {
        let svg = """
            <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12">
              <defs><linearGradient id="paint"><stop stop-color="red"/><stop offset="1" stop-color="blue"/></linearGradient></defs>
              <path fill="url( '#paint' )" d="M0 0h12v12H0z"/>
            </svg>
            """
        await assertWebViewDiskReuse(NativeImage(data: Data(svg.utf8), mimeType: "image/svg+xml"))
    }

    @MainActor
    private func assertWebViewDiskReuse(_ image: NativeImage) async {
        let firstDownloader = FakeImageDownloader(result: .success(image))
        let offlineDownloader = FakeImageDownloader(result: .failure(URLError(.notConnectedToInternet)))
        for (index, downloader) in [firstDownloader, offlineDownloader].enumerated() {
            let cache = NativeImageCache(directory: directory, downloader: downloader)
            let configuration = WKWebViewConfiguration()
            configuration.setURLSchemeHandler(NativeImageSchemeHandler(cache: cache), forURLScheme: NativeImageURL.scheme)
            let loaded = expectation(description: "WebView \(index) decoded image")
            let probe = ImageLoadProbe { message in
                XCTAssertEqual(message, "loaded:12:12")
                loaded.fulfill()
            }
            configuration.userContentController.add(probe, name: "imageCacheTest")
            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 100, height: 100), configuration: configuration)
            webView.loadHTMLString("""
                <img src="nurio-image://nurio.kr/images/webview.png"
                onload="window.webkit.messageHandlers.imageCacheTest.postMessage('loaded:'+this.naturalWidth+':'+this.naturalHeight)"
                onerror="window.webkit.messageHandlers.imageCacheTest.postMessage('failed')">
                """, baseURL: URL(string: "https://nurio.kr/events/1"))
            await fulfillment(of: [loaded], timeout: 10)
            configuration.userContentController.removeScriptMessageHandler(forName: "imageCacheTest")
            webView.stopLoading()
        }
        XCTAssertEqual(firstDownloader.requestedURLs.count, 1)
        XCTAssertTrue(offlineDownloader.requestedURLs.isEmpty)
    }

    @MainActor
    func testHotwireFactoryRegistersHandlerForEachWebViewAndAdvertisesCapability() {
        let main = Hotwire.config.makeWebView()
        let modal = Hotwire.config.makeWebView()
        XCTAssertNotNil(main.configuration.urlSchemeHandler(forURLScheme: NativeImageURL.scheme))
        XCTAssertNotNil(modal.configuration.urlSchemeHandler(forURLScheme: NativeImageURL.scheme))
        XCTAssertTrue(main.configuration.applicationNameForUserAgent?.contains("NurioImageCache/1") == true)
    }

    private func imageURL(_ suffix: String) -> URL { URL(string: "https://nurio.kr/images/\(suffix)")! }

    private func load(_ cache: NativeImageCache, _ url: URL) async throws -> NativeImage {
        try await withCheckedThrowingContinuation { continuation in
            cache.load(url) { continuation.resume(with: $0) }
        }
    }

    private func expectFailure(_ cache: NativeImageCache, _ url: URL) async {
        do { _ = try await load(cache, url); XCTFail("Expected failed image load") } catch {}
    }

    private func download() async throws -> NativeImage {
        let downloader = NativeImageDownloader {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [ImageURLProtocol.self]
            return configuration
        }
        return try await withCheckedThrowingContinuation { continuation in
            downloader.download(imageURL("network")) { continuation.resume(with: $0) }
        }
    }
}

private final class FakeImageDownloader: NativeImageDownloading {
    private let lock = NSLock()
    private var urls: [URL] = []
    private var active = 0
    private var highestActive = 0
    private var response: Result<NativeImage, Error>
    let delay: TimeInterval

    var requestedURLs: [URL] { lock.withLock { urls } }
    var maximumActive: Int { lock.withLock { highestActive } }
    var result: Result<NativeImage, Error> {
        get { lock.withLock { response } }
        set { lock.withLock { response = newValue } }
    }

    init(result: Result<NativeImage, Error>, delay: TimeInterval = 0) {
        self.response = result
        self.delay = delay
    }

    func download(_ url: URL, completion: @escaping (Result<NativeImage, Error>) -> Void) {
        let response = lock.withLock {
            urls.append(url)
            active += 1
            highestActive = max(highestActive, active)
            return self.response
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            self.lock.withLock { self.active -= 1 }
            completion(response)
        }
    }
}

private final class ImageURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (Int, [String: String], Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = Self.handler else { return }
        let (status, headers, data) = handler(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private final class FakeImageSchemeTask: NSObject, WKURLSchemeTask {
    let request = URLRequest(url: URL(string: "nurio-image://nurio.kr/images/shared")!)
    var onCallback: () -> Void
    var onFinish: (() -> Void)?
    var imageData: Data?
    init(onCallback: @escaping () -> Void) { self.onCallback = onCallback }
    func didReceive(_ response: URLResponse) { onCallback() }
    func didReceive(_ data: Data) { onCallback(); imageData = data }
    func didFinish() { onCallback(); onFinish?() }
    func didFailWithError(_ error: Error) { onCallback(); XCTFail("Unexpected scheme failure: \(error)") }
}

private final class ImageLoadProbe: NSObject, WKScriptMessageHandler {
    let onMessage: (String) -> Void
    init(onMessage: @escaping (String) -> Void) { self.onMessage = onMessage }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        onMessage(message.body as? String ?? "unexpected response")
    }
}
