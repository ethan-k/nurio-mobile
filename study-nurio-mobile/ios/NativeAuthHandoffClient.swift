import Foundation

enum NativeAuthHandoffError: Error, Equatable {
    case invalidResponse
    case rejected(Int)
    case transport
}

struct NativeAuthHandoffPayload: Decodable {
    let token: String
    let state: String
}

final class NativeAuthHandoffClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = AppEnvironment.baseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func exchangeKakao(
        accessToken: String,
        completion: @escaping (Result<URL, NativeAuthHandoffError>) -> Void
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
        using completion: @escaping (Result<URL, NativeAuthHandoffError>) -> Void
    ) {
        DispatchQueue.main.async {
            completion(result)
        }
    }
}
