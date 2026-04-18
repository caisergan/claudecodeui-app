# ClaudeCodeUI – iOS App

A native SwiftUI iOS app built with Swift 5.10, targeting **iOS 17+**.

## Project Structure

```
ClaudeCodeUI/
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
   open Package.swift
   # or open the .xcodeproj once generated
   ```

2. **Select a simulator** (iPhone 15 or later recommended).

3. **Run** with ⌘R.

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
