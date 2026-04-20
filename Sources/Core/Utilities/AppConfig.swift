import Foundation

/// Central place for compile-time and runtime configuration.
enum AppConfig {
    enum ConfigSource {
        case appSettings
        case envFile
        case builtInDefault
        case unavailable

        var displayName: String {
            switch self {
            case .appSettings:
                return "Settings"
            case .envFile:
                return ".env"
            case .builtInDefault:
                return "Built-in default"
            case .unavailable:
                return "Not set"
            }
        }
    }

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
        for candidate in envCandidatePaths() {
            if let contents = try? String(contentsOfFile: candidate, encoding: .utf8) {
                return parseEnv(contents)
            }
        }
        return [:]
    }()

    private static func envCandidatePaths() -> [String] {
        var paths: [String] = []

        if let bundlePath = Bundle.main.path(forResource: ".env", ofType: nil) {
            paths.append(bundlePath)
        }

        #if DEBUG
        // PROJECT_DIR is often present during builds, but not reliably at runtime.
        if let projectDir = ProcessInfo.processInfo.environment["PROJECT_DIR"] {
            paths.append("\(projectDir)/.env")
        }

        // Use the compile-time source file path to find the repo root in debug builds.
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Utilities
            .deletingLastPathComponent() // Core
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // repo root
            .path
        paths.append("\(repoRoot)/.env")

        let currentDirectory = FileManager.default.currentDirectoryPath
        paths.append("\(currentDirectory)/.env")
        #endif

        return Array(NSOrderedSet(array: paths)) as? [String] ?? paths
    }

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

    private static func boolEnvValue(for keys: [String]) -> Bool? {
        for key in keys {
            guard let rawValue = envValues[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !rawValue.isEmpty else {
                continue
            }

            switch rawValue.lowercased() {
            case "1", "true", "yes", "on":
                return true
            case "0", "false", "no", "off":
                return false
            default:
                continue
            }
        }

        return nil
    }

    // MARK: - API

    static func normalizedAPIBaseURL(from rawValue: String) -> URL? {
        guard let url = URL(string: rawValue),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        guard let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host,
              !host.isBlank else {
            return nil
        }

        #if DEBUG
        // The iOS simulator may prefer IPv6 for "localhost", while the local CloudCLI
        // server commonly binds only on IPv4. Force IPv4 loopback for local debug URLs.
        if components.host == "localhost" {
            components.host = "127.0.0.1"
        }
        #endif

        if components.path.isEmpty || components.path == "/" {
            components.path = "/api"
        }

        return components.url
    }

    static var apiBaseURL: URL {
        if let appURL = appAPIBaseURLOverride {
            return appURL
        }

        if let envURL = envAPIBaseURL {
            return envURL
        }

        switch environment {
        case .development:
            return normalizedAPIBaseURL(from: "http://localhost:3000/api")!
        case .staging:
            return normalizedAPIBaseURL(from: "https://staging.api.claudecodeui.com/api")!
        case .production:
            return normalizedAPIBaseURL(from: "https://api.claudecodeui.com/api")!
        }
    }

    static var apiBaseURLSource: ConfigSource {
        if appAPIBaseURLOverride != nil {
            return .appSettings
        }

        if envAPIBaseURL != nil {
            return .envFile
        }

        return .builtInDefault
    }

    static var hasExplicitAPIBaseURL: Bool {
        appAPIBaseURLOverride != nil || envAPIBaseURL != nil
    }

    static var serverBaseURL: URL {
        guard var components = URLComponents(url: apiBaseURL, resolvingAgainstBaseURL: false) else {
            return apiBaseURL
        }

        if components.path.hasSuffix("/api") {
            components.path = String(components.path.dropLast(4))
        }

        if components.path == "/" {
            components.path = ""
        }

        return components.url ?? apiBaseURL
    }

    // MARK: - Agent / Warmup

    static var envAgentAPIKey: String? {
        let candidates = [
            envValues["ccui_api_key"],
            envValues["CCUI_API_KEY"],
            envValues["agent_api_key"],
            envValues["api_key"],
            envValues["API_KEY"]
        ]

        return candidates.first { value in
            guard let value else { return false }
            return !value.isBlank
        } ?? nil
    }

    static func preferredAgentAPIKey(
        envValue: String?,
        keychainValue: String?
    ) -> String? {
        if let keychainValue, !keychainValue.isBlank {
            return keychainValue
        }

        if let envValue, !envValue.isBlank {
            return envValue
        }

        return nil
    }

    static var resolvedAgentAPIKey: String? {
        preferredAgentAPIKey(
            envValue: envAgentAPIKey,
            keychainValue: KeychainHelper.shared.read(key: .agentAPIKey)
        )
    }

    static var agentAPIKeySource: ConfigSource {
        if let keychainValue = KeychainHelper.shared.read(key: .agentAPIKey),
           !keychainValue.isBlank {
            return .appSettings
        }

        if envAgentAPIKey != nil {
            return .envFile
        }

        return .unavailable
    }

    static var defaultProjectPath: String? {
        if let appProjectPath = UserDefaultsStorage.shared.warmupProjectPathOverride,
           !appProjectPath.isBlank {
            return appProjectPath
        }

        let candidates = [
            envValues["project_path"],
            envValues["warmup_project_path"]
        ]

        return candidates.first { value in
            guard let value else { return false }
            return !value.isBlank
        } ?? nil
    }

    static var defaultProjectPathSource: ConfigSource {
        if let appProjectPath = UserDefaultsStorage.shared.warmupProjectPathOverride,
           !appProjectPath.isBlank {
            return .appSettings
        }

        if defaultProjectPath != nil {
            return .envFile
        }

        return .unavailable
    }

    // MARK: - Feature Flags

    static var disableAuthentication: Bool {
        if let override = boolEnvValue(for: [
            "disable_authentication",
            "preview_mode",
            "auth_bypass"
        ]) {
            return override
        }

        return environment == .development && !hasExplicitAPIBaseURL
    }
    static let enableAnalytics: Bool = environment == .production
    static let enableDebugMenu: Bool = environment == .development

    private static var appAPIBaseURLOverride: URL? {
        guard let override = UserDefaultsStorage.shared.apiBaseURLOverride else {
            return nil
        }

        return normalizedAPIBaseURL(from: override)
    }

    private static var envAPIBaseURL: URL? {
        guard let envURL = envValues["api_base_url"], !envURL.isEmpty else {
            return nil
        }

        return normalizedAPIBaseURL(from: envURL)
    }
}
