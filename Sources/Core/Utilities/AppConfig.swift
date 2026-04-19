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

    // MARK: - .env

    private static let envValues: [String: String] = {
        // Look for .env in the main bundle first, then fall back to project root (simulator only)
        if let bundlePath = Bundle.main.path(forResource: ".env", ofType: nil),
           let contents = try? String(contentsOfFile: bundlePath, encoding: .utf8) {
            return parseEnv(contents)
        }
        #if DEBUG
        // In simulator builds, try reading from the project source root
        if let projectDir = ProcessInfo.processInfo.environment["PROJECT_DIR"],
           let contents = try? String(contentsOfFile: "\(projectDir)/.env", encoding: .utf8) {
            return parseEnv(contents)
        }
        #endif
        return [:]
    }()

    private static func parseEnv(_ contents: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
            result[key] = value
        }
        return result
    }

    // MARK: - API

    static var apiBaseURL: URL {
        if let envURL = envValues["api_base_url"], !envURL.isEmpty,
           let url = URL(string: envURL) {
            return url
        }
        switch environment {
        case .development:
            return URL(string: "http://localhost:3000/api")!
        case .staging:
            return URL(string: "https://staging.api.claudecodeui.com/api")!
        case .production:
            return URL(string: "https://api.claudecodeui.com/api")!
        }
    }

    // MARK: - Agent / Warmup

    /// Project path sent with warmup requests.
    /// TODO: Replace with real project selection once project browsing is implemented.
    static var defaultProjectPath: String? {
        nil
    }

    // MARK: - Feature Flags

    static let disableAuthentication: Bool = environment == .development
    static let enableAnalytics: Bool = environment == .production
    static let enableDebugMenu: Bool = environment == .development
}
