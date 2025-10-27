# Repository Guidelines

## Project Structure & Module Organization
All app code lives in `Wpayin_Wallet/`. `Core/Managers` exposes app services like `WalletManager` and `KeychainManager`, while `Core/API` and `Core/Theme` centralize networking stubs and shared styling. Domain models (`Blockchain`, `Token`, `Wallet`) sit in `Models/`, and feature views live under `Views/Wallet`, `Views/Swap`, `Views/Activity`, `Views/Settings`, and `Views/Welcome`. Shared SwiftUI components belong in `Views/Components`. Assets remain in `Assets.xcassets`. Tests are split between `Wpayin_WalletTests/` for unit coverage and `Wpayin_WalletUITests/` for automation.

## Build, Test, and Development Commands
Open the workspace with `xed .` or `open Wpayin_Wallet.xcodeproj`. Build locally using `xcodebuild -scheme Wpayin_Wallet -destination 'platform=iOS Simulator,name=iPhone 15' build`. Run unit tests with `xcodebuild test -scheme Wpayin_Wallet -destination 'platform=iOS Simulator,name=iPhone 15'`. Execute UI flows through `xcodebuild test -scheme Wpayin_WalletUITests -destination 'platform=iOS Simulator,name=iPhone 15'`. Use SwiftUI previews in Xcode for quick layout checks before launching full simulators.

## Coding Style & Naming Conventions
Follow Swift API Design Guidelines. Use four-space indentation, `PascalCase` for types, `camelCase` for members, and keep view structs lean. Group logic with `// MARK:` separators (see `WalletManager`). Name files after the primary type, e.g., `MainTabView.swift` or `WelcomeView.swift`. Extract reusable UI into `Views/Components` and prefer immutable `struct` models with state managed via `ObservableObject` classes.

## Testing Guidelines
Unit tests rely on the Swift `Testing` package with `@Test` functions and `#expect` assertions; mirror production module names (`WalletManagerTests`) and mark async flows with `async`. UI tests use XCTest inside `Wpayin_WalletUITests/`; organize helpers with `launch`/`assert` prefixes. Run both test targets before opening a PR and confirm simulator logs stay clean.

## Commit & Pull Request Guidelines
Write short, imperative commit subjects (e.g., `Add wallet refresh placeholder`). Keep related changes together and add bodies when touching security-sensitive code. PRs should describe the problem, summarize the solution, list impacted screens, and attach relevant screenshots or recordings. Link issue IDs and note that `xcodebuild test` passed locally.

## Security & Configuration Tips
Do not commit mnemonics, private keys, or API secrets. Store sensitive state in `KeychainManager` or `UserDefaults`, and rely on `WalletManager` mock hooks when demoing. Gate any real network configuration behind build flags or ignored secrets files.
