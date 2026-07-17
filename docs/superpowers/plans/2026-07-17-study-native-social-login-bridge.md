# Nurio Study Native Social Login Bridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Kakao, Google, and Naver sign-in return reliably to the dedicated Nurio Study iOS and Android apps and establish a remembered Rails session on `study.nurio.kr`.

**Architecture:** Reuse the existing Rails Kakao token exchange and one-time native handoff. Kakao uses KakaoSDK in both Study clients; Google and Naver keep their current OS authentication sessions. A provider/host allowlist drives both the Hotwire bridge component and route handler, and Study callbacks use `nuriostudy://auth-callback` to avoid colliding with the main Nurio apps.

**Tech Stack:** Rails 8.1, Rodauth/OAuth, RSpec, Hotwire Native iOS/Android, Swift/XCTest, Kotlin/JUnit, Kakao iOS SDK 2.28.0, Kakao Android SDK 2.24.0.

---

## Repository boundaries

This feature spans two repositories:

- Rails: `/Users/ws/es/business/nurioworkspace/nurio`
- Mobile: `/Users/ws/es/business/nurioworkspace/nurio-mobile`

Both worktrees already contain unrelated user changes. Before implementation, use `superpowers:using-git-worktrees` to create an isolated worktree for each repository. If worktrees cannot be used, record `git status --short` in both repositories and use `git commit --only <task paths>` for every commit. Never stage, restore, or commit unrelated paths.

Do not touch `flutter_app/`, `/admin/*`, `/tutoring*`, `/tutors*`, the main `ios/` client, or the main `android/` client.

## File map

### Rails repository

- Modify `app/controllers/application_controller.rb`: recognize Study native user agents.
- Modify `app/helpers/application_helper.rb`: keep fallback native detection consistent.
- Modify `app/views/study/welcomes/show.html.erb`: attach the existing OAuth bridge to all three Study social links.
- Create `app/services/native_sign_in/callback_url.rb`: choose the Study or main app callback scheme from a trusted request host.
- Modify `app/misc/rodauth_main.rb`: use the callback URL service for native OAuth completion.
- Modify `app/controllers/native_auth_controller.rb`: use the host-aware redirect resolver after handoff.
- Modify `spec/helpers/application_helper_spec.rb`: cover both Study user agents.
- Modify `spec/requests/welcome_page_spec.rb`: cover bridge attributes for Kakao, Google, and Naver.
- Create `spec/services/native_sign_in/callback_url_spec.rb`: cover callback schemes and encoding.
- Modify `spec/requests/native_auth_spec.rb`: cover the Study post-login destination.

### Mobile repository: Study iOS

- Modify `study-nurio-mobile/ios/AppEnvironment.swift`: use the unique Study callback scheme.
- Create `study-nurio-mobile/ios/SocialAuthRoute.swift`: provider and host allowlist.
- Create `study-nurio-mobile/ios/NativeAuthHandoffClient.swift`: Kakao access-token exchange.
- Create `study-nurio-mobile/ios/NativeKakaoSignInCoordinator.swift`: KakaoSDK login and handoff.
- Create `study-nurio-mobile/ios/SocialAuthCoordinator.swift`: shared dispatch for bridge and route entry points.
- Modify `study-nurio-mobile/ios/OAuthSessionCoordinator.swift`: report cancellation and failures explicitly.
- Modify `study-nurio-mobile/ios/Routing/OAuthRouteDecisionHandler.swift`: dispatch through the shared coordinator.
- Modify `study-nurio-mobile/ios/Bridge/SignInWithOAuthComponent.swift`: dispatch through the shared coordinator.
- Modify `study-nurio-mobile/ios/AppDelegate.swift`: initialize KakaoSDK.
- Modify `study-nurio-mobile/ios/SceneController.swift`: hand Kakao app-return URLs to KakaoSDK.
- Modify `study-nurio-mobile/ios/Info.plist`: register Study and Kakao callback schemes.
- Modify `study-nurio-mobile/ios/Tests/NurioStudyTests.swift`: cover routing, handoff, and callback behavior.
- Modify `study-nurio-mobile/ios/NurioStudy.xcodeproj/project.pbxproj`: add source files and Kakao package products.

### Mobile repository: Study Android

- Modify `study-nurio-mobile/android/settings.gradle.kts`: add Kakao's official Maven repository.
- Modify `study-nurio-mobile/android/gradle/libs.versions.toml`: pin Kakao SDK 2.24.0 and JUnit.
- Modify `study-nurio-mobile/android/app/build.gradle.kts`: expose a non-secret native key setting and add dependencies.
- Modify `study-nurio-mobile/android/app/src/main/AndroidManifest.xml`: register Kakao and Study callbacks.
- Create `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/auth/SocialAuthRoute.kt`: provider and host allowlist.
- Create `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/auth/NativeAuthHandoffClient.kt`: Kakao exchange and callback construction.
- Create `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/auth/NativeKakaoSignInCoordinator.kt`: KakaoSDK login.
- Create `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/auth/SocialAuthCoordinator.kt`: shared provider dispatch.
- Modify `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/StudyApplication.kt`: initialize KakaoSDK when configured.
- Modify `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/MainActivity.kt`: accept `nuriostudy` callbacks and expose in-app handoff routing.
- Modify both Android OAuth entry points to use `SocialAuthCoordinator`.
- Create local unit tests under `study-nurio-mobile/android/app/src/test/java/com/nurio/study/android/auth/`.

- Create `study-nurio-mobile/docs/SOCIAL_LOGIN.md`: console setup and real-device runbook.

## Task 1: Recognize Study clients and bridge the Study login links

**Repository:** Rails

**Files:**
- Modify: `app/controllers/application_controller.rb:390`
- Modify: `app/helpers/application_helper.rb:457`
- Modify: `app/views/study/welcomes/show.html.erb:31`
- Test: `spec/helpers/application_helper_spec.rb`
- Test: `spec/requests/welcome_page_spec.rb`

- [ ] **Step 1: Write failing native-user-agent tests**

Add this example to `describe "#native_oauth_request_path"`:

```ruby
it "adds the native platform param for both Nurio Study clients" do
  [ "Nurio Study iOS", "Nurio Study Android" ].each do |user_agent|
    request = instance_double(
      ActionDispatch::Request,
      user_agent: user_agent,
      env: {},
      script_name: ""
    )
    allow(helper).to receive(:request).and_return(request)

    expect(helper.native_oauth_request_path(:google_oauth2)).to eq(
      "/auth/google_oauth2?platform=native"
    )
  end
end
```

