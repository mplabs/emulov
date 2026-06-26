# Emulov

A lightweight macOS menu bar utility for ejecting disk images, network mounts, and removable media. Spiritual successor to [Semulov](https://github.com/karelia/Semulov), rebuilt for Apple Silicon in Swift.

## Requirements

- macOS 14.0 Sonoma or later
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Getting started

```bash
git clone <repo>
cd Emulov
xcodegen generate
open Emulov.xcodeproj
```

Set your Development Team in *Signing & Capabilities*, then run.

## What it does

Emulov sits in the menu bar and lists every non-system volume currently mounted:

- **Disk Images** — `.dmg`, `.iso`, `.sparsebundle`, etc.
- **Network** — SMB, AFP, NFS, WebDAV shares
- **Removable** — USB drives, SD cards (including built-in card readers)

Click any volume to eject or disconnect it. *Eject All* clears everything at once.

## Architecture

See [SPEC.md](SPEC.md) for the full technical specification.

## License

MIT
