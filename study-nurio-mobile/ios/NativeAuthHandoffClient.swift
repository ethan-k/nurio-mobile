import Foundation

enum NativeAuthHandoffError: Error, Equatable, Sendable {
    case invalidResponse
    case rejected(Int)
    case transport
}

struct NativeAuthHandoffPayload: Decodable, Sendable {
    let token: String
    let state: String
}

typealias NativeAuthHandoffCompletion = @MainActor @Sendable (
    Result<URL, NativeAuthHandoffError>
) -> Void

final class NativeAuthRedirectRejectingDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

final class NativeAuthHandoffClient {
    private let baseURL: URL
    private let session: URLSession
    private let redirectDelegate: NativeAuthRedirectRejectingDelegate

    init(
        baseURL: URL = AppEnvironment.baseURL,
        sessionConfiguration: URLSessionConfiguration = .ephemeral
    ) {
        self.baseURL = baseURL
        let redirectDelegate = NativeAuthRedirectRejectingDelegate()
        self.session = URLSession(
            configuration: sessionConfiguration,
            delegate: redirectDelegate,
            delegateQueue: nil
        )
        self.redirectDelegate = redirectDelegate
    }

    func exchangeKakao(
        accessToken: String,
        completion: @escaping NativeAuthHandoffCompletion
    ) {
        let url = baseURL
            .appendingPathComponent("auth")
            .appendingPathComponent("kakao")
            .appendingPathComponent("native")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try? JSONSerialization.data(
            withJSONObject: ["access_token": accessToken]
        )

        session.dataTask(with: request) { data, response, error in
            let result: Result<URL, NativeAuthHandoffError>

            if error != nil {
                result = .failure(.transport)
            } else if let response = response as? HTTPURLResponse {
                if (200..<300).contains(response.statusCode) {
                    guard let data else {
                        Self.complete(.failure(.invalidResponse), using: completion)
                        return
                    }

                    do {
                        result = .success(try Self.callbackURL(from: data))
                    } catch {
                        result = .failure(.invalidResponse)
                    }
                } else {
                    result = .failure(.rejected(response.statusCode))
                }
            } else {
                result = .failure(.invalidResponse)
            }

            Self.complete(result, using: completion)
        }.resume()
    }

    static func callbackURL(from data: Data) throws -> URL {
        let payload: NativeAuthHandoffPayload

        do {
            payload = try JSONDecoder().decode(NativeAuthHandoffPayload.self, from: data)
        } catch {
            throw NativeAuthHandoffError.invalidResponse
        }

        guard !payload.token.isEmpty, !payload.state.isEmpty else {
            throw NativeAuthHandoffError.invalidResponse
        }

        var components = URLComponents()
        components.scheme = AppEnvironment.callbackScheme
        components.host = "auth-callback"
        components.queryItems = [
            URLQueryItem(name: "token", value: payload.token),
            URLQueryItem(name: "state", value: payload.state),
        ]

        guard let url = components.url else {
            throw NativeAuthHandoffError.invalidResponse
        }

        return url
    }

    private static func complete(
        _ result: Result<URL, NativeAuthHandoffError>,
        using completion: @escaping NativeAuthHandoffCompletion
    ) {
        Task { @MainActor in
            completion(result)
        }
    }
}
