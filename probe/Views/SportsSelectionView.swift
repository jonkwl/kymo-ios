import SwiftUI

struct SportSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSport: Sport
    
    @State private var searchText = ""
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    private var searchResultsImportant: [Sport] {
        let important = Sport.importantSports
        if searchText.isEmpty { return important }
        return important.filter { $0.rawValue.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var searchResultsOther: [Sport] {
        let importantSet = Set(Sport.importantSports)
        let others = Sport.allCases.filter { !importantSet.contains($0) }
        
        if searchText.isEmpty { return others }
        return others.filter { $0.rawValue.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if searchResultsImportant.isEmpty && searchResultsOther.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .padding(.top, 40)
                } else {
                    VStack(spacing: 32) {
                        if !searchResultsImportant.isEmpty {
                            sportSection(sports: searchResultsImportant)
                        }
                        
                        if !searchResultsOther.isEmpty {
                            sportSection(title: "All Sports", sports: searchResultsOther)
                        }
                    }
                    .padding(.vertical, 24)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Select Sport")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search sports")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
    }
    
    // MARK: Subviews
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
                ZStack {
                    Circle()
                        .fill(selectedSport == sport ? Color.blue.gradient : Color(.secondarySystemGroupedBackground).gradient)
                        .frame(width: 72, height: 72)
                        .shadow(color: selectedSport == sport ? Color.blue.opacity(0.3) : .black.opacity(0.04), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: sport.icon)
                        .font(.system(size: 30, weight: .medium))
                        .foregroundColor(selectedSport == sport ? .white : .primary)
                }
                
                Text(sport.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(selectedSport == sport ? .primary : .secondary)
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
