import CryptoKit
import Darwin
import Foundation
import ImageIO
import WebKit

/// Only image bytes live here: no page HTML, session cookies, or authenticated requests.
enum NativeImageURL {
    static let scheme = "nurio-image"

    static func sourceURL(from url: URL) -> URL? {
        guard url.scheme?.lowercased() == scheme,
              var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        parts.scheme = "https"
        parts.fragment = nil
        guard let source = parts.url, isAllowed(source) else { return nil }
        return source
    }

    static func isAllowed(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.user == nil, parts.password == nil,
              parts.port == nil || parts.port == 443,
              let rawHost = parts.host?.lowercased() else { return false }
        let host = rawHost.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        guard !host.hasSuffix("."), host != "localhost",
              ![".localhost", ".local", ".internal", ".lan"].contains(where: host.hasSuffix) else { return false }

        var ipv4 = in_addr()
        if inet_pton(AF_INET, host, &ipv4) == 1 {
            guard host.split(separator: ".").allSatisfy({ $0.count == 1 || $0.first != "0" }) else { return false }
            return publicIPv4(UInt32(bigEndian: ipv4.s_addr))
        }
        var ipv6 = in6_addr()
        if inet_pton(AF_INET6, host, &ipv6) == 1 {
            let bytes = withUnsafeBytes(of: &ipv6) { Array($0) }
            // Global unicast only. Excludes local, link-local, multicast and IPv4-mapped forms.
            return bytes[0] & 0xe0 == 0x20 && !(bytes[0] == 0x20 && bytes[1] == 0x01 && bytes[2] == 0x0d && bytes[3] == 0xb8)
        }
        // Reject legacy integer/octal/hex IP notation and single-label intranet names.
        return host.contains(".") && host.split(separator: ".").allSatisfy { label in
            !label.isEmpty && label.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
        } && host.split(separator: ".").last?.contains(where: { $0.isLetter }) == true
    }

    private static func publicIPv4(_ address: UInt32) -> Bool {
        let a = address >> 24, b = (address >> 16) & 255
        return a != 0 && a != 10 && a != 127 && a < 224 &&
            !(a == 100 && (64...127).contains(b)) && !(a == 169 && b == 254) &&
            !(a == 172 && (16...31).contains(b)) && !(a == 192 && (b == 168 || b == 0)) &&
            !(a == 198 && (b == 18 || b == 19))
    }
}

struct NativeImage: Codable, Equatable {
    let data: Data
    let mimeType: String
}

enum NativeImageError: Error {
    case invalidURL, invalidResponse, invalidImage, tooLarge, invalidRedirect
}

protocol NativeImageDownloading {
    func download(_ url: URL, completion: @escaping (Result<NativeImage, Error>) -> Void)
}

final class NativeImageCache {
    static let maximumImageBytes = 20 * 1024 * 1024
    static let shared = NativeImageCache(
        directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NurioImages/v1", isDirectory: true)
    )

    private struct Entry: Codable {
        let image: NativeImage
        let digest: String
    }

    private let directory: URL
    private let byteLimit: Int
    private let downloader: NativeImageDownloading
    private let queue = DispatchQueue(label: "kr.nurio.image-cache", qos: .utility)
    private var waiting: [String: [(Result<NativeImage, Error>) -> Void]] = [:]
    private var pending: [(String, URL)] = []
    private var activeDownloads = 0
    private let concurrentDownloads: Int

    init(directory: URL, byteLimit: Int = 256 * 1024 * 1024,
         downloader: NativeImageDownloading = NativeImageDownloader(), concurrentDownloads: Int = 4) {
        self.directory = directory
        self.byteLimit = byteLimit
        self.downloader = downloader
        self.concurrentDownloads = max(1, concurrentDownloads)
    }

    func load(_ url: URL, completion: @escaping (Result<NativeImage, Error>) -> Void) {
        queue.async {
            guard NativeImageURL.isAllowed(url) else {
                completion(.failure(NativeImageError.invalidURL))
                return
            }
            let key = Self.digest(Data(url.absoluteString.utf8))
            if let image = self.read(key) {
                completion(.success(image))
                return
            }
            if self.waiting[key] != nil {
                self.waiting[key]?.append(completion)
                return
            }
            self.waiting[key] = [completion]
            self.pending.append((key, url))
            self.startDownloads()
        }
    }

    private func startDownloads() {
        while activeDownloads < concurrentDownloads, !pending.isEmpty {
            let (key, url) = pending.removeFirst()
            activeDownloads += 1
            downloader.download(url) { result in
                self.queue.async {
                    let validated = result.flatMap { image -> Result<NativeImage, Error> in
                        guard Self.isValid(image) else { return .failure(NativeImageError.invalidImage) }
                        self.save(image, key: key)
                        return .success(image)
                    }
                    let callbacks = self.waiting.removeValue(forKey: key) ?? []
                    self.activeDownloads -= 1
                    callbacks.forEach { $0(validated) }
                    self.startDownloads()
                }
            }
        }
    }

