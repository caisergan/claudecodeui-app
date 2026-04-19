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
        let timestamp = Date.now
        let a = Message(id: id, role: .user, content: "Hi", timestamp: timestamp)
        let b = Message(id: id, role: .user, content: "Hi", timestamp: timestamp)
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

    // MARK: - Provider Models

    func testSupportedWarmupModelsAreHardcodedPerProvider() {
        XCTAssertEqual(AIProvider.codex.supportedWarmupModels, [
            "gpt-5.4",
            "gpt-5.4-mini",
            "gpt-5.3-codex",
            "gpt-5.2-codex",
            "gpt-5.2",
            "gpt-5.1-codex-max",
            "o3",
            "o4-mini"
        ])

        XCTAssertEqual(AIProvider.claude.supportedWarmupModels, [
            "sonnet",
            "opus",
            "haiku",
            "opusplan",
            "sonnet[1m]",
            "opus[1m]"
        ])

        XCTAssertEqual(AIProvider.gemini.supportedWarmupModels, [
            "gemini-3.1-pro-preview",
            "gemini-3-pro-preview",
            "gemini-3-flash-preview",
            "gemini-2.5-flash",
            "gemini-2.5-pro",
            "gemini-2.0-flash-lite",
            "gemini-2.0-flash",
            "gemini-2.0-pro-experimental",
            "gemini-2.0-flash-thinking"
        ])

        XCTAssertTrue(AIProvider.cursor.supportedWarmupModels.isEmpty)
    }

    func testWarmupModelMenuOptionsPreserveSavedCustomSelection() {
        let options = AIProvider.claude.warmupModelMenuOptions(including: "sonnet-4")

        XCTAssertEqual(options.first, "sonnet-4")
        XCTAssertEqual(options.dropFirst().first, "sonnet")
    }

    func testWarmupModelMenuOptionsDoNotDuplicateKnownSelection() {
        let options = AIProvider.codex.warmupModelMenuOptions(including: "gpt-5.4")

        XCTAssertEqual(options.first, "gpt-5.4")
        XCTAssertEqual(options.filter { $0 == "gpt-5.4" }.count, 1)
    }
}
