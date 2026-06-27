import Foundation
import SQLite
import Testing

@testable import IMsgCore

@Test
func messagesUseDestinationCallerIDWhenSenderMissing() throws {
  let db = try Connection(.inMemory)
  try db.execute(
    """
    CREATE TABLE message (
      ROWID INTEGER PRIMARY KEY,
      handle_id INTEGER,
      text TEXT,
      destination_caller_id TEXT,
      date INTEGER,
      is_from_me INTEGER,
      service TEXT
    );
    """
  )
  try db.execute(
    """
    CREATE TABLE chat (
      ROWID INTEGER PRIMARY KEY,
      chat_identifier TEXT,
      guid TEXT,
      display_name TEXT,
      service_name TEXT
    );
    """
  )
  try db.execute("CREATE TABLE handle (ROWID INTEGER PRIMARY KEY, id TEXT);")
  try db.execute("CREATE TABLE chat_message_join (chat_id INTEGER, message_id INTEGER);")
  try db.execute(
    """
    CREATE TABLE message_attachment_join (
      message_id INTEGER,
      attachment_id INTEGER
    );
    """
  )

  try db.run(
    """
    INSERT INTO chat(ROWID, chat_identifier, guid, display_name, service_name)
    VALUES (1, '+123', 'iMessage;+;chat123', 'Test Chat', 'iMessage')
    """
  )
  try db.run(
    """
    INSERT INTO message(ROWID, handle_id, text, destination_caller_id, date, is_from_me, service)
    VALUES (1, NULL, 'hello', 'me@icloud.com', ?, 1, 'iMessage')
    """,
    Int64(Date().timeIntervalSince1970 - MessageStore.appleEpochOffset) * 1_000_000_000
  )
  try db.run("INSERT INTO chat_message_join(chat_id, message_id) VALUES (1, 1)")

  let store = try MessageStore(connection: db, path: ":memory:")
  let messages = try store.messages(chatID: 1, limit: 5)
  #expect(messages.first?.sender == "me@icloud.com")
  #expect(messages.first?.destinationCallerID == "me@icloud.com")
}

@Test
func outgoingMessagesUseDestinationCallerIDInsteadOfRecipientHandle() throws {
  let db = try Connection(.inMemory)
  try db.execute(
    """
    CREATE TABLE message (
      ROWID INTEGER PRIMARY KEY,
      handle_id INTEGER,
      text TEXT,
      destination_caller_id TEXT,
      date INTEGER,
      is_from_me INTEGER,
      service TEXT
    );
    """
  )
  try db.execute(
    """
    CREATE TABLE chat (
      ROWID INTEGER PRIMARY KEY,
      chat_identifier TEXT,
      guid TEXT,
      display_name TEXT,
      service_name TEXT
    );
    """
  )
  try db.execute("CREATE TABLE handle (ROWID INTEGER PRIMARY KEY, id TEXT);")
  try db.execute("CREATE TABLE chat_message_join (chat_id INTEGER, message_id INTEGER);")
  try db.execute(
    """
    CREATE TABLE message_attachment_join (
      message_id INTEGER,
      attachment_id INTEGER
    );
    """
  )

  try db.run(
    """
    INSERT INTO chat(ROWID, chat_identifier, guid, display_name, service_name)
    VALUES (1, '+15550000002', 'iMessage;+;chat200', 'Test Chat', 'iMessage')
    """
  )
  // The joined handle is the recipient; an outgoing message must still report the
  // local account from destination_caller_id, not the recipient's number.
  try db.run("INSERT INTO handle(ROWID, id) VALUES (2, '+15550000002')")
  try db.run(
    """
    INSERT INTO message(ROWID, handle_id, text, destination_caller_id, date, is_from_me, service)
    VALUES (1, 2, 'hello', '+15550000001', ?, 1, 'iMessage')
    """,
    Int64(Date().timeIntervalSince1970 - MessageStore.appleEpochOffset) * 1_000_000_000
  )
  try db.run("INSERT INTO chat_message_join(chat_id, message_id) VALUES (1, 1)")

  let store = try MessageStore(connection: db, path: ":memory:")
  let messages = try store.messages(chatID: 1, limit: 5)
  #expect(messages.first?.sender == "+15550000001")
}
