import OSLog

// MARK: - App Logger
//
// Wraps Apple's unified logging (os.Logger) with typed subsystem/category.
// Usage:
//   AppLogger.network.info("Request started: \(url)")
//   AppLogger.ui.error("Failed to load view: \(error)")

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.claudecodeui"

    static let general  = Logger(subsystem: subsystem, category: "General")
    static let network  = Logger(subsystem: subsystem, category: "Network")
    static let storage  = Logger(subsystem: subsystem, category: "Storage")
    static let ui       = Logger(subsystem: subsystem, category: "UI")
    static let auth     = Logger(subsystem: subsystem, category: "Auth")
}
