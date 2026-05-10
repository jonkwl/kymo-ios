import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \SavedSession.startedAt, order: .reverse)
    private var sessions: [SavedSession]

    @Environment(\.modelContext) private var modelContext

    @State private var sessionsPendingDeletion: [SavedSession] = []
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .navigationTitle("My Recordings")
            .contentMargins(.top, 16, for: .scrollContent)
            .contentMargins(.bottom, 24, for: .scrollContent)
            .alert(deletionAlertTitle, isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    sessionsPendingDeletion = []
                }
                Button("Delete", role: .destructive) {
                    deleteConfirmedSessions()
                }
            } message: {
                Text(deletionAlertMessage)
            }
        }
    }

    private var deletionAlertTitle: String {
        if sessionsPendingDeletion.count <= 1 {
            return "Delete Recording?"
        }
        return "Delete \(sessionsPendingDeletion.count) Recordings?"
    }

    private var deletionAlertMessage: String {
        if sessionsPendingDeletion.count == 1, let session = sessionsPendingDeletion.first {
            return "“\(session.title)” will be permanently removed including any saved ECG data. You cannot undo this action."
        }
        if sessionsPendingDeletion.count > 1 {
            return "These \(sessionsPendingDeletion.count) recordings will be permanently removed including any saved ECG data. You cannot undo this action."
        }
        return "This recording will be permanently removed. You cannot undo this action."
    }

    // MARK: Session list

    private var sessionList: some View {
        List {
            ForEach(groupedByMonth, id: \.month) { group in
                Section(group.month) {
                    ForEach(group.sessions) { session in
                        NavigationLink(destination: SessionDetailView(session: session)) {
                            sessionRow(for: session)
                        }
                    }
                    .onDelete { indexSet in
                        sessionsPendingDeletion = indexSet.map { group.sessions[$0] }
                        showDeleteConfirmation = true
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.tertiary)

            VStack(spacing: 6) {
                Text("No Recordings Yet")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Complete a session to see it here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Row

    private func sessionRow(for session: SavedSession) -> some View {
        let color = ActivityColor(rawValue: session.colorName)?.color ?? .blue

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.gradient)
                        .frame(width: 44, height: 44)

                    Image(systemName: Sport(rawValue: session.sport)?.icon ?? "heart.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title)
                        .font(.headline.weight(.bold))
                        .foregroundColor(.primary)

                    Text(formattedDate(session.startedAt))
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 8) {
                metricPill(icon: "timer", text: formattedDuration(session.durationSeconds))

                if let avg = session.averageBpm {
                    metricPill(icon: "heart.fill", text: "\(avg) BPM")
                }

                if let rpe = session.rpe {
                    metricPill(icon: "gauge", text: "RPE \(rpe)")
                }
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: Grouping

    private struct MonthGroup: Identifiable {
        let month: String
        let sessions: [SavedSession]
        var id: String { month }
    }

    private var groupedByMonth: [MonthGroup] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        var groups: [String: [SavedSession]] = [:]
        var order: [String] = []

        for session in sessions {
            let key = formatter.string(from: session.startedAt)
            if groups[key] == nil {
                order.append(key)
            }
            groups[key, default: []].append(session)
        }

        return order.compactMap { key in
            guard let list = groups[key] else { return nil }
            return MonthGroup(month: key, sessions: list)
        }
    }

    // MARK: Delete

    private func deleteConfirmedSessions() {
        for session in sessionsPendingDeletion {
            if let url = session.ecgFileURL {
                try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
            }
            modelContext.delete(session)
        }
        sessionsPendingDeletion = []
    }

    // MARK: Formatting

    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        if calendar.isDateInToday(date) {
            return "Today • \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday • \(formatter.string(from: date))"
        } else {
            formatter.dateFormat = "MMM d • HH:mm"
            return formatter.string(from: date)
        }
    }

    private func formattedDuration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = total / 60 % 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    private func metricPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemFill))
        .clipShape(Capsule())
    }
}
