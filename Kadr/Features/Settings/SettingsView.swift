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
        .frame(minWidth: 680, idealWidth: 680, minHeight: 560, idealHeight: 600)
    }
}
