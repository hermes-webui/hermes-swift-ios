import Foundation
import Contacts

public final class ContactsCapability: Capability, @unchecked Sendable {
    public let name = "contacts"

    private let store = CNContactStore()

    public init() {}

    public func permissionStatus() async -> PermissionStatus {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined: return .notDetermined
        case .denied:        return .denied
        case .restricted:    return .restricted
        case .authorized, .limited: return .granted
        @unknown default:    return .notDetermined
        }
    }

    public func requestPermission() async -> PermissionStatus {
        do {
            let granted = try await store.requestAccess(for: .contacts)
            return granted ? .granted : .denied
        } catch {
            return .denied
        }
    }

    public func invoke(method: String, params: CapabilityParams) async throws -> CapabilityResult {
        guard await permissionStatus() == .granted else {
            if await requestPermission() != .granted { throw CapabilityError.permissionDenied }
        }
        switch method {
        case "search":
            guard let query = params["query"]?.stringValue, !query.isEmpty else {
                throw CapabilityError.missingParam("query")
            }
            let predicate = CNContact.predicateForContacts(matchingName: query)
            let keys: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
            ]
            let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keys)
            let serialized = contacts.map { c -> AnyCodable in
                .object([
                    "identifier": .string(c.identifier),
                    "givenName":  .string(c.givenName),
                    "familyName": .string(c.familyName),
                    "phones":     .array(c.phoneNumbers.map { .string($0.value.stringValue) }),
                    "emails":     .array(c.emailAddresses.map { .string($0.value as String) }),
                ])
            }
            return .array(serialized)
        default:
            throw CapabilityError.unknownMethod(method)
        }
    }
}
