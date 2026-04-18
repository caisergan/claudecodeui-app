.PHONY: build test clean lint format open open-package build-ios test-ios build-package test-package

# ── Open in Xcode ─────────────────────────────────────────────────────────────
open:
	open ClaudeCodeUI.xcodeproj

open-package:
	open Package.swift

# ── Build (Xcode / iOS Simulator) ────────────────────────────────────────────
build:
	DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ClaudeCodeUI.xcodeproj -scheme ClaudeCodeUI -destination 'generic/platform=iOS Simulator' build

build-ios:
	DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ClaudeCodeUI.xcodeproj -scheme ClaudeCodeUI -destination 'generic/platform=iOS Simulator' build

build-package:
	swift build

# ── Test ──────────────────────────────────────────────────────────────────────
test:
	DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project ClaudeCodeUI.xcodeproj -scheme ClaudeCodeUI -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

test-ios:
	DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project ClaudeCodeUI.xcodeproj -scheme ClaudeCodeUI -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

test-package:
	swift test --parallel

# ── Clean build artefacts ─────────────────────────────────────────────────────
clean:
	swift package clean
	rm -rf .build

# ── Lint (requires SwiftLint: brew install swiftlint) ─────────────────────────
lint:
	swiftlint lint --strict

# ── Auto-format (requires swift-format: brew install swift-format) ────────────
format:
	swift-format format --recursive --in-place Sources Tests

# ── Resolve dependencies ──────────────────────────────────────────────────────
resolve:
	swift package resolve

# ── Update dependencies ───────────────────────────────────────────────────────
update:
	swift package update