- [ ] **Step 2: Write the failing bridge-markup request test**

In `spec/requests/welcome_page_spec.rb`, add this environment wrapper and example:

```ruby
around do |example|
  original_google_client_id = ENV["GOOGLE_CLIENT_ID"]
  original_naver_client_id = ENV["NAVER_CLIENT_ID"]
  ENV["GOOGLE_CLIENT_ID"] = "study-google-client-test"
  ENV["NAVER_CLIENT_ID"] = "study-naver-client-test"
  example.run
ensure
  original_google_client_id.nil? ? ENV.delete("GOOGLE_CLIENT_ID") : ENV["GOOGLE_CLIENT_ID"] = original_google_client_id
  original_naver_client_id.nil? ? ENV.delete("NAVER_CLIENT_ID") : ENV["NAVER_CLIENT_ID"] = original_naver_client_id
end

it "marks every Study social login link for the native OAuth bridge" do
  get study_welcome_path, headers: {
    "HTTP_USER_AGENT" => "Mozilla/5.0 Nurio Study iOS Hotwire Native"
  }

  document = Nokogiri::HTML(response.body)
  paths = [ "/auth/kakao", "/auth/google_oauth2", "/auth/naver" ]

  paths.each do |path|
    link = document.css('a[data-controller~="bridge--sign-in-with-oauth"]').find do |candidate|
      candidate["data-bridge--sign-in-with-oauth-start-path-value"].to_s.start_with?(path)
    end

    expect(link).to be_present, "expected a bridged social link for #{path}"
    expect(link["data-bridge--sign-in-with-oauth-start-path-value"]).to include("platform=native")
  end
end
```

- [ ] **Step 3: Run the focused tests and verify RED**

Run:

```bash
mise exec -- bundle exec rspec spec/helpers/application_helper_spec.rb spec/requests/welcome_page_spec.rb
```

Expected: the Study user-agent example omits `platform=native`, and the welcome markup example cannot find bridge-enabled links.

- [ ] **Step 4: Implement explicit Study native detection**

Replace the predicate body in `ApplicationController#native_app_request?` with:

```ruby
def native_app_request?
  user_agent = request.user_agent.to_s
  return false if user_agent.blank?

  user_agent.include?("Nurio Android") ||
    user_agent.include?("Nurio iOS") ||
    user_agent.include?("Nurio Study Android") ||
    user_agent.include?("Nurio Study iOS") ||
    hotwire_native_request?
end
```

Make the fallback branch of `ApplicationHelper#nurio_native_app_request?` use the same four explicit Nurio prefixes before the generic Hotwire checks.

- [ ] **Step 5: Attach the existing bridge to all three Study links**

For each provider in `app/views/study/welcomes/show.html.erb`, assign the path once and pass it to both `href` and the bridge value. The Kakao shape is:

```erb
<% kakao_auth_path = native_oauth_request_path(:kakao) %>
<%= link_to(
      kakao_auth_path,
      class: "flex h-14 w-full items-center justify-center gap-3 rounded-full bg-[#FEE500] px-6 text-base font-bold text-[#191919] transition-all hover:bg-[#FADA0A] active:scale-95",
      data: {
        controller: "bridge--sign-in-with-oauth",
        bridge__sign_in_with_oauth_start_path_value: kakao_auth_path
      }
    ) do %>
```

Use the identical `data` keys for Google and Naver, with `google_auth_path` and `naver_auth_path`. Preserve their existing conditional rendering and copy.

- [ ] **Step 6: Run the tests and verify GREEN**

Run the command from Step 3. Expected: all examples pass.

- [ ] **Step 7: Commit only Task 1 files**

```bash
git add app/controllers/application_controller.rb app/helpers/application_helper.rb app/views/study/welcomes/show.html.erb spec/helpers/application_helper_spec.rb spec/requests/welcome_page_spec.rb
git commit --only app/controllers/application_controller.rb app/helpers/application_helper.rb app/views/study/welcomes/show.html.erb spec/helpers/application_helper_spec.rb spec/requests/welcome_page_spec.rb -m "fix: bridge Study social login requests"
```

## Task 2: Give Study OAuth a unique callback and host-aware destination

**Repository:** Rails

**Files:**
- Create: `app/services/native_sign_in/callback_url.rb`
- Create: `spec/services/native_sign_in/callback_url_spec.rb`
- Modify: `app/misc/rodauth_main.rb:143`
- Modify: `app/controllers/native_auth_controller.rb:16`
- Modify: `spec/requests/native_auth_spec.rb`

- [ ] **Step 1: Write the failing callback URL service spec**

Create:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe NativeSignIn::CallbackUrl do
  describe ".build" do
    it "uses the Study scheme for the Study production host" do
      url = described_class.build(
        request_host: "study.nurio.kr",
        token: "signed token",
        state: "one/time"
      )

      expect(url).to eq(
        "nuriostudy://auth-callback?token=signed+token&state=one%2Ftime"
      )
    end

    it "keeps the main Nurio scheme for the main host" do
      url = described_class.build(
        request_host: "nurio.kr",
        token: "token",
        state: "state"
      )

      expect(url).to eq("nurio://auth-callback?token=token&state=state")
    end

    it "recognizes a Study host with a port" do
      url = described_class.build(
        request_host: "study.lvh.me:3000",
        token: "token",
        state: "state"
      )

      expect(url).to start_with("nuriostudy://auth-callback?")
    end
  end
end
```

- [ ] **Step 2: Write the failing Study handoff destination test**

Add this request example:

```ruby
it "redirects a completed account to the Study root on the Study host" do
  account = create(:account, status: :verified)
  account.profile.update!(onboarding_completed: true)
  token = account.signed_id(purpose: :native_auth, expires_in: 5.minutes)
  state = NativeAuthHandoffState.issue!(token: token, expires_in: 5.minutes)
  host! "study.nurio.kr"

  get native_token_auth_path, params: { token: token, state: state }

  expect(response).to redirect_to("/")
  expect(session[:account_id]).to eq(account.id)
  expect(account.reload.remember_key).to be_present
end
```

- [ ] **Step 3: Run the focused tests and verify RED**

```bash
mise exec -- bundle exec rspec spec/services/native_sign_in/callback_url_spec.rb spec/requests/native_auth_spec.rb
```

Expected: the callback service is missing and completed Study accounts still redirect to `/home`.

- [ ] **Step 4: Implement the callback URL service**

Create:

```ruby
# frozen_string_literal: true

