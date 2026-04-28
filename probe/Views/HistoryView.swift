import SwiftUI

struct HistoryActivity: Identifiable {
    let id = UUID()
    let title: String
    let date: String
    let duration: String
    let avgBpm: Int
    let rpe: Int
    let icon: String
    let color: Color
}

struct HistoryView: View {
    @State private var recentActivities = [
        HistoryActivity(title: "Norwegian 4x4", date: "Apr 28 • 17:30", duration: "48:12", avgBpm: 168, rpe: 9, icon: "heart.circle.fill", color: .red),
        HistoryActivity(title: "Zone 2 Base", date: "Apr 25 • 08:15", duration: "1:15:00", avgBpm: 132, rpe: 4, icon: "figure.run", color: .blue),
        HistoryActivity(title: "Recovery Spin", date: "Apr 22 • 09:00", duration: "45:00", avgBpm: 115, rpe: 2, icon: "figure.indoor.cycle", color: .green)
    ]
    
    @State private var olderActivities = [
        HistoryActivity(title: "Threshold Intervals", date: "Mar 28 • 18:00", duration: "55:30", avgBpm: 172, rpe: 8, icon: "bolt.fill", color: .orange),
        HistoryActivity(title: "Long Run", date: "Mar 24 • 07:00", duration: "2:10:15", avgBpm: 145, rpe: 7, icon: "figure.run", color: .blue)
    ]

    var body: some View {
        NavigationStack {
            List {
                if !recentActivities.isEmpty {
                    Section("April 2026") {
                        ForEach(recentActivities) { activity in
                            activityRow(for: activity)
                        }
                        .onDelete { indexSet in
                            recentActivities.remove(atOffsets: indexSet)
                        }
                    }
                }
                
                if !olderActivities.isEmpty {
                    Section("March 2026") {
                        ForEach(olderActivities) { activity in
                            activityRow(for: activity)
                        }
                        .onDelete { indexSet in
                            olderActivities.remove(atOffsets: indexSet)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("My Activities")
            .contentMargins(.top, 16, for: .scrollContent)
            .contentMargins(.bottom, 24, for: .scrollContent)
        }
    }
    
    private func activityRow(for activity: HistoryActivity) -> some View {
        NavigationLink(destination: Text("Activity Overview: \(activity.title)")) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(activity.color.gradient)
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: activity.icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(activity.title)
                            .font(.headline.weight(.bold))
                            .foregroundColor(.primary)
                        
                        Text(activity.date)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 12) {
                    metricPill(icon: "timer", text: activity.duration, color: .blue)
                    metricPill(icon: "heart.fill", text: "\(activity.avgBpm) BPM", color: .red)
                    metricPill(icon: "chart.bar.fill", text: "RPE \(activity.rpe)", color: .orange)
                }
            }
            .padding(.vertical, 6)
        }
    }
    
    private func metricPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}
