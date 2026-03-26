import Foundation

@testable import IMsgCore

final class MockContactResolver: ContactResolving, @unchecked Sendable {
  var contactsUnavailable: Bool
  private let names: [String: String]

  init(names: [String: String] = [:], contactsUnavailable: Bool = false) {
    self.names = names
    self.contactsUnavailable = contactsUnavailable
  }

  func resolve(_ identifier: String) -> String? {
    names[identifier]
  }

  func resolve(_ identifiers: [String]) -> [String: String] {
    var results: [String: String] = [:]
    for id in identifiers {
      if let name = names[id] {
        results[id] = name
      }
    }
    return results
  }

  func displayNameForChat(identifier: String, name: String, participants: [String]) -> String {
    if identifier.hasPrefix("+") || identifier.contains("@") {
      return resolve(identifier) ?? identifier
    }
    guard name.isEmpty else { return name }
    guard !participants.isEmpty else { return identifier }
    let resolved = resolve(participants)
    return participants.map { resolved[$0] ?? $0 }.joined(separator: ", ")
  }
}
