# macOS Hardware Reference

Coverage: Apple Silicon (M1 through M4) and supported Intel Macs.

---

## 1. Apple Silicon vs Intel Feature Matrix

| Feature | Apple Silicon (M1+) | Intel (T2) | Intel (No T2) |
|---------|-------------------|------------|---------------|
| Rosetta 2 | Yes (x86_64 translation) | N/A | N/A |
| Apple Intelligence | Yes (M1+) | No | No |
| Secure Enclave | Integrated in SoC | T2 chip (separate) | Not available |
| FileVault key storage | Secure Enclave | T2 chip | Software (EFI) |
| FileVault performance | Negligible overhead | Minimal overhead | ~5-10% CPU impact |
| Touch ID | Yes (where hardware present) | Yes (with T2) | No |
| Virtualization.framework | macOS + Linux guests | Linux only | Linux only |
| Neural Engine | Yes (16-core on M1+) | No | No |
| Unified Memory | Yes (shared CPU/GPU/NPU) | No (separate GPU) | No |
| Recovery Mode access | Hold power button | Cmd+R at startup | Cmd+R at startup |
| Homebrew prefix | `/opt/homebrew` | `/usr/local` | `/usr/local` |
| Kernel extensions | Deprecated (System Ext) | Supported with SIP | Supported with SIP |
| Recovery Lock (MDM) | Yes | No (firmware password) | No (firmware password) |

---

## 2. Apple Silicon Chip Capabilities

| Chip | Cores (P+E) | GPU Cores | Neural Engine | Max Memory | Released |
|------|-------------|-----------|---------------|------------|----------|
| M1 | 4P + 4E | 7-8 | 16-core | 16 GB | Nov 2020 |
| M1 Pro | 6-8P + 2E | 14-16 | 16-core | 32 GB | Oct 2021 |
| M1 Max | 8P + 2E | 24-32 | 16-core | 64 GB | Oct 2021 |
| M1 Ultra | 16P + 4E | 48-64 | 32-core | 128 GB | Mar 2022 |
| M2 | 4P + 4E | 8-10 | 16-core | 24 GB | Jun 2022 |
| M2 Pro | 6-8P + 4E | 16-19 | 16-core | 32 GB | Jan 2023 |
| M2 Max | 8P + 4E | 30-38 | 16-core | 96 GB | Jan 2023 |
| M2 Ultra | 16P + 8E | 60-76 | 32-core | 192 GB | Jun 2023 |
| M3 | 4P + 4E | 10 | 16-core | 24 GB | Oct 2023 |
| M3 Pro | 5-6P + 6E | 14-18 | 16-core | 36 GB | Oct 2023 |
| M3 Max | 10-12P + 4E | 30-40 | 16-core | 128 GB | Oct 2023 |
| M4 | 4P + 6E | 10 | 16-core | 32 GB | May 2024 |
| M4 Pro | 10-12P + 4E | 16-20 | 16-core | 48 GB | Oct 2024 |
| M4 Max | 12-14P + 4E | 32-40 | 16-core | 128 GB | Oct 2024 |

### Chip Detection
```bash
system_profiler SPHardwareDataType | grep -E "Chip|Cores|Memory"
sysctl -n machdep.cpu.brand_string
sysctl hw.perflevel0.physicalcpu    # Performance cores
sysctl hw.perflevel1.physicalcpu    # Efficiency cores
sysctl hw.memsize                   # Total memory in bytes
```

---

## 3. Rosetta 2 Status

Rosetta 2 provides AOT (ahead-of-time) translation of x86_64 binaries to arm64 on Apple Silicon. Translation cache stored in `/var/db/oah/`.

### Current Status
- **macOS 14 Sonoma**: Fully supported, installed on demand
- **macOS 15 Sequoia**: Fully supported, installed on demand
- **macOS 26 Tahoe**: Fully supported (last Intel macOS release; Rosetta remains for app compat)

### Detection
```bash
# Check if Rosetta 2 is installed
if /usr/bin/pgrep -q oahd 2>/dev/null; then
    echo "Rosetta 2 daemon running"
fi

# Run binary under Rosetta
arch -x86_64 /bin/bash
arch -x86_64 /usr/local/bin/brew     # x86_64 Homebrew

# Check binary architecture
file /path/to/binary
lipo -info /path/to/binary
```

### Install Rosetta 2
```bash
softwareupdate --install-rosetta --agree-to-license
```

