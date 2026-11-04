import Foundation
import OSLog

enum AppLog {
    private static let subsystem = "com.melly.miniphone"

    static let network = Logger(subsystem: subsystem, category: "network")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let storage = Logger(subsystem: subsystem, category: "storage")
}
