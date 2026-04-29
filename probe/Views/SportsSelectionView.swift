import SwiftUI

typealias SportSearchEngine = SearchEngine<Sport>

struct SportSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSport: Sport

    @State private var searchText = ""
    @State private var filteredImportant: [Sport] = Sport.importantSports
    @State private var filteredOther: [Sport] = []
    @State private var searchResults: [Sport] = []

    @State private var searchTask: Task<Void, Never>?

    private let otherSportsBase: [Sport]
    private let searchEngine: SportSearchEngine

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    init(selectedSport: Binding<Sport>) {
        self._selectedSport = selectedSport

        let importantSet = Set(Sport.importantSports)
        let others = Sport.allCases.filter { !importantSet.contains($0) }

        self.otherSportsBase = others

        self.searchEngine = SportSearchEngine(
            items: Sport.allCases,
            textProvider: { $0.rawValue }
        )

        _filteredOther = State(initialValue: others)
        _searchResults = State(initialValue: Sport.allCases)
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if isSearching {
                    searchContent
                } else {
                    defaultContent
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Select Sport")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search sports"
            )
            .onChange(of: searchText) { _, newValue in
                performSearch(text: newValue)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
            .onAppear {
                performSearch(text: "")
            }
        }
    }

    @ViewBuilder
    private var defaultContent: some View {
        VStack(spacing: 32) {
            if !filteredImportant.isEmpty {
                sportSection(sports: filteredImportant)
            }

            if !filteredOther.isEmpty {
                sportSection(title: "All Sports", sports: filteredOther)
            }
        }
        .padding(.vertical, 24)
    }

    @ViewBuilder
    private var searchContent: some View {
        if searchResults.isEmpty {
            ContentUnavailableView.search(text: searchText)
                .padding(.top, 40)
        } else {
            VStack(spacing: 24) {
                sportSection(title: "Search Results", sports: searchResults)
            }
            .padding(.vertical, 24)
        }
    }

    private func performSearch(text: String) {
        searchTask?.cancel()

        searchTask = Task(priority: .userInitiated) {
            try? await Task.sleep(for: .milliseconds(120))

            let query = text
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if query.isEmpty {
                if Task.isCancelled { return }

                await MainActor.run {
                    searchResults = Sport.allCases
                    filteredImportant = Sport.importantSports

                    let importantSet = Set(Sport.importantSports)
                    filteredOther = Sport.allCases.filter {
                        !importantSet.contains($0)
                    }
                }

                return
            }

            let results = searchEngine.search(query)

            if Task.isCancelled { return }

            await MainActor.run {
                searchResults = results
            }
        }
    }

    private func sportSection(title: String? = nil, sports: [Sport]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
            }

            LazyVGrid(columns: columns, spacing: 28) {
                ForEach(sports) { sport in
                    sportGridItem(for: sport)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func sportGridItem(for sport: Sport) -> some View {
        Button {
            selectedSport = sport
            dismiss()
        } label: {
            VStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Circle()
                            .fill(
                                selectedSport == sport
                                ? Color.blue.gradient
                                : Color(.secondarySystemGroupedBackground).gradient
                            )
                            .frame(width: 72, height: 72)
                            .shadow(
                                color: selectedSport == sport
                                ? Color.blue.opacity(0.3)
                                : .black.opacity(0.04),
                                radius: 8,
                                x: 0,
                                y: 4
                            )

                        Image(systemName: sport.icon)
                            .font(.system(size: 30, weight: .medium))
                            .foregroundColor(
                                selectedSport == sport ? .white : .primary
                            )
                    }

                    if sport.useLocation {
                        ZStack {
                            Circle()
                                .fill(.background)
                                .frame(width: 22, height: 22)

                            Circle()
                                .fill(Color.blue.gradient)
                                .frame(width: 18, height: 18)

                            Image(systemName: "location.fill")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(.white)
                        }
                        .offset(x: 4, y: -4)
                    }
                }

                Text(sport.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(
                        selectedSport == sport ? .primary : .secondary
                    )
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .frame(height: 32, alignment: .top)
            }
        }
        .buttonStyle(.plain)
        .clickyButton(weight: .light)
    }
}
