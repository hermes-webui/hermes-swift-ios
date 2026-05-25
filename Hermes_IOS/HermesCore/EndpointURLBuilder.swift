import Foundation

enum EndpointURLBuilder {
    static func makeURL(from input: String, defaultPort: Int = 8787) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.contains("://") {
            guard let url = URL(string: trimmed),
                  let scheme = url.scheme?.lowercased(),
                  ["http", "https"].contains(scheme) else { return nil }
            return url
        }

        var components = URLComponents()
        components.scheme = "http"

        // Support IPv6 literals in manual input.
        let bareHost = trimmed.hasPrefix("[") && trimmed.hasSuffix("]")
            ? String(trimmed.dropFirst().dropLast())
            : trimmed

        if let colon = bareHost.lastIndex(of: ":"),
           bareHost[bareHost.index(after: colon)...].allSatisfy(\.isNumber),
           !bareHost.contains("]") {
            let hostPart = String(bareHost[..<colon])
            let portPart = String(bareHost[bareHost.index(after: colon)...])
            components.host = hostPart
            components.port = Int(portPart)
        } else {
            components.host = bareHost
            components.port = defaultPort
        }

        guard let url = components.url else { return nil }
        return url
    }
}
