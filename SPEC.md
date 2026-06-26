# Emulov — Technical Specification

## Motivation

Semulov, the original menu bar ejector, targets Intel Macs and is built around physical disk drives using the full DiskArbitration mount/eject lifecycle. Emulov is a clean-break successor focused on the volumes modern Mac users actually need to manage: disk images, network mounts, and removable media. It builds natively for Apple Silicon and runs on macOS 14+.

---

## Tech Stack

| Concern | Choice |
|---|---|
| Language | Swift 5.9+ |
| UI | SwiftUI `MenuBarExtra` (`.menu` style) |
| Minimum OS | macOS 14.0 Sonoma |
| Architectures | arm64 + x86_64 (universal binary) |
| Volume discovery | `FileManager` + `URLResourceKey` |
| Disk image detection | `DiskArbitration` (synchronous description query only) |
| Ejection | `NSWorkspace.unmountAndEjectDevice(at:)` |
| Change monitoring | `NSWorkspace` mount/unmount notifications |
| Dependencies | None (system frameworks only) |

---

## Project Layout

```
Emulov/
├── project.yml               ← XcodeGen spec; re-run after structural changes
├── Emulov.xcodeproj          ← generated; do not edit by hand
└── Emulov/
    ├── App.swift             ← @main, MenuBarExtra scene
    ├── Info.plist            ← LSUIElement=true, no Dock icon
    ├── Models/
    │   ├── VolumeType.swift  ← enum: diskImage | network | removable
    │   └── Volume.swift      ← Identifiable value type (url, name, type, icon)
    ├── Services/
    │   └── VolumeMonitor.swift  ← @Observable service; owns discovery + ejection
    └── Views/
        ├── MenuContentView.swift    ← root menu: sections + Eject All + Quit
        └── VolumeSectionView.swift  ← per-category volume rows
```

---

## Volume Classification

### Discovery

```swift
FileManager.default.mountedVolumeURLs(
    includingResourceValuesForKeys: keys,
    options: [.skipHiddenVolumes]
)
```

Resource keys queried per URL:

| Key | Purpose |
|---|---|
| `volumeNameKey` | Display name |
| `volumeIsRemovableKey` | True for USB, SD cards, disk images |
| `volumeIsEjectableKey` | True for anything the user can safely remove |
| `volumeIsLocalKey` | False for network mounts |
| `volumeIsInternalKey` | True for boot drive and built-in card readers |
| `volumeIsRootFileSystemKey` | True only for `/` |

### Classification logic

```
skip  if isRoot
skip  if isInternal && !isEjectable        ← boot SSD / internal non-removable
→ .network    if !isLocal
→ .diskImage  if isLocal && (isRemovable || isEjectable) && DA says "Disk Image"
→ .removable  if isLocal && (isRemovable || isEjectable) && not a disk image
```

**Note on built-in SD card readers:** macOS reports `volumeIsInternal = true` for SD cards inserted into a Mac's internal card slot. The original skip rule `isInternal → skip` incorrectly dropped these. The corrected rule skips only `isInternal && !isEjectable`, which preserves ejectable media in built-in slots while still filtering the boot drive.

### Disk image detection

DiskArbitration is used for one purpose only: distinguishing disk images from physical removable media. No run-loop scheduling is needed for synchronous description queries.

```swift
func isDiskImage(at url: URL) -> Bool {
    guard
        let session = DASessionCreate(kCFAllocatorDefault),
        let disk    = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL),
        let desc    = DADiskCopyDescription(disk) as? [AnyHashable: Any]
    else { return false }
    return (desc[kDADiskDescriptionMediaKindKey] as? String) == "Disk Image"
}
```

**Known pitfall:** `DADiskCopyDescription` returns `CFDictionary`, which bridges to `[AnyHashable: Any]` in Swift — not `[CFString: Any]`. Using the wrong cast type silently returns `nil`, causing all disk images to be misclassified as removable.

---

## VolumeMonitor

`@Observable @MainActor final class` — single source of truth for the UI.

```swift
var diskImages:    [Volume]
var networkMounts: [Volume]
var removable:     [Volume]

func refresh()       // re-scans FileManager; called on init and on mount/unmount notifications
func eject(_ volume: Volume)   // dispatches unmount off the main thread
func ejectAll()                // ejects all volumes concurrently
```

Mount/unmount notifications are subscribed with `queue: .main`; `MainActor.assumeIsolated` is used in the handler closure to satisfy Swift's actor-isolation checker without creating an extra async hop.

---

## Ejection

```swift
try? NSWorkspace.shared.unmountAndEjectDevice(at: url)
```

`NSWorkspace` handles all three volume types uniformly. The call is dispatched on a `Task.detached(priority: .userInitiated)` to avoid blocking the main actor while the OS resolves open file handles. Errors are silently discarded in v1; a future version should surface them as a transient status item in the menu.

---

## Menu Structure

```
[⏏]  ← SF Symbol "eject.fill", template image
──────────────────────────
  DISK IMAGES
  • MyImage.dmg
  • Xcode_15.dmg
──────────────────────────
  NETWORK
  • TimeMachineNAS
──────────────────────────
  REMOVABLE
  • SAMSUNG USB
──────────────────────────
  Eject All
──────────────────────────
  Quit Emulov
```

- Sections are hidden when empty.
- "Eject All" is hidden when no volumes are present.
- Volume icons come from `NSWorkspace.shared.icon(forFile:)`.
- Action label is "Disconnect" for `.network`, "Eject" for others.

---

## Build Notes

- `project.yml` is the source of truth for the Xcode project. Run `xcodegen generate` after any structural change.
- Release builds set `ONLY_ACTIVE_ARCH = NO` to produce a universal (`arm64 + x86_64`) binary.
- No entitlements file is required; the app runs unsandboxed.
- `LSUIElement = true` in Info.plist suppresses the Dock icon and app switcher entry.

---

## Verification Checklist

1. Mount a `.dmg` → appears under **Disk Images**, click → unmounts
2. Connect a USB drive → appears under **Removable**, click → safe-ejects
3. Insert an SD card (built-in slot) → appears under **Removable**, click → ejects
4. Connect a network share → appears under **Network**, click → disconnects
5. Unmount a volume externally → disappears from the menu automatically
6. `lipo -info Emulov.app/Contents/MacOS/Emulov` → `x86_64 arm64`