module NativeSignIn
  class CallbackUrl
    MAIN_SCHEME = "nurio"
    STUDY_SCHEME = "nuriostudy"

    def self.build(request_host:, token:, state:)
      host = request_host.to_s.split(":", 2).first.to_s.downcase
      scheme = host.split(".").first == "study" ? STUDY_SCHEME : MAIN_SCHEME
      query = Rack::Utils.build_query(token: token, state: state)

      "#{scheme}://auth-callback?#{query}"
    end
  end
end
```

- [ ] **Step 5: Use the service from Rodauth**

In the `platform == "native"` branch of `login_redirect`, replace direct `nurio://` string construction with:

```ruby
NativeSignIn::CallbackUrl.build(
  request_host: request.host,
  token: token,
  state: state
)
```

Keep the five-minute expiry and `NativeAuthHandoffState.issue!` unchanged.

- [ ] **Step 6: Make native session completion host-aware**

Replace the completed-profile branch in `NativeAuthController#token_auth` with:

```ruby
destination = if account.profile&.onboarding_completed?
  AuthRedirectPathResolver.new(
    account: account,
    request_subdomain: request.host
  ).authenticated_path
elsif SignupIntent.party_source?(account.profile&.signup_source)
  party_onboarding_path
else
  onboardings_wizard_path
end
```

- [ ] **Step 7: Run the focused and existing Kakao tests**

```bash
mise exec -- bundle exec rspec spec/services/native_sign_in/callback_url_spec.rb spec/requests/native_auth_spec.rb spec/services/kakao/native_sign_in_service_spec.rb spec/requests/kakao_native_sign_ins_spec.rb
```

Expected: all examples pass.

- [ ] **Step 8: Commit only Task 2 files**

```bash
git add app/services/native_sign_in/callback_url.rb app/misc/rodauth_main.rb app/controllers/native_auth_controller.rb spec/services/native_sign_in/callback_url_spec.rb spec/requests/native_auth_spec.rb
git commit --only app/services/native_sign_in/callback_url.rb app/misc/rodauth_main.rb app/controllers/native_auth_controller.rb spec/services/native_sign_in/callback_url_spec.rb spec/requests/native_auth_spec.rb -m "feat: route native auth back to Nurio Study"
```

## Task 3: Add testable Study iOS route and handoff primitives

**Repository:** Mobile

**Files:**
- Modify: `study-nurio-mobile/ios/AppEnvironment.swift`
- Create: `study-nurio-mobile/ios/SocialAuthRoute.swift`
- Create: `study-nurio-mobile/ios/NativeAuthHandoffClient.swift`
- Modify: `study-nurio-mobile/ios/Tests/NurioStudyTests.swift`
- Modify: `study-nurio-mobile/ios/NurioStudy.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write failing callback and route-policy tests**

Update the existing native callback fixtures from `nurio://` to `nuriostudy://`. Add:

```swift
func testSocialAuthRouteAcceptsStudyProviders() {
    let baseURL = URL(string: "https://study.nurio.kr")!

    XCTAssertEqual(
        SocialAuthRoute.resolve(startPath: "/auth/kakao?platform=native", baseURL: baseURL)?.provider,
        .kakao
    )
    XCTAssertEqual(
        SocialAuthRoute.resolve(startPath: "/auth/google_oauth2", baseURL: baseURL)?.provider,
        .google
    )
    XCTAssertEqual(
        SocialAuthRoute.resolve(startPath: "/auth/naver", baseURL: baseURL)?.provider,
        .naver
    )
}

func testSocialAuthRouteRejectsForeignHostsAndUnknownPaths() {
    let baseURL = URL(string: "https://study.nurio.kr")!

    XCTAssertNil(SocialAuthRoute.resolve(startPath: "https://evil.example/auth/kakao", baseURL: baseURL))
    XCTAssertNil(SocialAuthRoute.resolve(startPath: "/admin/events", baseURL: baseURL))
}
```

- [ ] **Step 2: Write the failing handoff parsing test**

```swift
func testNativeHandoffBuildsStudyCallback() throws {
    let data = #"{"token":"signed token","state":"one/time"}"#.data(using: .utf8)!
    let callback = try NativeAuthHandoffClient.callbackURL(from: data)

    XCTAssertEqual(callback.scheme, "nuriostudy")
    XCTAssertEqual(callback.host, "auth-callback")
    XCTAssertEqual(URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems, [
        URLQueryItem(name: "token", value: "signed token"),
        URLQueryItem(name: "state", value: "one/time")
    ])
}
```

- [ ] **Step 3: Add project references needed to compile the failing tests**

Add `SocialAuthRoute.swift` and `NativeAuthHandoffClient.swift` file references to the Support group and their build-file IDs to the app Sources phase. Do not add implementations yet.

- [ ] **Step 4: Run the iOS tests and verify RED**

```bash
xcodebuild -project study-nurio-mobile/ios/NurioStudy.xcodeproj -scheme NurioStudy -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.2' test CODE_SIGNING_ALLOWED=NO
```

Expected: compilation fails because `SocialAuthRoute` and `NativeAuthHandoffClient` do not exist.

- [ ] **Step 5: Implement the allowlisted route model**

Create:

```swift
import Foundation

enum SocialAuthProvider: Equatable {
    case kakao
    case google
    case naver

    init?(path: String) {
        switch path {
        case "/auth/kakao": self = .kakao
        case "/auth/google_oauth2": self = .google
        case "/auth/naver": self = .naver
        default: return nil
        }
    }
}

struct SocialAuthRoute: Equatable {
    let provider: SocialAuthProvider
    let url: URL

    static func resolve(startPath: String, baseURL: URL) -> SocialAuthRoute? {
        guard let resolved = URL(string: startPath, relativeTo: baseURL)?.absoluteURL else { return nil }
        guard [ "http", "https" ].contains(resolved.scheme?.lowercased() ?? "") else { return nil }
        guard resolved.host?.lowercased() == baseURL.host?.lowercased() else { return nil }
        guard let provider = SocialAuthProvider(path: resolved.path) else { return nil }

        return SocialAuthRoute(provider: provider, url: resolved)
    }
}
```

- [ ] **Step 6: Implement the handoff client and codec**

Create `NativeAuthHandoffClient.swift` with this implementation:

