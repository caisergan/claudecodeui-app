import XCTest
@testable import ClaudeCodeUI

final class ModelsTests: XCTestCase {

    // MARK: - Message

    func testMessageDefaultsToNow() {
        let before = Date.now
        let msg = Message(role: .user, content: "Hello")
        let after = Date.now
        XCTAssertGreaterThanOrEqual(msg.timestamp, before)
        XCTAssertLessThanOrEqual(msg.timestamp, after)
    }

    func testMessageEquality() {
        let id = UUID().uuidString
        let a = Message(id: id, role: .user, content: "Hi")
        let b = Message(id: id, role: .user, content: "Hi")
        XCTAssertEqual(a, b)
    }

    // MARK: - Conversation

    func testConversationDefaultsToEmpty() {
        let c = Conversation()
        XCTAssertTrue(c.messages.isEmpty)
        XCTAssertEqual(c.title, "New Conversation")
    }

    // MARK: - String Extensions

    func testIsBlank() {
        XCTAssertTrue("   ".isBlank)
        XCTAssertTrue("".isBlank)
        XCTAssertFalse("hello".isBlank)
    }

    func testTruncated() {
        let s = "Hello, world!"
        XCTAssertEqual(s.truncated(to: 5), "Hello…")
        XCTAssertEqual(s.truncated(to: 100), s)
    }

    // MARK: - Collection Extensions

    func testSafeIndex() {
        let arr = [1, 2, 3]
        XCTAssertEqual(arr.safe(0), 1)
        XCTAssertNil(arr.safe(10))
    }
}
