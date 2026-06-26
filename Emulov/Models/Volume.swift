import AppKit

struct Volume: Identifiable, Hashable {
    let url: URL
    let name: String
    let type: VolumeType

    var id: URL { url }

    var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }

    static func == (lhs: Volume, rhs: Volume) -> Bool { lhs.url == rhs.url }
    func hash(into hasher: inout Hasher) { hasher.combine(url) }
}