```swift
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
        let endpoint = baseURL
            .appendingPathComponent("auth")
            .appendingPathComponent("kakao")
            .appendingPathComponent("native")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try? JSONSerialization.data(
            withJSONObject: [ "access_token": accessToken ]
        )

        session.dataTask(with: request) { data, response, error in
            let result: Result<URL, NativeAuthHandoffError>
            if error != nil {
                result = .failure(.transport)
            } else if let http = response as? HTTPURLResponse,
                      !(200..<300).contains(http.statusCode) {
                result = .failure(.rejected(http.statusCode))
            } else if let data {
                result = Result { try Self.callbackURL(from: data) }
                    .mapError { ($0 as? NativeAuthHandoffError) ?? .invalidResponse }
            } else {
                result = .failure(.invalidResponse)
            }

            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    static func callbackURL(from data: Data) throws -> URL {
        let payload = try JSONDecoder().decode(NativeAuthHandoffPayload.self, from: data)
        guard !payload.token.isEmpty, !payload.state.isEmpty else {
            throw NativeAuthHandoffError.invalidResponse
        }

        var components = URLComponents()
        components.scheme = AppEnvironment.callbackScheme
        components.host = "auth-callback"
        components.queryItems = [
            URLQueryItem(name: "token", value: payload.token),
            URLQueryItem(name: "state", value: payload.state)
        ]
        guard let url = components.url else { throw NativeAuthHandoffError.invalidResponse }
        return url
    }
}
```

Change `AppEnvironment.callbackScheme` to `nuriostudy`.

- [ ] **Step 7: Run tests and verify GREEN**

Run the command from Step 4. Expected: all existing and new tests pass.

- [ ] **Step 8: Commit Task 3**

```bash
git add study-nurio-mobile/ios/AppEnvironment.swift study-nurio-mobile/ios/SocialAuthRoute.swift study-nurio-mobile/ios/NativeAuthHandoffClient.swift study-nurio-mobile/ios/Tests/NurioStudyTests.swift study-nurio-mobile/ios/NurioStudy.xcodeproj/project.pbxproj
git commit --only study-nurio-mobile/ios/AppEnvironment.swift study-nurio-mobile/ios/SocialAuthRoute.swift study-nurio-mobile/ios/NativeAuthHandoffClient.swift study-nurio-mobile/ios/Tests/NurioStudyTests.swift study-nurio-mobile/ios/NurioStudy.xcodeproj/project.pbxproj -m "feat: add Study iOS social auth primitives"
```

## Task 4: Wire native Kakao into the Study iOS bridge

**Repository:** Mobile

**Files:**
- Create: `study-nurio-mobile/ios/NativeKakaoSignInCoordinator.swift`
- Create: `study-nurio-mobile/ios/SocialAuthCoordinator.swift`
- Modify: `study-nurio-mobile/ios/OAuthSessionCoordinator.swift`
- Modify: `study-nurio-mobile/ios/Routing/OAuthRouteDecisionHandler.swift`
- Modify: `study-nurio-mobile/ios/Bridge/SignInWithOAuthComponent.swift`
- Modify: `study-nurio-mobile/ios/AppDelegate.swift`
- Modify: `study-nurio-mobile/ios/SceneController.swift`
- Modify: `study-nurio-mobile/ios/Info.plist`
- Modify: `study-nurio-mobile/ios/NurioStudy.xcodeproj/project.pbxproj`
- Test: `study-nurio-mobile/ios/Tests/NurioStudyTests.swift`

- [ ] **Step 1: Write a failing provider-dispatch test**

Define lightweight `KakaoSignInStarting` and `OAuthSessionStarting` protocols in the production design, then add fakes in the test target and assert:

```swift
func testSocialAuthCoordinatorDispatchesOnlyKakaoToNativeSDK() {
    let kakao = KakaoStarterSpy()
    let oauth = OAuthStarterSpy()
    let coordinator = SocialAuthCoordinator(kakao: kakao, oauth: oauth)

    coordinator.start(route: SocialAuthRoute(
        provider: .kakao,
        url: URL(string: "https://study.nurio.kr/auth/kakao")!
    )) { _ in }

    XCTAssertEqual(kakao.startCount, 1)
    XCTAssertEqual(oauth.startedURLs, [])
}

func testSocialAuthCoordinatorKeepsGoogleAndNaverInSystemAuth() {
    let kakao = KakaoStarterSpy()
    let oauth = OAuthStarterSpy()
    let coordinator = SocialAuthCoordinator(kakao: kakao, oauth: oauth)

    [
        SocialAuthRoute(provider: .google, url: URL(string: "https://study.nurio.kr/auth/google_oauth2")!),
        SocialAuthRoute(provider: .naver, url: URL(string: "https://study.nurio.kr/auth/naver")!)
    ].forEach { route in
        coordinator.start(route: route) { _ in }
    }

    XCTAssertEqual(kakao.startCount, 0)
    XCTAssertEqual(oauth.startedURLs.map(\.path), [ "/auth/google_oauth2", "/auth/naver" ])
}

private final class KakaoStarterSpy: KakaoSignInStarting {
    var startCount = 0

    func start(completion: @escaping (Result<URL, SocialAuthError>) -> Void) {
        startCount += 1
    }
}

private final class OAuthStarterSpy: OAuthSessionStarting {
    var startedURLs: [URL] = []

    func start(url: URL, completion: @escaping (Result<URL, SocialAuthError>) -> Void) {
        startedURLs.append(url)
    }
}
```

Mark both test methods `@MainActor` because the production coordinator is main-actor isolated.

- [ ] **Step 2: Add empty source references and verify RED**

Add the two new Swift file references and source-phase entries, then run the iOS test command. Expected: the new coordinator/protocol types are missing.

- [ ] **Step 3: Implement shared dispatch and error presentation**

Use:

```swift
enum SocialAuthError: Error, Equatable {
    case cancelled
    case notConfigured
    case providerFailed
    case handoffFailed
}

protocol KakaoSignInStarting {
    func start(completion: @escaping (Result<URL, SocialAuthError>) -> Void)
}

protocol OAuthSessionStarting {
    func start(url: URL, completion: @escaping (Result<URL, SocialAuthError>) -> Void)
}

@MainActor
final class SocialAuthCoordinator {
    static let shared = SocialAuthCoordinator(
        kakao: NativeKakaoSignInCoordinator.shared,
        oauth: OAuthSessionCoordinator.shared
    )

    private let kakao: KakaoSignInStarting
    private let oauth: OAuthSessionStarting

    init(kakao: KakaoSignInStarting, oauth: OAuthSessionStarting) {
        self.kakao = kakao
        self.oauth = oauth
    }

    func start(
        route: SocialAuthRoute,
        completion: @escaping (Result<URL, SocialAuthError>) -> Void
    ) {
        switch route.provider {
        case .kakao:
            kakao.start(completion: completion)
        case .google, .naver:
            oauth.start(url: route.url, completion: completion)
        }
    }
}
```

