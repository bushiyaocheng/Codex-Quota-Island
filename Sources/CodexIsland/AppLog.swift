import Foundation
import OSLog

enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "dev.codexisland.app"

    static let appServer = Logger(subsystem: subsystem, category: "AppServer")
    static let usage = Logger(subsystem: subsystem, category: "Usage")
    static let windowing = Logger(subsystem: subsystem, category: "Windowing")
    static let launchAtLogin = Logger(subsystem: subsystem, category: "LaunchAtLogin")
}
