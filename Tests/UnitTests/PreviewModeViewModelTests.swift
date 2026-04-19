import XCTest
@testable import ClaudeCodeUI

@MainActor
final class PreviewModeViewModelTests: XCTestCase {

    func testHomeLoadsPreviewConversationsWhenAuthBypassIsEnabled() async throws {
        guard AppConfig.disableAuthentication else {
            throw XCTSkip("Preview-mode assertions only apply when auth bypass is enabled.")
        }

        let viewModel = HomeViewModel()

        await viewModel.loadConversations()

        XCTAssertFalse(viewModel.conversations.isEmpty)
        XCTAssertFalse(viewModel.showError)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testChatUsesLocalPreviewReplyWhenAuthBypassIsEnabled() async throws {
        guard AppConfig.disableAuthentication else {
            throw XCTSkip("Preview-mode assertions only apply when auth bypass is enabled.")
        }

        let viewModel = ChatViewModel()
        viewModel.inputText = "Hello preview"

        await viewModel.sendMessage()

        XCTAssertEqual(viewModel.messages.count, 2)
        XCTAssertEqual(viewModel.messages.first?.role, .user)
        XCTAssertEqual(viewModel.messages.first?.content, "Hello preview")
        XCTAssertEqual(viewModel.messages.last?.role, .assistant)
        XCTAssertTrue(viewModel.messages.last?.content.contains("Preview mode is active") == true)
    }
}