Change `OAuthSessionCoordinator` to conform to `OAuthSessionStarting`, map `ASWebAuthenticationSessionError.canceledLogin` to `.cancelled`, and all other missing/error callbacks to `.providerFailed`.

Add one shared handler in both the route handler and bridge component: successful URLs go to `AppRouteCoordinator`; cancellation is silent; other failures present a `UIAlertController` titled `Sign-in failed` with `Please try again.`.

- [ ] **Step 4: Add and initialize KakaoSDK 2.28.0**

In the Xcode project, add the exact package `https://github.com/kakao/kakao-ios-sdk` at `2.28.0` and products `KakaoSDKCommon`, `KakaoSDKAuth`, and `KakaoSDKUser` to the Study app target. Add their framework build-file entries.

Add `KAKAO_NATIVE_APP_KEY = "";` to both Study app build configurations. `Info.plist` must contain:

```xml
<key>KAKAO_APP_KEY</key>
<string>$(KAKAO_NATIVE_APP_KEY)</string>
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>kakaokompassauth</string>
  <string>kakaolink</string>
</array>
```

Change the Study auth scheme from `nurio` to `nuriostudy` and add a second URL type whose scheme is `kakao$(KAKAO_NATIVE_APP_KEY)`.

Initialize only a non-empty key:

```swift
private func configureKakaoSDK() {
    guard let key = Bundle.main.object(forInfoDictionaryKey: "KAKAO_APP_KEY") as? String,
          !key.isEmpty else { return }
    KakaoSDK.initSDK(appKey: key)
}
```

Call it after `configureHotwire()`.

- [ ] **Step 5: Implement the native Kakao coordinator**

Adapt the established main-client flow into the Study target, but depend on `NativeAuthHandoffClient` for the backend exchange. The required control flow is:

```swift
func start(completion: @escaping (Result<URL, SocialAuthError>) -> Void) {
    guard let key = Bundle.main.object(forInfoDictionaryKey: "KAKAO_APP_KEY") as? String,
          !key.isEmpty else {
        completion(.failure(.notConfigured))
        return
    }

    let callback: (OAuthToken?, Error?) -> Void = { [weak self] token, error in
        Task { @MainActor in
            if let sdkError = error as? ClientError, sdkError.reason == .Cancelled {
                completion(.failure(.cancelled))
            } else if error != nil {
                completion(.failure(.providerFailed))
            } else if let accessToken = token?.accessToken, !accessToken.isEmpty {
                self?.handoff.exchangeKakao(accessToken: accessToken) { result in
                    completion(result.mapError { _ in .handoffFailed })
                }
            } else {
                completion(.failure(.providerFailed))
            }
        }
    }

    if UserApi.isKakaoTalkLoginAvailable() {
        UserApi.shared.loginWithKakaoTalk(completion: callback)
    } else {
        UserApi.shared.loginWithKakaoAccount(completion: callback)
    }
}
```

Keep only one in-flight completion, as the main coordinator does, so repeated taps cannot start overlapping exchanges.

- [ ] **Step 6: Route bridge and ordinary OAuth links through the coordinator**

`OAuthRouteDecisionHandler.matches` must call `SocialAuthRoute.resolve(startPath: location.absoluteString, baseURL: configuration.startLocation)`. Its `handle` and `SignInWithOAuthComponent.onReceive` must resolve a route and call the same `SocialAuthCoordinator.shared.start` method.

No Study code may open `/auth/kakao` through `OAuthSessionCoordinator`.

- [ ] **Step 7: Handle Kakao app returns before normal app callbacks**

Import `KakaoSDKAuth` in `SceneController`. For both cold launch and `openURLContexts`, run:

```swift
if AuthApi.isKakaoTalkLoginUrl(url) {
    _ = AuthController.handleOpenUrl(url: url)
    startIfNeeded()
    return
}
```

Only non-Kakao URLs continue to `AppRouteCoordinator`.

- [ ] **Step 8: Verify tests and a simulator build**

```bash
xcodebuild -project study-nurio-mobile/ios/NurioStudy.xcodeproj -scheme NurioStudy -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.2' test CODE_SIGNING_ALLOWED=NO
xcodebuild -project study-nurio-mobile/ios/NurioStudy.xcodeproj -scheme NurioStudy -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

Expected: both commands end with `** TEST SUCCEEDED **` / `** BUILD SUCCEEDED **`.

- [ ] **Step 9: Commit Task 4**

```bash
git add study-nurio-mobile/ios
git commit --only study-nurio-mobile/ios/AppDelegate.swift study-nurio-mobile/ios/SceneController.swift study-nurio-mobile/ios/Info.plist study-nurio-mobile/ios/OAuthSessionCoordinator.swift study-nurio-mobile/ios/NativeKakaoSignInCoordinator.swift study-nurio-mobile/ios/SocialAuthCoordinator.swift study-nurio-mobile/ios/Routing/OAuthRouteDecisionHandler.swift study-nurio-mobile/ios/Bridge/SignInWithOAuthComponent.swift study-nurio-mobile/ios/Tests/NurioStudyTests.swift study-nurio-mobile/ios/NurioStudy.xcodeproj/project.pbxproj -m "feat: add native Kakao login to Study iOS"
```

## Task 5: Add testable Study Android route and handoff primitives

**Repository:** Mobile

**Files:**
- Modify: `study-nurio-mobile/android/gradle/libs.versions.toml`
- Modify: `study-nurio-mobile/android/app/build.gradle.kts`
- Create: `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/auth/SocialAuthRoute.kt`
- Create: `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/auth/NativeAuthHandoffClient.kt`
- Create: `study-nurio-mobile/android/app/src/test/java/com/nurio/study/android/auth/SocialAuthRouteTest.kt`
- Create: `study-nurio-mobile/android/app/src/test/java/com/nurio/study/android/auth/NativeAuthHandoffClientTest.kt`

- [ ] **Step 1: Add JUnit and write the failing route tests**

Add JUnit `4.13.2` to the version catalog and `testImplementation(libs.junit)` to the app. Create:

```kotlin
package com.nurio.study.android.auth

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SocialAuthRouteTest {
    private val baseUrl = "https://study.nurio.kr"

    @Test
    fun `accepts all Study social providers`() {
        assertEquals(SocialAuthProvider.KAKAO, SocialAuthRoute.resolve("/auth/kakao", baseUrl)?.provider)
        assertEquals(SocialAuthProvider.GOOGLE, SocialAuthRoute.resolve("/auth/google_oauth2", baseUrl)?.provider)
        assertEquals(SocialAuthProvider.NAVER, SocialAuthRoute.resolve("/auth/naver", baseUrl)?.provider)
    }

    @Test
    fun `rejects foreign hosts and unknown paths`() {
        assertNull(SocialAuthRoute.resolve("https://evil.example/auth/kakao", baseUrl))
        assertNull(SocialAuthRoute.resolve("/admin/events", baseUrl))
    }
}
```

- [ ] **Step 2: Write the failing handoff codec test**

```kotlin
package com.nurio.study.android.auth

