import XCTest
@testable import ClaudeCodeUI

@MainActor
final class SettingsViewModelTests: XCTestCase {

    private var testDefaults: UserDefaults!
    private var storage: UserDefaultsStorage!
    private let suiteName = "SettingsViewModelTests"

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: suiteName)
        testDefaults.removePersistentDomain(forName: suiteName)
        storage = UserDefaultsStorage(store: testDefaults)
        KeychainHelper.shared.delete(key: .agentAPIKey)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        KeychainHelper.shared.delete(key: .agentAPIKey)
        super.tearDown()
    }

    func testProviderPreferencesPersistAndReload() {
        let pref = ProviderPreference(isEnabled: false, warmupModel: "opus-4")
        storage.setPreference(pref, for: .claude)

        let loaded = storage.preference(for: .claude)
        XCTAssertEqual(loaded.isEnabled, false)
        XCTAssertEqual(loaded.warmupModel, "opus-4")
    }

    func testLoadProviderSettingsLoadsConnectionOverrides() {
        storage.apiBaseURLOverride = "https://app.override.test/api"
        KeychainHelper.shared.save("settings-key", key: .agentAPIKey)

        let viewModel = SettingsViewModel(storage: storage)
        viewModel.loadProviderSettings()

        XCTAssertEqual(viewModel.apiBaseURLOverrideText, "https://app.override.test/api")
        XCTAssertEqual(viewModel.agentAPIKeyText, "settings-key")
    }

    func testSaveAPIBaseURLOverrideNormalizesAndPersistsValue() {
        let viewModel = SettingsViewModel(storage: storage)
        viewModel.apiBaseURLOverrideText = "http://localhost:3000"

        let saved = viewModel.saveAPIBaseURLOverride()

        XCTAssertTrue(saved)
        XCTAssertEqual(storage.apiBaseURLOverride, "http://127.0.0.1:3000/api")
        XCTAssertEqual(viewModel.apiBaseURLOverrideText, "http://127.0.0.1:3000/api")
        XCTAssertNil(viewModel.errorBanner)
    }

    func testSaveAPIBaseURLOverrideRejectsInvalidValue() {
        let viewModel = SettingsViewModel(storage: storage)
        viewModel.apiBaseURLOverrideText = "not a url"

        let saved = viewModel.saveAPIBaseURLOverride()

        XCTAssertFalse(saved)
        XCTAssertNil(storage.apiBaseURLOverride)
        XCTAssertEqual(viewModel.errorBanner, "Enter a valid API base URL.")
    }

    func testClearingAPIBaseURLOverrideRemovesPersistedValue() {
        storage.apiBaseURLOverride = "https://app.override.test/api"

        let viewModel = SettingsViewModel(storage: storage)
        viewModel.loadProviderSettings()
        viewModel.clearAPIBaseURLOverride()

        XCTAssertEqual(viewModel.apiBaseURLOverrideText, "")
        XCTAssertNil(storage.apiBaseURLOverride)
    }

    func testSaveAgentAPIKeyStoresTrimmedValueInKeychain() {
        let viewModel = SettingsViewModel(storage: storage)
        viewModel.agentAPIKeyText = "  secret-key  "

        viewModel.saveAgentAPIKey()

        XCTAssertEqual(viewModel.agentAPIKeyText, "secret-key")
        XCTAssertEqual(KeychainHelper.shared.read(key: .agentAPIKey), "secret-key")
    }

    func testClearingAgentAPIKeyRemovesSavedOverride() {
        KeychainHelper.shared.save("secret-key", key: .agentAPIKey)

        let viewModel = SettingsViewModel(storage: storage)
        viewModel.loadProviderSettings()
        viewModel.clearAgentAPIKey()

        XCTAssertEqual(viewModel.agentAPIKeyText, "")
        XCTAssertNil(KeychainHelper.shared.read(key: .agentAPIKey))
    }

    func testLoadProviderSettingsLoadsWarmupProjectPathOverride() {
        storage.warmupProjectPathOverride = "/tmp/project"

        let viewModel = SettingsViewModel(storage: storage)
        viewModel.loadProviderSettings()

        XCTAssertEqual(viewModel.warmupProjectPathText, "/tmp/project")
    }

    func testSaveWarmupProjectPathStoresTrimmedValue() {
        let viewModel = SettingsViewModel(storage: storage)
        viewModel.warmupProjectPathText = "  /tmp/project  "

        viewModel.saveWarmupProjectPath()

        XCTAssertEqual(viewModel.warmupProjectPathText, "/tmp/project")
        XCTAssertEqual(storage.warmupProjectPathOverride, "/tmp/project")
    }

    func testClearWarmupProjectPathRemovesOverride() {
        storage.warmupProjectPathOverride = "/tmp/project"

        let viewModel = SettingsViewModel(storage: storage)
        viewModel.loadProviderSettings()
        viewModel.clearWarmupProjectPath()

        XCTAssertEqual(viewModel.warmupProjectPathText, "")
        XCTAssertNil(storage.warmupProjectPathOverride)
    }

    func testToggleProviderPersists() {
        let viewModel = SettingsViewModel(storage: storage)
        viewModel.loadProviderSettings()

        viewModel.toggleProvider(.gemini, isEnabled: false)

        XCTAssertEqual(viewModel.preferences[.gemini]?.isEnabled, false)
        XCTAssertEqual(storage.preference(for: .gemini).isEnabled, false)
    }

    func testUpdateWarmupModelPersists() {
        let viewModel = SettingsViewModel(storage: storage)
        viewModel.loadProviderSettings()

        viewModel.updateWarmupModel(.claude, model: "sonnet-4")

        XCTAssertEqual(viewModel.preferences[.claude]?.warmupModel, "sonnet-4")
        XCTAssertEqual(storage.preference(for: .claude).warmupModel, "sonnet-4")
    }
}
