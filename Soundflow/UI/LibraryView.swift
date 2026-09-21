import SwiftUI
import UniformTypeIdentifiers

/// Écran principal : la bibliothèque.
struct LibraryView: View {
    @Environment(LibraryModel.self) private var library
    @Environment(PreferencesStore.self) private var store
    @Environment(PlayerController.self) private var player

    @State private var isImporterPresented = false
    @State private var isNowPlayingPresented = false
    @State private var banner: BannerContent?

    private struct BannerContent: Equatable, Identifiable {
        let id = UUID()
        let message: String
        let isError: Bool

        static func == (lhs: BannerContent, rhs: BannerContent) -> Bool {
            lhs.message == rhs.message && lhs.isError == rhs.isError
        }
    }

    var body: some View {
        @Bindable var library = library

        NavigationStack {
            Group {
                if library.tracks.isEmpty {
                    emptyState
                } else {
                    trackList
                }
            }
            .navigationTitle("Soundflow")
            .searchable(
                text: $library.searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Rechercher"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isImporterPresented = true
                    } label: {
                        Label("Importer", systemImage: "plus")
                    }
                    .disabled(library.importingSource == nil)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        player.startPlaybackFromScratch()
                        isNowPlayingPresented = true
                    } label: {
                        Label("Lecture aléatoire", systemImage: "shuffle")
                    }
                    .disabled(library.tracks.isEmpty)
                }
            }
            // La barre de lecture est ancrée au bas de l'écran : elle ne
            // défile pas avec la liste et ne masque jamais la dernière ligne.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                MiniPlayerBar { isNowPlayingPresented = true }
            }
            .overlay(alignment: .bottom) {
                if let banner {
                    StatusBanner(message: banner.message, isError: banner.isError)
                        .padding(.bottom, player.currentTrack == nil ? 16 : 70)
                }
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: library.supportedContentTypes,
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .sheet(isPresented: $isNowPlayingPresented) {
            NowPlayingView()
        }
        .task {
            await library.refresh(pruning: store)
        }
        .onChange(of: library.lastMessage) { _, message in
            guard let message else { return }
            show(message: message, isError: false)
            library.lastMessage = nil
        }
        .onChange(of: player.lastError) { _, message in
            guard let message else { return }
            show(message: message, isError: true)
            player.lastError = nil
        }
        .onChange(of: library.tracks) { _, _ in
            player.libraryDidChange()
        }
        // Le bandeau disparaît tout seul : pas de bouton à fermer, donc pas
        // de geste imposé à l'utilisateur.
        .task(id: banner?.id) {
            guard banner != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation { banner = nil }
        }
    }

    // MARK: - Liste

    private var trackList: some View {
        List {
            ForEach(library.filteredTracks) { track in
                TrackRow(
                    track: track,
                    preferences: store.preferences(for: track.id),
                    isCurrent: player.currentTrack?.id == track.id,
                    isPlaying: player.isPlaying,
                    onPlay: { player.play(track) },
                    onSetScore: { store.setScore($0, for: track.id) },
                    onToggleMute: { store.toggleMuted(track.id) }
                )
                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 8))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if library.importingSource != nil {
                        Button(role: .destructive) {
                            Task { await library.delete(track, store: store) }
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if library.filteredTracks.isEmpty && !library.searchText.isEmpty {
                ContentUnavailableView.search(text: library.searchText)
            }
        }
        .refreshable {
            await library.refresh(pruning: store)
        }
    }

    // MARK: - État vide

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Aucun morceau", systemImage: "music.note.list")
        } description: {
            Text("""
                 Ajoutez des fichiers MP3 avec le bouton +, \
                 ou déposez-les dans le dossier Soundflow \
                 depuis l'app Fichiers ou le Finder de votre Mac.
                 """)
        } actions: {
            Button("Importer des fichiers") {
                isImporterPresented = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(library.importingSource == nil)
        }
    }

    // MARK: - Actions

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task { await library.importFiles(urls) }
        case .failure(let error):
            show(message: error.localizedDescription, isError: true)
        }
    }

    private func show(message: String, isError: Bool) {
        withAnimation {
            banner = BannerContent(message: message, isError: isError)
        }
    }
}