import org.junit.Assert.assertEquals
import org.junit.Test

class NativeAuthHandoffClientTest {
    @Test
    fun `builds the unique Study callback`() {
        val callback = NativeAuthHandoffClient.callbackUrl(
            """{"token":"signed token","state":"one/time"}"""
        )

        assertEquals(
            "nuriostudy://auth-callback?token=signed+token&state=one%2Ftime",
            callback
        )
    }
}
```

- [ ] **Step 3: Run Android unit tests and verify RED**

```bash
cd study-nurio-mobile/android
./gradlew testDebugUnitTest
```

Expected: Kotlin compilation fails because the two production types do not exist.

- [ ] **Step 4: Implement pure Kotlin route resolution**

Create:

```kotlin
package com.nurio.study.android.auth

import java.net.URI

enum class SocialAuthProvider(val path: String) {
    KAKAO("/auth/kakao"),
    GOOGLE("/auth/google_oauth2"),
    NAVER("/auth/naver");

    companion object {
        fun fromPath(path: String): SocialAuthProvider? = entries.find { it.path == path }
    }
}

data class SocialAuthRoute(val provider: SocialAuthProvider, val url: String) {
    companion object {
        fun resolve(startPath: String, baseUrl: String): SocialAuthRoute? {
            val base = runCatching { URI(baseUrl) }.getOrNull() ?: return null
            val resolved = runCatching { base.resolve(startPath) }.getOrNull() ?: return null
            if (resolved.scheme?.lowercase() !in setOf("http", "https")) return null
            if (!resolved.host.equals(base.host, ignoreCase = true)) return null
            val provider = SocialAuthProvider.fromPath(resolved.path) ?: return null
            return SocialAuthRoute(provider, resolved.toString())
        }
    }
}
```

- [ ] **Step 5: Implement the Android handoff codec and transport**

Create `NativeAuthHandoffClient.kt`:

```kotlin
package com.nurio.study.android.auth

import com.nurio.study.android.BuildConfig
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.nio.charset.StandardCharsets.UTF_8
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

@Serializable
data class NativeAuthHandoffPayload(val token: String, val state: String)

class NativeAuthHandoffClient(
    private val baseUrl: String = BuildConfig.BASE_URL,
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
) {
    fun exchangeKakao(accessToken: String, callback: (Result<String>) -> Unit) {
        executor.execute {
            callback(runCatching { exchangeKakaoBlocking(accessToken) })
        }
    }

    private fun exchangeKakaoBlocking(accessToken: String): String {
        val endpoint = URL("${baseUrl.trimEnd('/')}/auth/kakao/native")
        val connection = endpoint.openConnection() as HttpURLConnection
        return try {
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Accept", "application/json")
            connection.doOutput = true
            val requestBody = Json.encodeToString(mapOf("access_token" to accessToken))
            connection.outputStream.use { output ->
                output.write(requestBody.toByteArray(Charsets.UTF_8))
            }

            val status = connection.responseCode
            require(status in 200..299) { "native handoff rejected" }
            val responseBody = connection.inputStream.bufferedReader().use { it.readText() }
            callbackUrl(responseBody)
        } finally {
            connection.disconnect()
        }
    }

    companion object {
        fun callbackUrl(responseBody: String): String {
            val payload = Json.decodeFromString<NativeAuthHandoffPayload>(responseBody)
            require(payload.token.isNotBlank() && payload.state.isNotBlank())
            val token = URLEncoder.encode(payload.token, UTF_8)
            val state = URLEncoder.encode(payload.state, UTF_8)
            return "nuriostudy://auth-callback?token=$token&state=$state"
        }
    }
}
```

Never log the request body or callback URL.

- [ ] **Step 6: Run tests and verify GREEN**

Run `./gradlew testDebugUnitTest`. Expected: all tests pass.

- [ ] **Step 7: Commit Task 5**

```bash
git add study-nurio-mobile/android/gradle/libs.versions.toml study-nurio-mobile/android/app/build.gradle.kts study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/auth/SocialAuthRoute.kt study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/auth/NativeAuthHandoffClient.kt study-nurio-mobile/android/app/src/test/java/com/nurio/study/android/auth/SocialAuthRouteTest.kt study-nurio-mobile/android/app/src/test/java/com/nurio/study/android/auth/NativeAuthHandoffClientTest.kt
git commit --only study-nurio-mobile/android/gradle/libs.versions.toml study-nurio-mobile/android/app/build.gradle.kts study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/auth/SocialAuthRoute.kt study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/auth/NativeAuthHandoffClient.kt study-nurio-mobile/android/app/src/test/java/com/nurio/study/android/auth/SocialAuthRouteTest.kt study-nurio-mobile/android/app/src/test/java/com/nurio/study/android/auth/NativeAuthHandoffClientTest.kt -m "feat: add Study Android social auth primitives"
```

## Task 6: Wire native Kakao into the Study Android bridge

**Repository:** Mobile

**Files:**
- Modify: `study-nurio-mobile/android/settings.gradle.kts`
- Modify: `study-nurio-mobile/android/gradle/libs.versions.toml`
- Modify: `study-nurio-mobile/android/app/build.gradle.kts`
- Modify: `study-nurio-mobile/android/app/src/main/AndroidManifest.xml`
- Create: `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/auth/NativeKakaoSignInCoordinator.kt`
- Create: `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/auth/SocialAuthCoordinator.kt`
- Modify: `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/StudyApplication.kt`
- Modify: `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/MainActivity.kt`
- Modify: `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/routing/OAuthRouteDecisionHandler.kt`
- Modify: `study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/bridge/SignInWithOAuthComponent.kt`
- Test: `study-nurio-mobile/android/app/src/test/java/com/nurio/study/android/auth/SocialAuthCoordinatorTest.kt`

- [ ] **Step 1: Write the failing provider-dispatch test**

Model `SocialAuthCoordinator` around injectable lambdas so it is a pure unit. Create the complete test file:

```kotlin
package com.nurio.study.android.auth

