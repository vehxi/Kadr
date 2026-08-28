import SwiftUI

struct SettingsView: View {
    @ObservedObject var updateController: UpdateController

    var body: some View {
        TabView {
            GeneralSettingsView(updateController: updateController)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            GenreSettingsView()
                .tabItem {
                    Label("Genres", systemImage: "tag")
                }
        }
        .frame(width: 640, height: 520)
    }
}
