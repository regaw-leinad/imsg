import Commander
import Foundation
import Testing

@testable import IMsgCore
@testable import imsg

@Test
func chatsCommandRunsWithJsonOutput() async throws {
  let path = try CommandTestDatabase.makePath()
  let values = ParsedValues(
    positional: [],
    options: ["db": [path], "limit": ["5"]],
    flags: ["jsonOutput"]
  )
  let runtime = RuntimeOptions(parsedValues: values)
  _ = try await StdoutCapture.capture {
    try await ChatsCommand.spec.run(values, runtime)
  }
}

@Test
func historyCommandRunsWithChatID() async throws {
  let path = try CommandTestDatabase.makePath()
  let values = ParsedValues(
    positional: [],
    options: ["db": [path], "chatID": ["1"], "limit": ["5"]],
    flags: ["jsonOutput"]
  )
  let runtime = RuntimeOptions(parsedValues: values)
  _ = try await StdoutCapture.capture {
    try await HistoryCommand.spec.run(values, runtime)
  }
}

@Test
func historyCommandRunsWithAttachmentsNonJson() async throws {
  let path = try CommandTestDatabase.makePathWithAttachment()
  let values = ParsedValues(
    positional: [],
    options: ["db": [path], "chatID": ["1"], "limit": ["5"]],
    flags: ["attachments"]
  )
  let runtime = RuntimeOptions(parsedValues: values)
  _ = try await StdoutCapture.capture {
    try await HistoryCommand.spec.run(values, runtime)
  }
}

@Test
func chatsCommandRunsWithPlainOutput() async throws {
  let path = try CommandTestDatabase.makePath()
  let values = ParsedValues(
    positional: [],
    options: ["db": [path], "limit": ["5"]],
    flags: []
  )
  let runtime = RuntimeOptions(parsedValues: values)
  _ = try await StdoutCapture.capture {
    try await ChatsCommand.spec.run(values, runtime)
  }
}

