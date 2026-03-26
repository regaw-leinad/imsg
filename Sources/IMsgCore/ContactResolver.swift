@preconcurrency import Contacts
import Foundation

/// Protocol for resolving phone numbers and email addresses to contact display names.
public protocol ContactResolving: Sendable {
  /// Whether contacts access is unavailable (denied, restricted, or not yet granted).
  var contactsUnavailable: Bool { get }

  /// Resolve a single identifier (phone number or email) to a display name.
  func resolve(_ identifier: String) -> String?

  /// Batch resolve multiple identifiers. Returns a dictionary mapping
  /// identifiers to display names (only includes resolved entries).
  func resolve(_ identifiers: [String]) -> [String: String]

  /// Resolve the best display name for a chat given its identifier, DB name, and participants.
  func displayNameForChat(identifier: String, name: String, participants: [String]) -> String
}

/// Resolves phone numbers and email addresses to contact display names
/// via CNContactStore. Results are cached for the lifetime of the instance.
/// If Contacts access is denied, all lookups silently return nil.
public final class ContactResolver: ContactResolving, @unchecked Sendable {
  private let store: CNContactStore
  private var cache: [String: String?] = [:]
  private var denied: Bool = false
  private let queue = DispatchQueue(label: "imsg.contacts", qos: .userInitiated)

  private static let keysToFetch: [CNKeyDescriptor] = [
    CNContactGivenNameKey as CNKeyDescriptor,
    CNContactFamilyNameKey as CNKeyDescriptor,
    CNContactNicknameKey as CNKeyDescriptor,
    CNContactPhoneNumbersKey as CNKeyDescriptor,
    CNContactEmailAddressesKey as CNKeyDescriptor,
  ]

  public private(set) var contactsUnavailable: Bool

  public init() {
    self.store = CNContactStore()
    let status = CNContactStore.authorizationStatus(for: .contacts)
    switch status {
    case .authorized:
      self.contactsUnavailable = false
    case .notDetermined:
      // Trigger the system permission prompt in the background.
      // This run won't resolve names, but once the user responds,
      // subsequent runs will work.
      self.denied = true
      self.contactsUnavailable = true
      store.requestAccess(for: .contacts) { _, _ in }
    default:
      self.denied = true
      self.contactsUnavailable = true
    }
  }

  /// Resolve a single identifier (phone number or email) to a display name.
  /// Returns nil if no matching contact is found or access is denied.
  public func resolve(_ identifier: String) -> String? {
    queue.sync {
      if denied { return nil }
      if let existing = cache[identifier] { return existing }
      let result = lookup(identifier)
      cache[identifier] = result
      return result
    }
  }

  /// Batch resolve multiple identifiers. Returns a dictionary mapping
  /// identifiers to display names (only includes resolved entries).
  public func resolve(_ identifiers: [String]) -> [String: String] {
    var results: [String: String] = [:]
    for identifier in identifiers {
      if let name = resolve(identifier) {
        results[identifier] = name
      }
    }
    return results
  }

  private func lookup(_ identifier: String) -> String? {
    let trimmed = identifier.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }

    do {
      let predicate: NSPredicate
      if trimmed.contains("@") {
        predicate = CNContact.predicateForContacts(matchingEmailAddress: trimmed)
      } else if trimmed.hasPrefix("+") || trimmed.first?.isNumber == true {
        let phoneNumber = CNPhoneNumber(stringValue: trimmed)
        predicate = CNContact.predicateForContacts(matching: phoneNumber)
      } else {
        return nil
      }

      let contacts = try store.unifiedContacts(
        matching: predicate,
        keysToFetch: Self.keysToFetch
      )
      guard let contact = contacts.first else { return nil }
      return ContactResolver.displayName(for: contact)
    } catch let error as NSError
      where error.domain == CNErrorDomain
      && error.code == CNError.authorizationDenied.rawValue
    {
      denied = true
      return nil
    } catch {
      return nil
    }
  }

  /// Resolve the best display name for a chat given its identifier, DB name, and participants.
  /// Checks phone/email identifiers first (since the DB name can be a raw phone fallback),
  /// then falls back to the DB name, then resolves group participants, then the raw identifier.
  public func displayNameForChat(
    identifier: String, name: String, participants: [String]
  ) -> String {
    if identifier.hasPrefix("+") || identifier.contains("@") {
      return resolve(identifier) ?? identifier
    }
    guard name.isEmpty else { return name }
    guard !participants.isEmpty else { return identifier }
    let resolved = resolve(participants)
    return participants.map { resolved[$0] ?? $0 }.joined(separator: ", ")
  }

  private static func displayName(for contact: CNContact) -> String? {
    if !contact.nickname.isEmpty {
      return contact.nickname
    }
    let parts = [contact.givenName, contact.familyName].filter { !$0.isEmpty }
    guard !parts.isEmpty else { return nil }
    return parts.joined(separator: " ")
  }
}
