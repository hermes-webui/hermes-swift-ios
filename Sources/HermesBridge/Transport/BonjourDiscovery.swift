import Foundation
import Network
import HermesCore

/// Discovers Mac BridgeServer instances advertising `_hermes._tcp` on the local network.
/// Requires `NSBonjourServices` and `NSLocalNetworkUsageDescription` in Info.plist (set in project.yml).
public final class BonjourDiscovery {
    public struct DiscoveredService: Hashable, Sendable {
        public let name: String        // user-visible Mac name from TXT or service name
        public let endpoint: NWEndpoint
        public let txtRecord: [String: String]
    }

    private var browser: NWBrowser?
    private var continuation: AsyncStream<[DiscoveredService]>.Continuation?
    private var current: [NWBrowser.Result: DiscoveredService] = [:]

    public init() {}

    public func start() -> AsyncStream<[DiscoveredService]> {
        AsyncStream { continuation in
            self.continuation = continuation
            let params = NWParameters()
            params.includePeerToPeer = false
            let browser = NWBrowser(for: .bonjourWithTXTRecord(type: "_hermes._tcp", domain: nil), using: params)

            browser.browseResultsChangedHandler = { [weak self] results, _ in
                guard let self else { return }
                self.current.removeAll()
                for r in results {
                    var txt: [String: String] = [:]
                    if case let .bonjour(record) = r.metadata {
                        for key in record.keys {
                            if let v = record.getEntry(for: key)?.description {
                                txt[key] = v
                            }
                        }
                    }
                    let displayName: String = {
                        if case let .service(name, _, _, _) = r.endpoint { return name }
                        return "Unknown Mac"
                    }()
                    self.current[r] = DiscoveredService(name: displayName, endpoint: r.endpoint, txtRecord: txt)
                }
                continuation.yield(Array(self.current.values))
            }

            browser.stateUpdateHandler = { state in
                Loggers.transport.info("Bonjour browser state: \(String(describing: state), privacy: .public)")
                if case .failed(let err) = state {
                    Loggers.transport.error("Bonjour browser failed: \(err.localizedDescription, privacy: .public)")
                    continuation.finish()
                }
            }

            browser.start(queue: .global(qos: .utility))
            self.browser = browser

            continuation.onTermination = { @Sendable _ in
                browser.cancel()
            }
        }
    }

    public func stop() {
        browser?.cancel()
        continuation?.finish()
        browser = nil
        continuation = nil
        current.removeAll()
    }
}

extension NWTXTRecord {
    fileprivate var keys: [String] {
        // NWTXTRecord doesn't expose keys directly; iterate dictionary form.
        return Array(self.dictionary.keys)
    }
}