---

## 4. Hardware-Gated Features

### Apple Intelligence (M1+ Required)
Apple Intelligence features are unavailable on all Intel Macs:
- Writing Tools (system-wide text rewriting, summarization)
- Notification summaries
- Image Playground / Genmoji
- Siri natural language improvements
- Spotlight semantic ranking (macOS 26)
- Foundation Models framework (macOS 26)
- Live Translation (macOS 26)

Intel Macs fall back to keyword-based Spotlight and standard Siri.

### Virtualization Framework
- **Apple Silicon**: macOS and Linux VM guests with hardware acceleration
- **Intel**: Linux guests only via Virtualization.framework
- Docker Desktop and UTM use Virtualization.framework on Apple Silicon

### Containerization Framework (macOS 26)
- Apple Silicon only
- Swift-based, open-source framework for Linux containers
- Uses Virtualization.framework underneath
- EXT4 block device support

### Neural Engine Workloads
- Core ML model inference routes to Neural Engine on Apple Silicon
- On Intel, Core ML falls back to CPU or discrete/integrated GPU
- Foundation Models framework requires Apple Silicon

---

## 5. T2 Security Chip vs Secure Enclave

### T2 Security Chip (Intel Macs, 2018-2020)
Present in: MacBook Air/Pro (2018+), Mac mini (2018+), iMac (2020), Mac Pro (2019), iMac Pro (2017)

Functions:
- Secure Boot (verifies bootloader integrity)
- Touch ID processing (where hardware exists)
- FileVault encryption key storage
- SSD controller (hardware AES encryption)
- Audio processing
- Image signal processor (camera)

### Secure Enclave (Apple Silicon)
Integrated into the SoC -- not a separate chip:
- All T2 functions plus
- Pointer Authentication Codes (PAC) for arm64e
- Recovery Lock for MDM (replaces firmware password)
- Non-exportable private keys for MDM identity certificates
- Bootstrap Token backing for MDM operations

### Key Difference for Administrators
- T2 uses firmware password for recovery protection
- Apple Silicon uses Recovery Lock (MDM-managed)
- Both support Bootstrap Token escrow to MDM
- Apple Silicon Secure Enclave backs MDM identity cert private key (non-exportable)

---

## 6. macOS Version Hardware Support

### macOS 14 Sonoma (2023)
- **Minimum Intel**: 8th gen Coffee Lake (2018+)
- **Apple Silicon**: All (M1+)
- **Dropped**: All 7th gen Kaby Lake (2017 models)

### macOS 15 Sequoia (2024)
- **Dropped**: MacBook Air 2018, MacBook Air 2019
- **Apple Silicon**: All (M1+)
- **AI features**: M1+ only

### macOS 26 Tahoe (2025) -- Last Intel Release
Only four Intel models supported:

| Model | Released |
|-------|---------|
| Mac Pro (2019) | December 2019 |
| MacBook Pro 16-inch (2019) | November 2019 |
| MacBook Pro 13-inch 4-port (2020) | May 2020 |
| iMac (2020) | August 2020 |

**Not supported in Tahoe:**
- MacBook Pro 13-inch 2-port (2020)
- MacBook Air (2020, Intel)
- All 2018 and earlier Intel Macs

**macOS 27 (expected 2026)**: Apple Silicon only. No Intel support.

### Hardware Refresh Planning
- Intel Macs on macOS 26 will receive security updates until approximately fall 2027
- After macOS 27 ships (fall 2026), Intel Macs are on final security patches
- Plan hardware refresh for Intel fleet within 12-18 months of macOS 26 GA

---

## 7. Architecture Detection Commands

```bash
# Basic architecture
uname -m                             # arm64 or x86_64
arch                                 # arm64 or i386

# Detailed hardware
system_profiler SPHardwareDataType
sysctl -a | grep hw.optional         # optional hardware features

# Chip-specific
sysctl hw.perflevel0.physicalcpu     # P-cores (Apple Silicon)
sysctl hw.perflevel1.physicalcpu     # E-cores (Apple Silicon)
sysctl -n hw.packages                # physical CPU packages

# Serial number and model
system_profiler SPHardwareDataType | grep -E "Serial|Model"
ioreg -rd1 -c IOPlatformExpertDevice | grep model
```

---

*Coverage: All Macs supported by macOS 14 Sonoma through macOS 26 Tahoe.*
