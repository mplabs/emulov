import AppKit
import DiskArbitration
import Observation
import UserNotifications

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

    func eject(_ volume: Volume) { eject([volume]) }

    func ejectAll() { eject(all) }

    private func eject(_ volumes: [Volume]) {
        let targets = volumes.map { (url: $0.url, name: $0.name) }
        Task.detached(priority: .userInitiated) {
            let ejected = targets
                .filter { (try? NSWorkspace.shared.unmountAndEjectDevice(at: $0.url)) != nil }
                .map(\.name)
            guard !ejected.isEmpty else { return }

            // ponytail: no UNUserNotificationCenterDelegate — a menu bar agent is never the
            // active app, so banners show. Add willPresent if the app ever gets a window.
            let center = UNUserNotificationCenter.current()
            guard (try? await center.requestAuthorization(options: [.alert])) == true else { return }
            let content = UNMutableNotificationContent()
            content.title = "Ejected"
            content.body  = ejected.formatted(.list(type: .and))
            try? await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
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