import org.junit.Assert.assertEquals
import org.junit.Test

class SocialAuthCoordinatorTest {
@Test
fun `dispatches Kakao natively and Google Naver to system auth`() {
    val nativeProviders = mutableListOf<SocialAuthProvider>()
    val browserUrls = mutableListOf<String>()
    val coordinator = SocialAuthCoordinator(
        startKakao = { nativeProviders += SocialAuthProvider.KAKAO },
        openSystemAuth = { browserUrls += it }
    )

    coordinator.start(SocialAuthRoute(SocialAuthProvider.KAKAO, "https://study.nurio.kr/auth/kakao"))
    coordinator.start(SocialAuthRoute(SocialAuthProvider.GOOGLE, "https://study.nurio.kr/auth/google_oauth2"))
    coordinator.start(SocialAuthRoute(SocialAuthProvider.NAVER, "https://study.nurio.kr/auth/naver"))

    assertEquals(listOf(SocialAuthProvider.KAKAO), nativeProviders)
    assertEquals(
        listOf(
            "https://study.nurio.kr/auth/google_oauth2",
            "https://study.nurio.kr/auth/naver"
        ),
        browserUrls
    )
}
}
```

- [ ] **Step 2: Run the test and verify RED**

```bash
cd study-nurio-mobile/android
./gradlew testDebugUnitTest
```

Expected: `SocialAuthCoordinator` is missing.

- [ ] **Step 3: Implement the pure dispatch core**

```kotlin
class SocialAuthCoordinator(
    private val startKakao: () -> Unit,
    private val openSystemAuth: (String) -> Unit
) {
    fun start(route: SocialAuthRoute) {
        when (route.provider) {
            SocialAuthProvider.KAKAO -> startKakao()
            SocialAuthProvider.GOOGLE, SocialAuthProvider.NAVER -> openSystemAuth(route.url)
        }
    }
}
```

- [ ] **Step 4: Add Kakao SDK 2.24.0 and key plumbing**

Add Kakao's official Maven repository to `dependencyResolutionManagement.repositories`:

```kotlin
maven { url = uri("https://devrepo.kakao.com/nexus/content/groups/public/") }
```

Pin `kakao = "2.24.0"` and add `kakao-user = { module = "com.kakao.sdk:v2-user", version.ref = "kakao" }` to the version catalog.

At the top of the app Gradle file, resolve the non-secret native key without committing its value:

```kotlin
val kakaoNativeAppKey = providers
    .gradleProperty("NURIO_STUDY_KAKAO_NATIVE_APP_KEY")
    .orElse(providers.environmentVariable("NURIO_STUDY_KAKAO_NATIVE_APP_KEY"))
    .orElse("")
    .get()
```

Add to `defaultConfig`:

```kotlin
buildConfigField("String", "KAKAO_NATIVE_APP_KEY", "\"$kakaoNativeAppKey\"")
manifestPlaceholders["KAKAO_NATIVE_APP_KEY"] = kakaoNativeAppKey.ifBlank { "not_configured" }
```

Add `implementation(libs.kakao.user)`.

- [ ] **Step 5: Register the Android callbacks**

Add a KakaoTalk package query and the official handler:

```xml
<queries>
    <package android:name="com.kakao.talk" />
</queries>
```

```xml
<activity
    android:name="com.kakao.sdk.auth.AuthCodeHandlerActivity"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data
            android:scheme="kakao${KAKAO_NATIVE_APP_KEY}"
            android:host="oauth" />
    </intent-filter>
</activity>
```

Change the app handoff intent filter from `nurio` to `nuriostudy`.

- [ ] **Step 6: Initialize KakaoSDK only when configured**

In `StudyApplication.onCreate`:

```kotlin
if (BuildConfig.KAKAO_NATIVE_APP_KEY.isNotBlank()) {
    KakaoSdk.init(this, BuildConfig.KAKAO_NATIVE_APP_KEY)
}
```

Keep Hotwire initialization unchanged.

- [ ] **Step 7: Implement native Kakao login and handoff**

`NativeKakaoSignInCoordinator` receives `MainActivity` and `NativeAuthHandoffClient`. Its flow is:

```kotlin
fun start() {
    if (BuildConfig.KAKAO_NATIVE_APP_KEY.isBlank()) {
        activity.showSocialAuthError()
        return
    }

    val callback: (OAuthToken?, Throwable?) -> Unit = { token, error ->
        when {
            error is ClientError && error.reason == ClientErrorCause.Cancelled -> Unit
            error != null -> activity.showSocialAuthError()
            token?.accessToken.isNullOrBlank() -> activity.showSocialAuthError()
            else -> handoff.exchangeKakao(token!!.accessToken) { result ->
                activity.runOnUiThread {
                    result.onSuccess(activity::routeNativeAuthCallback)
                        .onFailure { activity.showSocialAuthError() }
                }
            }
        }
    }

    if (UserApiClient.instance.isKakaoTalkLoginAvailable(activity)) {
        UserApiClient.instance.loginWithKakaoTalk(activity, callback = callback)
    } else {
        UserApiClient.instance.loginWithKakaoAccount(activity, callback = callback)
    }
}
```

`MainActivity.routeNativeAuthCallback(callbackUrl: String)` must parse the callback, require scheme `nuriostudy` and host `auth-callback`, build the existing `/auth/native/token_auth` URL, and route it immediately or store it in `pendingAuthUrl`. `showSocialAuthError()` displays a short retryable AlertDialog without raw provider details.

- [ ] **Step 8: Use one coordinator from both Android entry points**

Both `OAuthRouteDecisionHandler` and `SignInWithOAuthComponent` must:

1. Resolve the input with `SocialAuthRoute.resolve(..., BuildConfig.BASE_URL)`.
2. Reject a null route.
3. Create the production `SocialAuthCoordinator` with a native Kakao lambda and the existing `CustomTabsIntent` lambda.
4. Start the resolved route.

Delete their independent provider path sets and ad hoc URL concatenation. Kakao must never reach the Custom Tab lambda.

- [ ] **Step 9: Run Android tests and build**

```bash
cd study-nurio-mobile/android
./gradlew testDebugUnitTest
./gradlew assembleDebug
```

Expected: all unit tests pass and `app/build/outputs/apk/debug/app-debug.apk` is produced. A missing native key may disable runtime Kakao but must not fail the build.

- [ ] **Step 10: Commit Task 6**

```bash
git add study-nurio-mobile/android
git commit --only study-nurio-mobile/android/settings.gradle.kts study-nurio-mobile/android/gradle/libs.versions.toml study-nurio-mobile/android/app/build.gradle.kts study-nurio-mobile/android/app/src/main/AndroidManifest.xml study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/StudyApplication.kt study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/MainActivity.kt study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/auth/NativeKakaoSignInCoordinator.kt study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/auth/SocialAuthCoordinator.kt study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/routing/OAuthRouteDecisionHandler.kt study-nurio-mobile/android/app/src/main/java/com/nurio/study/android/bridge/SignInWithOAuthComponent.kt study-nurio-mobile/android/app/src/test/java/com/nurio/study/android/auth/SocialAuthCoordinatorTest.kt -m "feat: add native Kakao login to Study Android"
```

## Task 7: Add the provider-console and real-device runbook

**Repository:** Mobile

**Files:**
- Create: `study-nurio-mobile/docs/SOCIAL_LOGIN.md`
- Modify: `study-nurio-mobile/ios/README.md`

- [ ] **Step 1: Write the runbook**

Document these exact requirements:

- Kakao App ID remains `1352984`; do not create a new Rails audience.
- Create a separate native platform key in that Kakao app for Study.
- Register iOS bundle `com.nurio.study.ios`.
- Register Android package `com.nurio.study.android` with debug and release key hashes.
- Keep `account_email` consent enabled.
- Pass the user-managed `NURIO_STUDY_KAKAO_NATIVE_APP_KEY` value to the iOS `KAKAO_NATIVE_APP_KEY` build setting.
- Pass the same user-managed value to Android through the `NURIO_STUDY_KAKAO_NATIVE_APP_KEY` Gradle property or environment variable.
- Keep `KAKAO_APP_ID` in both Rails deploy secret lists and the user-managed Kamal secrets file.
- Google and Naver continue to use Rails OAuth; confirm their callbacks allow `https://study.nurio.kr/auth/*/callback` as required by the existing provider configuration.
- Never test Kakao web simple-login inside an app authentication sheet.

