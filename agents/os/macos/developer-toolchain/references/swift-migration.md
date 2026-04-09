# Swift Migration Reference

## Swift Release Series

### Swift 5.9 (Xcode 15, Sonoma)

**Major Features:**
- **Swift Macros** -- Compile-time code generation via `@attached` and `@freestanding` macros
- **SwiftData** -- Declarative persistent data framework (CoreData successor)
- **Observation framework** -- `@Observable` macro replaces `ObservableObject`/`@Published` pattern
- **Variadic generics** -- Parameter packs for generic functions with variable argument counts

**Impact on Migration:**
- Macros are additive; no breaking changes from Swift 5.8
- SwiftData is opt-in; CoreData code continues to work
- `@Observable` is opt-in; `ObservableObject` is not deprecated
- Variadic generics enable new API patterns but do not break existing code

---

### Swift 6.0 (Xcode 16, Sequoia)

**Major Features:**
- **Strict concurrency model** -- Data race safety enforced at compile time
- **Complete actor isolation by default** -- All types are checked for Sendable conformance
- **`Sendable` enforcement** across module boundaries
- **Typed throws** -- `throws(ErrorType)` declarations for precise error types

**Migration Path:**

Swift 6.0 strict concurrency is the most significant migration effort in Swift history. The compiler enforces data race safety, flagging shared mutable state as errors.

#### Step 1: Enable Warnings First

```
// In Xcode build settings or Package.swift
SWIFT_STRICT_CONCURRENCY = targeted  // Start with targeted (warnings only)
```

Three levels:
| Level | Behavior |
|---|---|
| `minimal` | Only explicit `Sendable` annotations checked |
| `targeted` | Warns about common concurrency issues (recommended start) |
| `complete` | Full enforcement -- equivalent to Swift 6 mode |

#### Step 2: Fix Sendable Conformances

Common patterns:

```swift
// Before: Shared mutable state
class AppState {
    var counter = 0  // ERROR: not Sendable
}

// After: Actor isolation
actor AppState {
    var counter = 0  // Safe: actor-isolated
}

// Or: Sendable value type
struct AppState: Sendable {
    let counter: Int  // Immutable value type is Sendable
}
```

#### Step 3: Address @MainActor Requirements

UI-related code must be explicitly `@MainActor`:

```swift
@MainActor
class ViewModel: ObservableObject {
    @Published var items: [Item] = []

    func loadItems() async {
        let data = await fetchFromNetwork()
        items = data  // Safe: @MainActor isolated
    }
}
```

#### Step 4: Handle Closures and Callbacks

Closures crossing isolation boundaries must capture only `Sendable` values:

```swift
// Before: captures non-Sendable reference
task {
    viewModel.update(data)  // ERROR: viewModel not Sendable
}

// After: explicit MainActor context
Task { @MainActor in
    viewModel.update(data)  // Safe: runs on MainActor
}
```

#### Step 5: Enable Complete Enforcement

```
SWIFT_STRICT_CONCURRENCY = complete
```

Once all warnings are resolved at `targeted` level, move to `complete` and fix remaining issues. This is equivalent to Swift 6 language mode.

#### Common Sendable Patterns

| Situation | Solution |
|---|---|
| Shared mutable class | Convert to `actor` |
| Immutable shared data | Make `struct` or mark `Sendable` |
| Callback-based API | Wrap with `withCheckedContinuation` |
| Protocol without Sendable | Add `: Sendable` constraint |
| Global variable | Mark `@MainActor` or use actor |
| NSObject subclass | Mark `@unchecked Sendable` (audit for thread safety) |

#### Typed Throws

Swift 6.0 adds typed throws for precise error handling:

```swift
// Before
func load() throws -> Data { ... }

// After: callers know the exact error type
func load() throws(NetworkError) -> Data { ... }

do {
    let data = try load()
} catch {
    // error is NetworkError, not any Error
    switch error {
    case .timeout: ...
    case .notFound: ...
    }
}
```

---

### Swift 6.2 (Xcode 26, Tahoe)

