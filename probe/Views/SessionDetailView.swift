import SwiftUI

struct SessionDetailView: View {
    let session: SavedSession

    @AppStorage("userMaxHR") private var userMaxHR: Int = 190
    @Environment(\.colorScheme) private var colorScheme

    @State private var hrSamples: ContiguousArray<SessionManager.HeartRateSample> = []
    @State private var laps: [SavedSession.LapRecord] = []

    private var accentColor: Color {
        ActivityColor(rawValue: session.colorName)?.color ?? .blue
    }

    private var sportIcon: String {
        Sport(rawValue: session.sport)?.icon ?? "heart.fill"
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroHeader
                    .padding(.bottom, 24)

                VStack(spacing: 16) {
                    durationCard
                    if !session.note.isEmpty {
                        notesCard
                    }
                    if !hrSamples.isEmpty {
                        heartRateCard
                        zoneDistributionCard
                    }
                    metricsGrid
                    if !laps.isEmpty {
                        lapsCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let decoded = session.decodedHRSamples()
            hrSamples = ContiguousArray(decoded.map {
                SessionManager.HeartRateSample(elapsedTime: $0.elapsed, bpm: $0.bpm)
            })
            laps = session.decodedLaps()
        }
    }

    // MARK: Hero header

    private var heroHeader: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [accentColor.opacity(0.85), accentColor.opacity(0.45)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.22))
                        .frame(width: 72, height: 72)
                    Image(systemName: sportIcon)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 4) {
                    Text(session.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    Text(fullDateString(session.startedAt))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.82))
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }

    // MARK: Duration card

    private var durationCard: some View {
        sectionCard {
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    label("Session Time", icon: "timer", color: accentColor)
                    Text(formattedDuration(session.durationSeconds))
                        .font(.system(size: 64, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                }

                if session.averageBpm != nil || session.maxBpm != nil {
                    Divider()

                    HStack(spacing: 0) {
                        if let avg = session.averageBpm {
                            bpmStat(value: avg, label: "AVG BPM", icon: "heart.fill", color: .red)
                        }
                        if session.averageBpm != nil && session.maxBpm != nil {
                            Divider().frame(height: 44)
                        }
                        if let max = session.maxBpm {
                            bpmStat(value: max, label: "MAX BPM", icon: "heart.circle.fill", color: .pink)
                        }
                    }
                }
            }
        }
    }

    private func bpmStat(value: Int, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text("\(value)")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Heart rate card

    private var heartRateCard: some View {
        sectionCard(padding: 0) {
            VStack(spacing: 0) {
                label("Heart Rate", icon: "waveform.path.ecg", color: .red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                HeartRateHistoryGraphView(
                    samples: hrSamples,
                    lapTimestamps: laps.map(\.endTime)
                )
                .frame(height: 180)
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: Zone distribution card

    @ViewBuilder
    private var zoneDistributionCard: some View {
        let distribution = zoneDistribution
        let activeZones = HeartRateZone.allCases
            .filter { $0 != .none && (distribution[$0] ?? 0) > 0 }
            .sorted { $0.rawValue < $1.rawValue }

        if !activeZones.isEmpty {
            sectionCard {
                VStack(alignment: .leading, spacing: 14) {
                    label("Heart Rate Zones", icon: "chart.bar.fill", color: .orange)

                    GeometryReader { geo in
                        HStack(spacing: 3) {
                            ForEach(activeZones, id: \.rawValue) { zone in
                                let fraction = distribution[zone] ?? 0
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(zone.color)
                                    .frame(width: max(6, geo.size.width * CGFloat(fraction)))
                            }
                        }
                    }
                    .frame(height: 16)
                    .clipShape(Capsule())

                    VStack(spacing: 10) {
                        ForEach(activeZones, id: \.rawValue) { zone in
                            zoneRow(zone: zone, fraction: distribution[zone] ?? 0)
                        }
                    }
                }
            }
        }
    }

    private func zoneRow(zone: HeartRateZone, fraction: Double) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(zone.color)
                .frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(zoneName(for: zone))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(formattedZoneTime(fraction))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            Text(String(format: "%.0f%%", fraction * 100))
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(zone.color)
        }
    }

    private func zoneName(for zone: HeartRateZone) -> String {
        switch zone {
        case .zone1: return "Zone 1 · Very Light"
        case .zone2: return "Zone 2 · Light"
        case .zone3: return "Zone 3 · Moderate"
        case .zone4: return "Zone 4 · Hard"
        case .zone5: return "Zone 5 · Maximum"
        case .none:  return ""
        }
    }

    // MARK: Metrics grid

    private var metricsGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 12) {
            if let rpe = session.rpe {
                rpeCard(rpe: rpe)
            }
            if let dist = session.distanceMeters {
                metricTile(
                    title: "Distance",
                    value: String(format: "%.2f", dist / 1_000),
                    unit: "km",
                    icon: "figure.walk.motion",
                    color: .purple
                )
            }
            if session.hasEcg {
                metricTile(
                    title: "ECG Samples",
                    value: compactEcgCount(session.ecgSampleCount),
                    unit: nil,
                    icon: "bolt.heart.fill",
                    color: accentColor
                )
            }
        }
    }

    private func rpeCard(rpe: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "gauge")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                Text("Effort (RPE)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(rpe)")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                Text("/ 10")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            // Mini RPE bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.tertiarySystemFill))
                    Capsule()
                        .fill(rpeColor(rpe))
                        .frame(width: geo.size.width * (CGFloat(rpe) / 10))
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func metricTile(title: String, value: String, unit: String?, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                if let unit {
                    Text(unit)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Laps card

    private var lapsCard: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                label("Laps", icon: "flag.fill", color: .blue)

                VStack(spacing: 0) {
                    // Header row
                    HStack {
                        Text("#")
                            .frame(width: 28, alignment: .leading)
                        Text("Duration")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Avg BPM")
                            .frame(width: 70, alignment: .trailing)
                        if laps.contains(where: { $0.distanceMeters != nil }) {
                            Text("Dist")
                                .frame(width: 52, alignment: .trailing)
                        }
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                    ForEach(laps, id: \.number) { lap in
                        lapRow(lap)
                        if lap.number < laps.count {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func lapRow(_ lap: SavedSession.LapRecord) -> some View {
        HStack {
            Text("\(lap.number)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accentColor)
                .frame(width: 28, alignment: .leading)

            Text(formattedDuration(lap.duration))
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(lap.averageBpm.map { "\($0)" } ?? "—")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .frame(width: 70, alignment: .trailing)

            if laps.contains(where: { $0.distanceMeters != nil }) {
                Text(lap.distanceMeters.map { String(format: "%.2f", $0 / 1_000) } ?? "—")
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: Notes card

    private var notesCard: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 10) {
                label("Notes", icon: "note.text", color: .secondary)

                Text(session.note)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Shared components

    @ViewBuilder
    private func sectionCard<Content: View>(
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(padding)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func label(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }

    // MARK: Zone distribution calculation

    private var zoneDistribution: [HeartRateZone: Double] {
        let bpms = hrSamples.compactMap(\.bpm)
        guard !bpms.isEmpty else { return [:] }
        let maxHR = userMaxHR > 0 ? userMaxHR : 190

        var counts: [HeartRateZone: Int] = [:]
        for bpm in bpms {
            let zone = HeartRateZone.current(bpm: bpm, maxHR: maxHR)
            counts[zone, default: 0] += 1
        }

        let total = Double(bpms.count)
        return counts.mapValues { Double($0) / total }
    }

    // MARK: Formatting

    private func formattedDuration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = total / 60 % 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    private func formattedZoneTime(_ fraction: Double) -> String {
        let total = Int((fraction * session.durationSeconds).rounded())
        let h = total / 3600
        let m = total / 60 % 60
        let s = total % 60
        if h > 0 { return String(format: "%dh %02dm %02ds", h, m, s) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return String(format: "%ds", s)
    }

    private func fullDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d · HH:mm"
        return formatter.string(from: date)
    }

    private func compactEcgCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.0fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    private func rpeColor(_ rpe: Int) -> Color {
        switch rpe {
        case 1...3: return .green
        case 4...6: return .orange
        default:    return .red
        }
    }
}