Include real-device checklists for KakaoTalk installed, KakaoTalk absent, cancellation, Google, Naver, app relaunch persistence, and both apps installed together.

- [ ] **Step 2: Link the runbook from the Study iOS README**

Add a `Social login` section linking to `../docs/SOCIAL_LOGIN.md` and state that the Study callback is `nuriostudy://auth-callback`.

- [ ] **Step 3: Validate documentation paths and diff**

```bash
test -f study-nurio-mobile/docs/SOCIAL_LOGIN.md
git diff --check -- study-nurio-mobile/docs/SOCIAL_LOGIN.md study-nurio-mobile/ios/README.md
```

Expected: both commands exit zero.

- [ ] **Step 4: Commit Task 7**

```bash
git add study-nurio-mobile/docs/SOCIAL_LOGIN.md study-nurio-mobile/ios/README.md
git commit --only study-nurio-mobile/docs/SOCIAL_LOGIN.md study-nurio-mobile/ios/README.md -m "docs: add Study social login runbook"
```

## Task 8: Cross-repository verification and acceptance

**Repositories:** Rails and Mobile

- [ ] **Step 1: Run the complete focused Rails suite**

```bash
mise exec -- bundle exec rspec spec/helpers/application_helper_spec.rb spec/requests/welcome_page_spec.rb spec/services/native_sign_in/callback_url_spec.rb spec/requests/native_auth_spec.rb spec/services/kakao/native_sign_in_service_spec.rb spec/requests/kakao_native_sign_ins_spec.rb
```

Expected: zero failures.

- [ ] **Step 2: Run iOS tests and build from a clean DerivedData directory**

```bash
NURIO_STUDY_DERIVED_DATA=$(mktemp -d)
xcodebuild -project study-nurio-mobile/ios/NurioStudy.xcodeproj -scheme NurioStudy -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.2' -derivedDataPath "$NURIO_STUDY_DERIVED_DATA" test CODE_SIGNING_ALLOWED=NO
xcodebuild -project study-nurio-mobile/ios/NurioStudy.xcodeproj -scheme NurioStudy -destination 'generic/platform=iOS Simulator' -derivedDataPath "$NURIO_STUDY_DERIVED_DATA" build CODE_SIGNING_ALLOWED=NO
```

Expected: test and build succeed. The temporary directory can be removed after verifying it is the exact `mktemp` result.

- [ ] **Step 3: Run Android tests and debug build**

```bash
cd study-nurio-mobile/android
./gradlew testDebugUnitTest assembleDebug
```

Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 4: Run static scope and secret-pattern checks**

Use `rg` only. From the mobile repository:

```bash
rg -n "(/admin/|/tutoring|/tutors|tutors\.)" study-nurio-mobile/ios study-nurio-mobile/android/app/src/main
rg -n "access_token.*(print|log)|token=.*(print|log)|KAKAO_NATIVE_APP_KEY\s*=\s*[A-Fa-f0-9]{20,}" study-nurio-mobile/ios study-nurio-mobile/android
```

From the Rails repository:

```bash
rg -n "access_token.*(print|log)|token=.*(print|log)" app/controllers app/services
```

Expected: no newly added customer navigation to forbidden scopes, no token logging, and no committed Study native key value.

- [ ] **Step 5: Inspect final scoped diffs**

In both repositories:

```bash
git status --short
git diff --check
```

Confirm all unrelated user changes remain untouched and no implementation file is left uncommitted.

- [ ] **Step 6: Perform real-device acceptance when the Study native key is available**

Verify KakaoTalk app-switch and Kakao Account fallback on both platforms, then Google and Naver. For every provider confirm:

- callback opens Nurio Study rather than the main Nurio app;
- final host is `study.nurio.kr`;
- the Rails session survives force-quit and relaunch;
- cancellation returns safely;
- admin and tutor routes remain blocked.

If the provider key or console registration is unavailable, report that exact external blocker while still delivering the passing automated builds and tests.

## Plan self-review

- Spec coverage: Rails native detection, Study callback isolation, KakaoSDK on both clients, Google/Naver system auth, remembered handoff, host-aware redirects, error behavior, documentation, and real-device acceptance are all mapped to tasks.
- Scope: Flutter, main mobile apps, admin, and tutor surfaces remain untouched.
- Type consistency: both clients use `SocialAuthProvider`, `SocialAuthRoute`, `SocialAuthCoordinator`, and a provider-specific handoff client with the same provider split.
- Security: Kakao App ID audience validation remains exclusively on Rails; no client secret or access token logging is introduced.