**Major Features:**
- **Foundation Models API** -- On-device Apple Intelligence model integration
- **`@MainActor` inference improvements** -- Opt-in via build setting for less boilerplate
- **`nonisolated(unsafe)`** -- Gradual migration from strict concurrency
- **Embedded Swift** -- Swift for microcontrollers (no OS dependency)

#### Foundation Models API

```swift
import FoundationModels

// Basic usage (3 lines)
let session = LanguageModelSession()
let response = try await session.respond(to: "Summarize: \(text)")
print(response.content)
```

**Guided Generation (structured output):**

```swift
@Generable
struct ExtractedData {
    var title: String
    var keywords: [String]
    var sentiment: String
}

let result = try await session.respond(
    to: "Extract from: \(text)",
    generating: ExtractedData.self
)
// result.title, result.keywords, result.sentiment are typed
```

**Tool Calling:**

```swift
struct SearchTool: Tool {
    let name = "search"
    let description = "Search documents"
    func call(arguments: String) async -> String { ... }
}

let session = LanguageModelSession(tools: [SearchTool()])
```

**Requirements:**
- macOS 26+ (Apple Silicon only, no Intel)
- Apple Intelligence enabled in System Settings
- ~3B parameter model, quantized, runs on Apple Neural Engine
- MDM can control via `allowAppleIntelligence` restriction

#### nonisolated(unsafe)

Provides a migration escape hatch from strict concurrency:

```swift
// When you know a property is thread-safe but the compiler disagrees
nonisolated(unsafe) var sharedConfig: Configuration = .default
```

Use sparingly; prefer proper isolation. This is a bridge for gradual migration, not a permanent solution.

#### @MainActor Inference Improvements

Opt-in build setting reduces `@MainActor` annotation boilerplate for UI code:
- View conformances automatically infer `@MainActor`
- Reduces annotation noise in SwiftUI apps
- Must be explicitly opted into via build settings

---

## Swift Toolchain Management

### swift.org Toolchains

Apple publishes Swift toolchains independently of Xcode for CI servers, Linux, and Windows:

```
https://swift.org/download/
```

**Installing a custom toolchain:**

```bash
# Toolchain .pkg installs to:
/Library/Developer/Toolchains/swift-6.0-RELEASE.xctoolchain

# Activate via environment:
export TOOLCHAINS=swift-6.0-RELEASE

# Verify:
xcrun --toolchain swift-6.0-RELEASE swift --version
```

### swiftenv Version Manager

`swiftenv` manages per-project Swift toolchain selection:

```bash
# Install
brew install swiftenv
eval "$(swiftenv init -)"

# Install a specific version
swiftenv install 6.0

# Pin version for a project (.swift-version file)
swiftenv local 6.0

# Global default
swiftenv global 6.0

# List installed
swiftenv versions
```

---

## Migration Strategy Recommendations

### From Swift 5.9 to 6.0

1. **Upgrade Xcode** to 16.x
2. **Set `SWIFT_STRICT_CONCURRENCY=targeted`** -- Fix warnings module by module
3. **Convert critical shared state** to actors
4. **Add `@MainActor`** to UI-facing classes
5. **Address `Sendable` conformance** warnings
6. **Move to `SWIFT_STRICT_CONCURRENCY=complete`** when all targeted warnings resolved
7. **Enable Swift 6 language mode** when complete mode is clean
8. **Adopt typed throws** for new code (optional, additive)

### From Swift 6.0 to 6.2

1. **Upgrade Xcode** to 26.x
2. **No breaking changes** from 6.0 to 6.2; mostly additive features
3. **Evaluate Foundation Models** for on-device AI use cases
4. **Consider `@MainActor` inference** opt-in for reducing annotation boilerplate
5. **Use `nonisolated(unsafe)`** only where needed for legacy code migration

### CI/CD Considerations

- Pin Swift version in CI via Xcode version or `.swift-version` file
- Test with `SWIFT_STRICT_CONCURRENCY=complete` in CI even if not yet enforced locally
- Swift Package Manager caches can conflict between Swift versions; clear `~/.swiftpm/cache` after upgrades
- Use `swift build --configuration release` for production-representative CI builds
