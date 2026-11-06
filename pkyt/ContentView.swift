import SwiftUI

struct ContentView: View {
    @Environment(Nav.self) private var nav

    var body: some View {
        @Bindable var nav = nav
        TabView(selection: $nav.tab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(Nav.Tab.home)
            PlaylistView()
                .tabItem { Label("Playlist", systemImage: "music.note.list") }
                .tag(Nav.Tab.playlist)
        }
        .toolbarBackground(Color.ink, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
