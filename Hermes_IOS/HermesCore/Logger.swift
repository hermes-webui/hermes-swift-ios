import Foundation
import os

/// Centralized loggers for each subsystem. Use os.Logger for performance and Console.app discoverability.
public enum Loggers {
    public static let subsystem = "app.webui.client.ios"

    public static let app          = Logger(subsystem: subsystem, category: "app")
    public static let webView      = Logger(subsystem: subsystem, category: "webview")
    public static let bridge       = Logger(subsystem: subsystem, category: "bridge")
    public static let transport    = Logger(subsystem: subsystem, category: "bridge.transport")
    public static let pairing      = Logger(subsystem: subsystem, category: "bridge.pairing")
    public static let capabilities = Logger(subsystem: subsystem, category: "capabilities")
}