    private func read(_ key: String) -> NativeImage? {
        let file = directory.appendingPathComponent(key)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: file.path) else { return nil }
        guard let size = attributes[.size] as? Int, size <= Self.maximumImageBytes + 4096,
              let data = try? Data(contentsOf: file),
              let entry = try? PropertyListDecoder().decode(Entry.self, from: data),
              entry.digest == Self.digest(entry.image.data), Self.isValid(entry.image) else {
            try? FileManager.default.removeItem(at: file)
            return nil
        }
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
        return entry.image
    }

    private func save(_ image: NativeImage, key: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
            var folder = directory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try folder.setResourceValues(values)
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            let data = try encoder.encode(Entry(image: image, digest: Self.digest(image.data)))
            guard data.count <= byteLimit else { return }
            try data.write(to: directory.appendingPathComponent(key), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            evict()
        } catch {
            // Disk-full or unavailable storage must not prevent this image from displaying.
        }
    }

    private func evict() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory,
                    includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) else { return }
        let entries = files.compactMap { file -> (URL, Int, Date)? in
            guard let values = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                  let size = values.fileSize else { return nil }
            return (file, size, values.contentModificationDate ?? .distantPast)
        }.sorted { $0.2 < $1.2 }
        var total = entries.reduce(0) { $0 + $1.1 }
        for (file, size, _) in entries where total > byteLimit {
            if (try? FileManager.default.removeItem(at: file)) != nil { total -= size }
        }
    }

    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    // ImageIO intentionally recovers some truncated files. Require the format's
    // terminal marker/container length as well so those recoveries are not permanent.
    private static func completeRasterContainer(_ data: Data) -> Bool {
        let bytes = [UInt8](data)
        if bytes.starts(with: [0xff, 0xd8]) {
            return bytes.suffix(2).elementsEqual([0xff, 0xd9])
        }
        if bytes.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]) {
            var offset = 8
            var imageDataSeen = false
            while offset + 12 <= bytes.count {
                let length = (0..<4).reduce(0) { ($0 << 8) | Int(bytes[offset + $1]) }
                guard length <= bytes.count - offset - 12 else { return false }
                let type = String(bytes: bytes[(offset + 4)..<(offset + 8)], encoding: .ascii)
                if type == "IDAT" { imageDataSeen = true }
                if type == "IEND" { return imageDataSeen && length == 0 && offset + 12 == bytes.count }
                offset += length + 12
            }
            return false
        }
        if bytes.starts(with: Array("GIF8".utf8)) { return bytes.last == 0x3b }
        if bytes.count >= 12, bytes.starts(with: Array("RIFF".utf8)),
           bytes[8..<12].elementsEqual(Array("WEBP".utf8)) {
            let size = (0..<4).reduce(0) { $0 | (Int(bytes[4 + $1]) << (8 * $1)) }
            return size + 8 == bytes.count
        }
        return true
    }

    static func isValid(_ image: NativeImage) -> Bool {
        guard !image.data.isEmpty, image.data.count <= maximumImageBytes, image.mimeType.hasPrefix("image/") else { return false }
        if image.mimeType == "image/svg+xml" { return StaticSVGValidator.validate(image.data) }
        guard completeRasterContainer(image.data),
              let source = CGImageSourceCreateWithData(image.data as CFData, nil),
              CGImageSourceGetStatus(source) == .statusComplete, CGImageSourceGetCount(source) > 0,
              CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 20_000, height <= 20_000,
              width * height <= 80_000_000 else { return false }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 32,
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) != nil
    }
}

private final class StaticSVGValidator: NSObject, XMLParserDelegate {
    private var rootSeen = false
    private var valid = true
    private var textContent = ""
    private static let localReference = try! NSRegularExpression(
        pattern: ##"(?i)url\s*\(\s*(?:#[A-Za-z0-9_.:-]+|'#[A-Za-z0-9_.:-]+'|"#[A-Za-z0-9_.:-]+")\s*\)"##
    )

    static func validate(_ data: Data) -> Bool {
        // Only UTF-8 static SVGs are cached; other forms use the ordinary HTTPS fallback.
        guard let text = String(data: data, encoding: .utf8),
              !text.lowercased().contains("<!doctype"), !text.lowercased().contains("<!entity"),
              safeReferences(text) else { return false }
        let validator = StaticSVGValidator()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = validator
        return parser.parse() && validator.rootSeen && validator.valid && safeReferences(validator.textContent)
    }

