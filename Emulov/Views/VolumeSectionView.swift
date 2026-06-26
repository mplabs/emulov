import SwiftUI

struct VolumeSectionView: View {
    @Environment(VolumeMonitor.self) private var monitor
    let title: String
    let volumes: [Volume]

    var body: some View {
        Section(title) {
            ForEach(volumes) { volume in
                Button {
                    monitor.eject(volume)
                } label: {
                    Label {
                        Text(volume.name)
                    } icon: {
                        Image(nsImage: volume.icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                    }
                }
            }
        }
    }
}
