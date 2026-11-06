import SwiftUI

struct HomeView: View {
    @State private var session = Session.shared
    @State private var home = Feed(.home, session: .shared)
    @State private var search: Feed?
    @State private var query = ""
    @State private var signingIn = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    bar
                    if let feed = search ?? (session.signedIn ? home : nil) {
                        list(feed)
                    } else {
                        ContentUnavailableView {
                            Label("Sign in to see your feed", systemImage: "person.crop.circle")
                        } description: {
                            Text("Or search for a video above.")
                        } actions: {
                            Button("Sign in") { signingIn = true }
                                .buttonStyle(.borderedProminent)
                        }
                        .foregroundStyle(Color.muted)
                        .padding(.top, 60)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .refreshable { await (search ?? home).load() }
            .background(.sky)
            .navigationTitle("Home")
            .toolbarBackground(Color.night, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if session.signedIn {
                        Button("Sign out") { Task { await session.signOut() } }
                    } else {
                        Button("Sign in") { signingIn = true }
                    }
                }
            }
            .sheet(isPresented: $signingIn) { SignInView() }
        }
        .environment(session)
        .task { await session.refresh() }
        .task(id: session.signedIn) {
            if session.signedIn { await home.load() }
        }
    }

    private var bar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.muted)
            TextField("Search YouTube", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit(submit)
            if !query.isEmpty {
                Button {
                    query = ""
                    search = nil
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.muted)
                }
            }
        }
        .padding(12)
        .card()
    }

    @ViewBuilder private func list(_ feed: Feed) -> some View {
        ForEach(feed.videos) { video in
            VideoRow(video: video)
                .task {
                    if video.id == feed.videos.last?.id { await feed.more() }
                }
        }
        if let error = feed.error {
            Text(error)
                .font(.footnote)
                .foregroundStyle(Color.pink)
                .padding()
                .card()
        }
        if feed.loading {
            ProgressView().tint(.cyan).padding()
        } else if feed.videos.isEmpty, feed.error == nil {
            Text("No videos").foregroundStyle(Color.muted).padding(.top, 40)
        }
    }

    private func submit() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        let feed = Feed(.search(q), session: session)
        search = feed
        Task { await feed.load() }
    }
}
