import SwiftUI

@main
struct EmulovApp: App {
    @State private var monitor = VolumeMonitor()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environment(monitor)
        } label: {
            Image(systemName: "eject.fill")
        }
        .menuBarExtraStyle(.menu)
    }
}