    private static func safeReferences(_ text: String) -> Bool {
        // CSS escapes could conceal external URLs. Static images with those forms
        // use HTTPS fallback; ordinary local gradients, masks and clip paths persist.
        guard !text.contains("\\"), !text.lowercased().contains("@import") else { return false }
        let withoutLocalReferences = localReference.stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..., in: text), withTemplate: ""
        )
        return withoutLocalReferences.range(of: #"url\s*\("#, options: [.regularExpression, .caseInsensitive]) == nil
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textContent += string
    }

    func parser(_ parser: XMLParser, foundProcessingInstructionWithTarget target: String, data: String?) {
        valid = false
        parser.abortParsing()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if !rootSeen {
            valid = elementName == "svg"
            rootSeen = true
        }
        if ["script", "foreignobject", "iframe", "image", "animate", "set"].contains(elementName.lowercased()) { valid = false }
        for (name, value) in attributeDict {
            if !Self.safeReferences(value) || name.lowercased().hasPrefix("on") ||
                ((name == "href" || name == "xlink:href") && !value.hasPrefix("#")) { valid = false }
        }
        if !valid { parser.abortParsing() }
    }
}

final class NativeImageDownloader: NativeImageDownloading {
    private let configuration: () -> URLSessionConfiguration

    init(configuration: @escaping () -> URLSessionConfiguration = { .ephemeral }) {
        self.configuration = configuration
    }

    func download(_ url: URL, completion: @escaping (Result<NativeImage, Error>) -> Void) {
        NativeImageDownload(url: url, configuration: configuration(), completion: completion).start()
    }
}

final class NativeImageDownload: NSObject, URLSessionDataDelegate {
    private let url: URL
    private let configuration: URLSessionConfiguration
    private var completion: ((Result<NativeImage, Error>) -> Void)?
    private var session: URLSession?
    private var bytes = Data()
    private var mimeType: String?
    private var redirects = 0

    init(url: URL, configuration: URLSessionConfiguration,
         completion: @escaping (Result<NativeImage, Error>) -> Void) {
        self.url = url
        self.configuration = configuration
        self.completion = completion
    }

    func start() {
        guard NativeImageURL.isAllowed(url) else { finish(.failure(NativeImageError.invalidURL)); return }
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpAdditionalHeaders = [:]
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 60
        let delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 1
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
        self.session = session
        session.dataTask(with: request(url)).resume()
    }

    private func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 25)
        request.httpShouldHandleCookies = false
        request.setValue("image/avif,image/webp,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
        return request
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode),
              response.statusCode != 206, response.value(forHTTPHeaderField: "Content-Range") == nil,
              let mime = response.mimeType?.lowercased(), mime.hasPrefix("image/") else {
            completionHandler(.cancel)
            finish(.failure(NativeImageError.invalidResponse))
            return
        }
        guard response.expectedContentLength <= NativeImageCache.maximumImageBytes else {
            completionHandler(.cancel)
            finish(.failure(NativeImageError.tooLarge))
            return
        }
        mimeType = mime
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard completion != nil else { return }
        guard bytes.count <= NativeImageCache.maximumImageBytes - data.count else {
            dataTask.cancel()
            finish(.failure(NativeImageError.tooLarge))
            return
        }
        bytes.append(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { finish(.failure(error)) }
        else if let mimeType { finish(.success(NativeImage(data: bytes, mimeType: mimeType))) }
        else { finish(.failure(NativeImageError.invalidResponse)) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard redirects < 5, let destination = request.url, NativeImageURL.isAllowed(destination) else {
            completionHandler(nil)
            finish(.failure(NativeImageError.invalidRedirect))
            return
        }
        redirects += 1
        // Rebuild every request so redirects cannot carry credentials or original page headers.
        completionHandler(self.request(destination))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            completionHandler(.performDefaultHandling, nil)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    private func finish(_ result: Result<NativeImage, Error>) {
        guard let completion else { return }
        self.completion = nil
        completion(result)
        session?.invalidateAndCancel()
        session = nil
    }
}

/// WebKit calls start/stop on the main thread. Delivery is also dispatched there so
/// a stopped task is never touched, even while its shared download finishes on disk.
final class NativeImageSchemeHandler: NSObject, WKURLSchemeHandler {
    private let cache: NativeImageCache
    private var tasks: [ObjectIdentifier: UUID] = [:]

    init(cache: NativeImageCache = .shared) { self.cache = cache }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let requestedURL = urlSchemeTask.request.url,
              let sourceURL = NativeImageURL.sourceURL(from: requestedURL) else {
            urlSchemeTask.didFailWithError(NativeImageError.invalidURL)
            return
        }
        let id = ObjectIdentifier(urlSchemeTask)
        let generation = UUID()
        tasks[id] = generation
        cache.load(sourceURL) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.tasks[id] == generation else { return }
                switch result {
                case .success(let image):
                    let response = URLResponse(url: requestedURL, mimeType: image.mimeType,
                                               expectedContentLength: image.data.count, textEncodingName: nil)
                    urlSchemeTask.didReceive(response)
                    guard self.tasks[id] == generation else { return }
                    urlSchemeTask.didReceive(image.data)
                    guard self.tasks[id] == generation else { return }
                    self.tasks.removeValue(forKey: id)
                    urlSchemeTask.didFinish()
                case .failure(let error):
                    self.tasks.removeValue(forKey: id)
                    urlSchemeTask.didFailWithError(error)
                }
            }
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        tasks.removeValue(forKey: ObjectIdentifier(urlSchemeTask))
    }
}
