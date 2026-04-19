import XCTest
@testable import ClaudeCodeUI

@MainActor
final class SettingsViewModelTests: XCTestCase {

    private var storage: UserDefaultsStorage!
    private let testDefaults = UserDefaults(suiteName: "SettingsViewModelTests")!

    override func setUp() {
        super.setUp()
        testDefaults.removePersistentDomain(forName: "SettingsViewModelTests")
        storage = .shared
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: "SettingsViewModelTests")
        super.tearDown()
    }

    // MARK: - Provider preferences persist

    func testProviderPreferencesPersistAndReload() {
        let pref = ProviderPreference(isEnabled: false, warmupModel: "opus-4")
        storage.setPreference(pref, for: .claude)

        let loaded = storage.preference(for: .claude)
        XCTAssertEqual(loaded.isEnabled, false)
        XCTAssertEqual(loaded.warmupModel, "opus-4")
    }

    func testDefaultPreferenceIsEnabledWithEmptyModel() {
        let pref = storage.preference(for: .gemini)
        XCTAssertTrue(pref.isEnabled)
        XCTAssertEqual(pref.warmupModel, "")
    }

    // MARK: - Disabled providers filtered

    func testDisabledProvidersExcludedFromEnabledList() {
        let vm = SettingsViewModel()
        vm.loadProviderSettings()

        // All enabled by default
        XCTAssertEqual(vm.enabledProviders.count, AIProvider.allCases.count)

        // Disable one
        vm.toggleProvider(.codex, isEnabled: false)
        XCTAssertFalse(vm.enabledProviders.contains(.codex))
        XCTAssertEqual(vm.enabledProviders.count, AIProvider.allCases.count - 1)
    }

    // MARK: - Warmup session ID storage

    func testFirstWarmupSessionIdIsStored() {
        XCTAssertNil(storage.warmupSessionId(for: .claude))

        storage.setWarmupSessionId("sess-abc", for: .claude)
        XCTAssertEqual(storage.warmupSessionId(for: .claude), "sess-abc")
    }

    func testSessionIdPerProviderIsolation() {
        storage.setWarmupSessionId("sess-claude", for: .claude)
        storage.setWarmupSessionId("sess-cursor", for: .cursor)

        XCTAssertEqual(storage.warmupSessionId(for: .claude), "sess-claude")
        XCTAssertEqual(storage.warmupSessionId(for: .cursor), "sess-cursor")
        XCTAssertNil(storage.warmupSessionId(for: .codex))
    }

    // MARK: - Warmup request payload

    func testWarmupPayloadIncludesProviderAndModel() {
        let payload = WarmupRequestPayload(
            provider: .cursor,
            model: "gpt-4",
            sessionId: "sess-1",
            projectPath: "/test"
        )
        XCTAssertEqual(payload.message, "ping")
        XCTAssertEqual(payload.provider, "cursor")
        XCTAssertEqual(payload.model, "gpt-4")
        XCTAssertEqual(payload.sessionId, "sess-1")
        XCTAssertEqual(payload.stream, false)
    }

    func testWarmupPayloadOmitsModelWhenNil() {
        let payload = WarmupRequestPayload(provider: .claude)
        XCTAssertNil(payload.model)
        XCTAssertNil(payload.sessionId)
    }

    // MARK: - Warmup state transitions

    func testWarmupStateStartsIdle() {
        let vm = SettingsViewModel()
        vm.loadProviderSettings()

        for provider in AIProvider.allCases {
            XCTAssertEqual(vm.warmupStates[provider], .idle)
        }
    }

    func testToggleProviderPersists() {
        let vm = SettingsViewModel()
        vm.loadProviderSettings()

        vm.toggleProvider(.gemini, isEnabled: false)
        XCTAssertEqual(vm.preferences[.gemini]?.isEnabled, false)

        // Verify persistence
        let persisted = storage.preference(for: .gemini)
        XCTAssertEqual(persisted.isEnabled, false)
    }

    func testUpdateWarmupModelPersists() {
        let vm = SettingsViewModel()
        vm.loadProviderSettings()

        vm.updateWarmupModel(.claude, model: "sonnet-4")
        XCTAssertEqual(vm.preferences[.claude]?.warmupModel, "sonnet-4")

        let persisted = storage.preference(for: .claude)
        XCTAssertEqual(persisted.warmupModel, "sonnet-4")
    }

    // MARK: - Timer cancellation

    func testCancelAllResetTimersDoesNotCrash() {
        let vm = SettingsViewModel()
        vm.loadProviderSettings()
        // Should be safe to call even with no active timers
        vm.cancelAllResetTimers()
    }
}
