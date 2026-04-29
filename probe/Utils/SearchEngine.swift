import Foundation

protocol SearchableItem {
    var searchText: String { get }
}

struct SearchEngine<Item> {
    private let entries: [Entry]
    private let resultMapper: (Entry) -> Item

    init(
        items: [Item],
        textProvider: @escaping (Item) -> String
    ) {
        self.entries = items.map {
            Entry(
                item: $0,
                normalized: textProvider($0)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
            )
        }

        self.resultMapper = { $0.item }
    }

    func search(_ text: String) -> [Item] {
        let query = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !query.isEmpty else {
            return entries.map(resultMapper)
        }

        let scored = entries.compactMap { entry -> (Entry, Int)? in
            let candidate = entry.normalized

            if candidate.hasPrefix(query) {
                return (entry, 0)
            }

            if candidate.contains(query) {
                return (entry, 1)
            }

            if levenshteinDistance(candidate, query) <= 2 {
                return (entry, 2)
            }

            return nil
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
                return lhs.0.normalized < rhs.0.normalized
            }
            .map { resultMapper($0.0) }
    }
}

private extension SearchEngine {
    struct Entry {
        let item: Item
        let normalized: String
    }

    func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)

        var dist = Array(
            repeating: Array(repeating: 0, count: b.count + 1),
            count: a.count + 1
        )

        for i in 0...a.count { dist[i][0] = i }
        for j in 0...b.count { dist[0][j] = j }

        for i in 1...a.count {
            for j in 1...b.count {
                if a[i - 1] == b[j - 1] {
                    dist[i][j] = dist[i - 1][j - 1]
                } else {
                    dist[i][j] = min(
                        dist[i - 1][j] + 1,
                        dist[i][j - 1] + 1,
                        dist[i - 1][j - 1] + 1
                    )
                }
            }
        }

        return dist[a.count][b.count]
    }
}
