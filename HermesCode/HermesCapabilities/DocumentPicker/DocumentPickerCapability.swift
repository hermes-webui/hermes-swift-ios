import Foundation
import UIKit
import UniformTypeIdentifiers

/// Presents `UIDocumentPickerViewController` so the user can pick a file from Files / iCloud Drive / etc.
/// No permission required — the user explicitly selects what they share.
///
/// Methods:
///   - `pick` — params: `{ types?: [String] (UTType identifiers, default ["public.item"]),
///                          allowMultiple?: Bool (default false),
///                          maxInlineBytes?: Int (default 1_048_576) }`
///     Returns array of `{ fileName, size, mimeType?, dataBase64? (if <= maxInlineBytes), tempPath }`.
public final class DocumentPickerCapability: NSObject, Capability, @unchecked Sendable, UIDocumentPickerDelegate {
    public let name = "documentPicker"

    private var continuation: CheckedContinuation<[AnyCodable], Error>?
    private var maxInlineBytes: Int = 1_048_576

    public override init() { super.init() }

    public func permissionStatus() async -> PermissionStatus { .granted }
    public func requestPermission() async -> PermissionStatus { .granted }

    public func invoke(method: String, params: CapabilityParams) async throws -> CapabilityResult {
        switch method {
        case "pick":
            let typeStrings = params["types"]?.arrayValue?.compactMap { $0.stringValue } ?? ["public.item"]
            let types = typeStrings.compactMap { UTType($0) }
            let allowMultiple = params["allowMultiple"]?.boolValue ?? false
            self.maxInlineBytes = params["maxInlineBytes"]?.intValue ?? 1_048_576

            let results = try await present(types: types.isEmpty ? [.item] : types, allowMultiple: allowMultiple)
            return .array(results)
        default:
            throw CapabilityError.unknownMethod(method)
        }
    }

    @MainActor
    private func present(types: [UTType], allowMultiple: Bool) async throws -> [AnyCodable] {
        guard let host = Self.topViewController() else {
            throw CapabilityError.underlying("no view controller available to present picker")
        }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = allowMultiple

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            host.present(picker, animated: true)
        }
    }

    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let results: [AnyCodable] = urls.map { url in
            let data = (try? Data(contentsOf: url)) ?? Data()
            let size = data.count
            var dict: [String: AnyCodable] = [
                "fileName": .string(url.lastPathComponent),
                "size":     .int(size),
                "tempPath": .string(url.path),
            ]
            if let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType {
                dict["mimeType"] = .string(mime)
            }
            if size <= maxInlineBytes {
                dict["dataBase64"] = .string(data.base64EncodedString())
            }
            return .object(dict)
        }
        continuation?.resume(returning: results)
        continuation = nil
    }

    public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        continuation?.resume(returning: [])
        continuation = nil
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let root = scenes.first?.keyWindow?.rootViewController else { return nil }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
