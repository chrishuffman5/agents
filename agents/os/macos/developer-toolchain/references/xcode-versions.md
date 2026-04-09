# Xcode Versions Reference

## Version-to-OS Mapping

| Xcode | macOS Codename | Min Host macOS | Bundled Swift | Key SDK | Release Period |
|---|---|---|---|---|---|
| 15.0 | Sonoma era | macOS 13 Ventura | Swift 5.9.0 | macOS 14 SDK | Sep 2023 |
| 15.4 | Sonoma era | macOS 14 Sonoma | Swift 5.10 | macOS 14 SDK | Mar 2024 |
| 16.0 | Sequoia era | macOS 14 Sonoma | Swift 6.0 | macOS 15 SDK | Sep 2024 |
| 16.3 | Sequoia era | macOS 15 Sequoia | Swift 6.0.3 | macOS 15 SDK | Mar 2025 |
| 26.0 | Tahoe era | macOS 15 Sequoia | Swift 6.2 | macOS 26 SDK | Jun 2025 |

Note: Xcode version numbers jumped from 16 to 26 to align with the macOS 26 "Tahoe" branding cycle starting in 2025.

---

## Installation and Coexistence

### Installation Paths

```
/Applications/Xcode.app                   # default App Store install
/Applications/Xcode-15.app                # renamed for multi-version coexistence
/Applications/Xcode-16.app
/Applications/Xcode-26.app
/Library/Developer/CommandLineTools/       # CLT standalone (no Xcode.app)
```

### Active Developer Directory

The active developer directory controls which `xcrun`-resolved tools are used -- clang, swift, simctl, codesign, notarytool, etc.

```bash
# Show current active directory
xcode-select --print-path

# Switch active Xcode
sudo xcode-select --switch /Applications/Xcode-26.app/Contents/Developer

# Reset to default
sudo xcode-select --reset
```

### Multiple Installations

Multiple Xcode.app bundles coexist by renaming. Each is self-contained -- SDKs, toolchains, and simulators are bundled inside. Switching requires only `xcode-select --switch`.

```bash
# List installed Xcodes (Spotlight metadata)
mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'"

# Verify each installation
/Applications/Xcode-16.app/Contents/Developer/usr/bin/xcodebuild -version
/Applications/Xcode-26.app/Contents/Developer/usr/bin/xcodebuild -version
```

### xcrun Tool Resolution

`xcrun` resolves tool names through the active developer directory, avoiding hard-coded paths:

```bash
xcrun swift --version          # resolves to active Xcode's swift
xcrun xcodebuild -version      # resolves xcodebuild
xcrun simctl list              # iOS/macOS simulator control
xcrun notarytool               # Apple notarization tool
```

---

## App Store vs Direct Download

| Method | Pros | Cons |
|---|---|---|
| App Store | Auto-updates, simple install | Can update automatically (breaking CI), no version pinning |
| Direct .xip download | Version control, multiple versions | Large download (~7-12 GB compressed) |

**Direct download locations:**
- https://developer.apple.com/download/all/ (requires Apple Developer account)
- Extract: `xip --expand Xcode_26.xip` then move to /Applications

**Recommended practice for CI:**
- Download specific Xcode .xip from developer.apple.com
- Verify checksum before install
- Rename to `Xcode-26.app` for coexistence
- Lock CI images to specific Xcode version

---

## Xcode Command Line Tools (CLT)

CLT provides compilers and Unix tools without the full Xcode GUI.

### CLT vs Full Xcode

| Feature | CLT Only | Full Xcode |
|---|---|---|
| clang/clang++ | Yes | Yes |
| swift compiler | Yes | Yes |
| iOS/macOS SDKs | macOS SDK only | All platform SDKs |
| Simulator | No | Yes |
| Interface Builder | No | Yes |
| Instruments | No | Yes |
| Archive/sign/notarize | Partial (xcrun) | Full |
| Disk footprint | ~2 GB | 12-30 GB |

### CLT Install Methods

```bash
# Interactive (triggers GUI dialog)
xcode-select --install

# Find available CLT packages
softwareupdate --list | grep "Command Line"

# Install specific package
softwareupdate --install "Command Line Tools for Xcode-16" --agree-to-license

# Silent from .pkg (MDM deployment)
installer -pkg /tmp/Command_Line_Tools_for_Xcode_16.pkg -target /
```

### CLT Version Check

```bash
pkgutil --pkg-info=com.apple.pkg.CLTools_Executables 2>/dev/null | grep version
xcode-select --version
```

---

## Xcode 15 Features (Sonoma Era)

- **Swift 5.9:** Macros, SwiftData, Observation framework, variadic generics
- **Swift Macros:** Compile-time code generation via `@attached` and `@freestanding`
- **SwiftData:** Declarative persistent data framework (CoreData successor)
- **Observation:** `@Observable` macro replaces `ObservableObject`/`@Published`
- **String Catalogs:** `.xcstrings` format replaces `.strings` and `.stringsdict`
- **Previews:** `#Preview` macro simplifies SwiftUI preview syntax
- **Asset Catalogs:** Auto-generated symbols for color and image assets
- **Xcode Cloud:** Native CI/CD integration in Xcode

---

## Xcode 16 Features (Sequoia Era)

- **Swift 6.0:** Strict concurrency, complete actor isolation, Sendable enforcement
- **Strict Concurrency:** Data race safety enforced at compile time
- **Typed Throws:** `throws(ErrorType)` declarations
- **Migration Setting:** `SWIFT_STRICT_CONCURRENCY=complete` build setting
- **Thread Sanitizer:** Enhanced for Swift 6 concurrency model
- **Explicit Modules:** Faster, more reliable builds via explicit module dependency tracking
- **Predictive Code Completion:** AI-powered code completion (Apple Intelligence integration)

---

## Xcode 26 Features (Tahoe Era)

- **Swift 6.2:** Foundation Models, `@MainActor` inference improvements, embedded Swift
- **Foundation Models API:** On-device Apple Intelligence model integration
- **Compilation Caching:** Explicit caching for faster incremental and clean builds
- **`@Generable` Macro:** Structured output from Foundation Models
- **Tool Protocol:** Tool calling for Foundation Models sessions
- **Embedded Swift:** Swift for microcontrollers (no OS dependency)
- **`nonisolated(unsafe)`:** Gradual migration path from strict concurrency

### Foundation Models Requirements

- macOS 26+ only
- Apple Silicon (M1 or later, no Intel)
- Apple Intelligence enabled in System Settings
- MDM can control via `allowAppleIntelligence` restriction

### Compilation Caching

```bash
# Enable via build setting
COMPILATION_CACHING = YES

# Stores compiled Swift modules and object files keyed by input hash
# Useful on CI when build caches are restored between runs
```

---

## SDK and Platform Support Matrix

| Xcode | macOS SDK | iOS SDK | watchOS SDK | tvOS SDK | visionOS SDK |
|---|---|---|---|---|---|
| 15.x | 14.x | 17.x | 10.x | 17.x | 1.x |
| 16.x | 15.x | 18.x | 11.x | 18.x | 2.x |
| 26.x | 26.x | 26.x | 26.x | 26.x | 26.x |

### SDK Path Resolution

```bash
# Show active macOS SDK path
xcrun --show-sdk-path --sdk macosx

# Show SDK version
xcrun --show-sdk-version --sdk macosx

# List all available SDKs
xcodebuild -showsdks
```

---

## License Acceptance

Xcode requires license acceptance before use. On CI servers, accept non-interactively:

```bash
sudo xcodebuild -license accept
```

Verify:
```bash
xcodebuild -license check  # exits 0 if accepted
```
