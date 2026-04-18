# ClaudeCodeUI – iOS App

A native SwiftUI iOS app built with Swift 5.10, targeting **iOS 17+**.

## Project Structure

```
ClaudeCodeUI/
├── ClaudeCodeUI.xcodeproj/        # Standard Xcode iOS app project
├── Package.swift                  # Swift Package Manager manifest
├── Resources/                     # App assets (images, fonts, localizations)
├── Sources/
│   ├── App/
│   │   ├── ClaudeCodeUIApp.swift  # @main entry point
│   │   ├── ContentView.swift      # Root TabView
│   │   └── AppState.swift         # Global @EnvironmentObject
│   ├── Core/
│   │   ├── Network/
│   │   │   └── APIClient.swift    # Async/await REST client + Endpoint model
│   │   ├── Storage/
│   │   │   └── KeychainHelper.swift
│   │   ├── Extensions/
│   │   │   └── Extensions.swift   # String, Date, Collection helpers
│   │   └── Utilities/
│   │       └── AppConfig.swift    # Environment-based config & feature flags
│   ├── Features/
│   │   ├── Home/
│   │   │   ├── HomeView.swift
│   │   │   ├── HomeViewModel.swift
│   │   │   └── ConversationRowView.swift
│   │   ├── Chat/
│   │   │   ├── ChatView.swift
│   │   │   ├── ChatViewModel.swift
│   │   │   ├── MessageBubbleView.swift
│   │   │   └── MessageInputView.swift
│   │   └── Settings/
│   │       ├── SettingsView.swift
│   │       └── SettingsViewModel.swift
│   └── Shared/
│       ├── Models/
│       │   └── Models.swift       # User, Message, Conversation, APIError
│       └── Components/
│           └── SharedComponents.swift  # LoadingButton, EmptyStateView, AsyncAvatarView
└── Tests/
    └── UnitTests/
        └── ModelsTests.swift
```

## Requirements

| Tool | Version |
|------|---------|
| Xcode | 15+ |
| Swift | 5.10+ |
| iOS | 17+ |

## Getting Started

1. **Open in Xcode**
   ```bash
   open ClaudeCodeUI.xcodeproj
   ```

2. **Select a simulator** (iPhone 15 or later recommended).

3. **Run** with ⌘R.

4. **Optional CLI build**
   ```bash
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
   xcodebuild -project ClaudeCodeUI.xcodeproj \
     -scheme ClaudeCodeUI \
     -destination 'generic/platform=iOS Simulator' build
   ```

5. **Optional Makefile shortcuts**
   ```bash
   make open
   make build
   make test
   ```

If `xcodebuild` says the active developer directory is Command Line Tools, point CLI builds at full Xcode:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

The legacy SwiftPM entry points are still available as `make open-package`, `make build-package`, and `make test-package`, but the standard iOS app workflow now goes through `ClaudeCodeUI.xcodeproj`.

## Architecture

The project follows **MVVM** with a clean layer separation:

- **App** — entry point and global state
- **Core** — framework-level concerns (networking, storage, config)
- **Features** — self-contained screen modules (`View` + `ViewModel`)
- **Shared** — cross-feature models and UI components

## Key Patterns

- `async/await` throughout — no Combine in networking layer
- `@MainActor` on all ViewModels
- Keychain for sensitive data (tokens), `@AppStorage` for preferences
- `APIClient` is injectable for testing (pass a custom `URLSession`)
