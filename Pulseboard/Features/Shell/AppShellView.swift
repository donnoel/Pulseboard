import SwiftUI

struct AppShellView: View {
    var body: some View {
        TabView {
            PulseMapView()
                .tabItem {
                    Label("Pulse", systemImage: "globe.americas.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(PulsePalette.accent)
    }
}

#Preview {
    AppShellView()
}
