.PHONY: build test clean lint format open

# ── Open in Xcode ─────────────────────────────────────────────────────────────
open:
	open Package.swift

# ── Build (SPM) ───────────────────────────────────────────────────────────────
build:
	swift build

# ── Test ──────────────────────────────────────────────────────────────────────
test:
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
