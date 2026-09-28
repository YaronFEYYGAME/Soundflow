import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Écran principal, en deux onglets : la bibliothèque et les fonds.
struct LibraryView: View {
    @Environment(LibraryModel.self) private var library
    @Environment(PreferencesStore.self) private var store
    @Environment(PlayerController.self) private var player
    @Environment(BackgroundStore.self) private var backgrounds

    private enum Tab: Hashable {
        case tracks
        case backgrounds
    }

    /// Ce que le sélecteur de fichiers importe. Un seul `.fileImporter` sert
    /// les deux usages : SwiftUI gère mal deux sélecteurs de fichiers sur le
    /// même écran (seul le dernier déclaré fonctionne).
    private enum ImportTarget {
        case audio
        case background
    }

    @State private var tab: Tab = .tracks
    @State private var isImporterPresented = false
    @State private var importTarget: ImportTarget = .audio
    @State private var isPhotoPickerPresented = false
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var isNowPlayingPresented = false
    @State private var banner: BannerContent?
    /// Incrémenté à chaque ajout en file : déclenche une vibration de
    /// confirmation, utile quand le balayage se fait sans regarder.
    @State private var enqueueCount = 0

    private struct BannerContent: Equatable, Identifiable {
        let id = UUID()
        let message: String
        let isError: Bool

        static func == (lhs: BannerContent, rhs: BannerContent) -> Bool {
            lhs.id == rhs.id
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch tab {
                case .tracks:
                    if library.tracks.isEmpty {
                        emptyState
                    } else {
                        trackList
                    }
                case .backgrounds:
                    BackgroundsView(
                        onAddFromPhotos: { isPhotoPickerPresented = true },
                        onAddFromFiles: {
                            importTarget = .background
                            isImporterPresented = true
                        }
                    )
                }
            }
            .navigationTitle("Soundflow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
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
            allowedContentTypes: importTarget == .audio ? library.supportedContentTypes : [.image],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result, target: importTarget)
        }
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $photoSelection,
            maxSelectionCount: 10,
            matching: .images,
            // `.current` : on veut le fichier d'origine. Le mode automatique
            // peut convertir l'image — et un GIF converti perd son animation.
            preferredItemEncoding: .current
        )
        .onChange(of: photoSelection) { _, items in
            guard !items.isEmpty else { return }
            photoSelection = []
            Task { await importPhotos(items) }
        }
        .sheet(isPresented: $isNowPlayingPresented) {
            NowPlayingView()
        }
        .task {
            await library.refresh()
            await backgrounds.refresh()
        }
        .onChange(of: library.lastMessage) { _, message in
            guard let message else { return }
            show(message: message, isError: false)
            library.lastMessage = nil
        }
        .onChange(of: backgrounds.lastMessage) { _, message in
            guard let message else { return }
            show(message: message, isError: true)
            backgrounds.lastMessage = nil
        }
        .onChange(of: player.lastError) { _, message in
            guard let message else { return }
            show(message: message, isError: true)
            player.lastError = nil
        }
        .onChange(of: library.tracks) { _, _ in
            player.libraryDidChange()
        }
        .sensoryFeedback(.success, trigger: enqueueCount)
        // Le bandeau disparaît tout seul : pas de bouton à fermer, donc pas
        // de geste imposé à l'utilisateur.
        .task(id: banner?.id) {
            guard banner != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation { banner = nil }
        }
    }

    // MARK: - Barre d'outils

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // L'onglet, en haut de l'écran, toujours visible.
        ToolbarItem(placement: .principal) {
            Picker("Section", selection: $tab) {
                Text("Morceaux").tag(Tab.tracks)
                Text("Fonds").tag(Tab.backgrounds)
            }
            .pickerStyle(.segmented)
            .frame(width: 210)
        }

        // Toujours les mêmes emplacements ; seul leur contenu dépend de
        // l'onglet. (Les conditions *entre* éléments de barre d'outils ne sont
        // pas prises en charge par toutes les versions d'iOS ; *à l'intérieur*
        // d'un élément, si.)
        ToolbarItem(placement: .topBarLeading) {
            if tab == .tracks {
                Button {
                    player.startPlaybackFromScratch()
                    isNowPlayingPresented = true
                } label: {
                    Label("Lecture aléatoire", systemImage: "shuffle")
                }
                .disabled(library.tracks.isEmpty)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if tab == .tracks {
                Button {
                    importTarget = .audio
                    isImporterPresented = true
                } label: {
                    Label("Importer des morceaux", systemImage: "plus")
                }
                .disabled(library.importingSource == nil)
            } else {
                Menu {
                    Button {
                        isPhotoPickerPresented = true
                    } label: {
                        Label("Depuis Photos", systemImage: "photo.on.rectangle")
                    }
                    Button {
                        importTarget = .background
                        isImporterPresented = true
                    } label: {
                        Label("Depuis Fichiers", systemImage: "folder")
                    }
                } label: {
                    Label("Ajouter un fond", systemImage: "plus")
                }
            }
        }
    }

    // MARK: - Liste

    private var trackList: some View {
        @Bindable var library = library

        return List {
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
                // Balayage de gauche à droite : ajout à la file d'attente.
                // `allowsFullSwipe` : un balayage franc suffit, sans avoir à
                // viser le bouton qui apparaît.
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        enqueue(track)
                    } label: {
                        Label("À suivre", systemImage: "text.badge.plus")
                    }
                    .tint(.indigo)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if library.importingSource != nil {
                        Button(role: .destructive) {
                            Task { await library.delete(track, store: store) }
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                    }
                }
                .accessibilityAction(named: "Ajouter à la file d'attente") {
                    enqueue(track)
                }
            }
        }
        .listStyle(.plain)
        .searchable(
            text: $library.searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Rechercher"
        )
        .overlay {
            if library.filteredTracks.isEmpty && !library.searchText.isEmpty {
                ContentUnavailableView.search(text: library.searchText)
            }
        }
        .refreshable {
            await library.refresh()
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
                 depuis l'app Fichiers.
                 """)
        } actions: {
            Button("Importer des fichiers") {
                importTarget = .audio
                isImporterPresented = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(library.importingSource == nil)
        }
    }

    // MARK: - Actions

    private func enqueue(_ track: Track) {
        let position = player.enqueue(track)
        enqueueCount += 1
        let place = position == 1 ? "en prochain" : "en position \(position)"
        show(message: "« \(track.title) » ajouté à la file, \(place).", isError: false)
    }

    private func handleImport(_ result: Result<[URL], Error>, target: ImportTarget) {
        switch result {
        case .success(let urls):
            switch target {
            case .audio:
                Task { await library.importFiles(urls) }
            case .background:
                Task {
                    var added = 0
                    for url in urls {
                        if await backgrounds.addFile(at: url) { added += 1 }
                    }
                    if added > 0 { showBackgroundsAdded(added) }
                }
            }
        case .failure(let error):
            show(message: error.localizedDescription, isError: true)
        }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        var added = 0
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                if await backgrounds.add(data: data) { added += 1 }
            } catch {
                show(message: "Une image n'a pas pu être chargée : \(error.localizedDescription)", isError: true)
            }
        }
        if added > 0 { showBackgroundsAdded(added) }
    }

    private func showBackgroundsAdded(_ count: Int) {
        show(
            message: count == 1 ? "Fond ajouté et choisi." : "\(count) fonds ajoutés ; le dernier est choisi.",
            isError: false
        )
    }

    private func show(message: String, isError: Bool) {
        withAnimation {
            banner = BannerContent(message: message, isError: isError)
        }
    }
}
