import Foundation

/// Central place for compile-time and runtime configuration.
enum AppConfig {
    // MARK: - Environment

    enum Environment {
        case development
        case staging
        case production
    }

    static let environment: Environment = {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }()

    // MARK: - API

    static var apiBaseURL: URL {
        switch environment {
        case .development:
            return URL(string: "http://localhost:3000/api/v1")!
        case .staging:
            return URL(string: "https://staging.api.claudecodeui.com/api/v1")!
        case .production:
            return URL(string: "https://api.claudecodeui.com/api/v1")!
        }
    }

    // MARK: - Feature Flags

    static let disableAuthentication: Bool = environment == .development
    static let enableAnalytics: Bool = environment == .production
    static let enableDebugMenu: Bool = environment == .development
}
