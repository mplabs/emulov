import AppKit
import DiskArbitration
import Observation

@Observable @MainActor final class VolumeMonitor {
    var diskImages:    [Volume] = []
    var networkMounts: [Volume] = []
    var removable:     [Volume] = []

    var hasAnyVolume: Bool { !diskImages.isEmpty || !networkMounts.isEmpty || !removable.isEmpty }
    var all: [Volume] { diskImages + networkMounts + removable }

    init() {
        refresh()
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.didMountNotification,   object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        nc.addObserver(forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func refresh() {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey,
            .volumeIsLocalKey,
            .volumeIsInternalKey,
            .volumeIsRootFileSystemKey,
        ]

        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) else { return }

        var images:   [Volume] = []
        var networks: [Volume] = []
        var removals: [Volume] = []

        for url in urls {
            guard let res = try? url.resourceValues(forKeys: Set(keys)) else { continue }

            let isInternal   = res.volumeIsInternal      ?? true
            let isEjectable  = res.volumeIsEjectable     ?? false
            let isRoot       = res.volumeIsRootFileSystem ?? false
            let isLocal      = res.volumeIsLocal          ?? true
            let isRemovable  = res.volumeIsRemovable      ?? false
            let name         = res.volumeName             ?? url.lastPathComponent

            // Skip the root filesystem and internal non-ejectable volumes (boot SSD, Fusion Drive).
            // Built-in SD card readers report isInternal=true but isEjectable=true — keep those.
            if isRoot || (isInternal && !isEjectable) { continue }

            if !isLocal {
                networks.append(Volume(url: url, name: name, type: .network))
            } else if isRemovable || isEjectable {
                let type: VolumeType = isDiskImage(at: url) ? .diskImage : .removable
                let vol = Volume(url: url, name: name, type: type)
                type == .diskImage ? images.append(vol) : removals.append(vol)
            }
        }

        diskImages    = images
        networkMounts = networks
        removable     = removals
    }

    func eject(_ volume: Volume) {
        let url = volume.url
        Task.detached(priority: .userInitiated) {
            try? NSWorkspace.shared.unmountAndEjectDevice(at: url)
        }
    }

    func ejectAll() {
        let urls = all.map(\.url)
        Task.detached(priority: .userInitiated) {
            for url in urls {
                try? NSWorkspace.shared.unmountAndEjectDevice(at: url)
            }
        }
    }

    // DiskArbitration is only needed to distinguish disk images from physical removable media.
    // No run-loop scheduling required for synchronous description queries.
    private func isDiskImage(at url: URL) -> Bool {
        guard
            let session = DASessionCreate(kCFAllocatorDefault),
            let disk    = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL),
            let desc    = DADiskCopyDescription(disk) as? [AnyHashable: Any]
        else { return false }
        return (desc[kDADiskDescriptionMediaKindKey] as? String) == "Disk Image"
    }
}
