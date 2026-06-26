enum VolumeType {
    case diskImage
    case network
    case removable

    var sectionTitle: String {
        switch self {
        case .diskImage: "Disk Images"
        case .network:   "Network"
        case .removable: "Removable"
        }
    }

    var actionLabel: String {
        switch self {
        case .network: "Disconnect"
        default:       "Eject"
        }
    }

    var systemImage: String {
        switch self {
        case .diskImage: "opticaldisc"
        case .network:   "network"
        case .removable: "externaldrive"
        }
    }
}
