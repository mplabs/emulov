import SwiftUI

struct MenuContentView: View {
    @Environment(VolumeMonitor.self) private var monitor

    var body: some View {
        if !monitor.hasAnyVolume {
            Text("No volumes mounted")
                .foregroundStyle(.secondary)
        }

        if !monitor.diskImages.isEmpty {
            VolumeSectionView(title: VolumeType.diskImage.sectionTitle, volumes: monitor.diskImages)
        }

        if !monitor.networkMounts.isEmpty {
            VolumeSectionView(title: VolumeType.network.sectionTitle, volumes: monitor.networkMounts)
        }

        if !monitor.removable.isEmpty {
            VolumeSectionView(title: VolumeType.removable.sectionTitle, volumes: monitor.removable)
        }

        if monitor.hasAnyVolume {
            Divider()
            Button("Eject All") {
                monitor.ejectAll()
            }
        }

        Divider()

        Button("Quit Emulov") {
            NSApplication.shared.terminate(nil)
        }
    }
}
