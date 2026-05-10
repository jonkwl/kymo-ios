import SwiftUI

struct EcgGraphPanel: View {
    let samples: [Double]
    let streamState: SensorManager.EcgStreamState
    /// Live BPM from the sensor (in-session only); shown bottom-trailing when > 0.
    var currentBpm: Int? = nil

    @Environment(\.colorScheme) private var colorScheme
    
    private var shouldShowWaitingMessage: Bool {
        switch streamState {
        case .initializing, .unavailable:
            return true
        case .streaming, .stopped:
            return false
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                ecgStyle.background

                GraphGridView()
                    .stroke(ecgStyle.grid, lineWidth: 0.6)

                if shouldShowWaitingMessage {
                    EcgLoadingMessage(style: ecgStyle)
                } else {
                    EcgGraphView(samples: samples, style: ecgStyle)
                        .padding(.vertical, 24)
                }
            }

            if let bpm = currentBpm, bpm > 0 {
                LiveSessionBpmBadge(bpm: bpm)
                    .padding(10)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: samples.isEmpty)
    }

    private var ecgStyle: EcgGraphStyle {
        colorScheme == .dark ? .dark : .light
    }
}

struct EcgGraphView: View {
    let samples: [Double]
    let style: EcgGraphStyle

    private var dynamicRange: Double {
        let maxVal = samples.map(abs).max() ?? 1000
        return max(2000, maxVal * 1.2)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let middle = height / 2

            let scaleY = height / CGFloat(dynamicRange)
            let stepX = width / CGFloat(max(1, samples.count - 1))

            ZStack {
                ecgPath(stepX: stepX, middle: middle, scaleY: scaleY)
                    .stroke(style.glow, lineWidth: 5)
                    .blur(radius: 3)

                ecgPath(stepX: stepX, middle: middle, scaleY: scaleY)
                    .stroke(style.line, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
        .drawingGroup()
    }

    private func ecgPath(stepX: CGFloat, middle: CGFloat, scaleY: CGFloat) -> Path {
        var path = Path()
        guard samples.count > 1 else { return path }

        let startY = middle - CGFloat(samples[0]) * (scaleY / 2)
        path.move(to: CGPoint(x: 0, y: startY))

        for index in 1..<samples.count {
            let x = CGFloat(index) * stepX
            let y = middle - CGFloat(samples[index]) * (scaleY / 2)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        return path
    }
}

private struct EcgLoadingMessage: View {
    let style: EcgGraphStyle

    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
                .tint(style.line)

            VStack(spacing: 4) {
                Text("Waiting for ECG data")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("This can take a moment.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: 260)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct EcgGraphStyle {
    let background: Color
    let grid: Color
    let line: Color
    let glow: Color

    private static let traceBlue = Color(red: 0.15, green: 0.39, blue: 0.92)

    static let light = EcgGraphStyle(
        background: Color(red: 0.98, green: 0.98, blue: 0.98),
        grid: Color(red: 0.90, green: 0.90, blue: 0.90),
        line: traceBlue,
        glow: traceBlue.opacity(0.18)
    )

    static let dark = EcgGraphStyle(
        background: Color(red: 0.12, green: 0.12, blue: 0.12),
        grid: Color(red: 0.16, green: 0.16, blue: 0.16),
        line: traceBlue,
        glow: traceBlue.opacity(0.30)
    )
}

struct HeartRateHistoryGraphView: View {
    let samples: ContiguousArray<SessionManager.HeartRateSample>
    /// Elapsed-time positions (seconds) where a lap was completed. Drawn as vertical markers.
    var lapTimestamps: [TimeInterval] = []
    /// Live BPM from the sensor (in-session only); shown bottom-trailing when > 0.
    var currentBpm: Int? = nil
    /// Used to map horizontal zone bands (% max HR). Ignored if ≤ 0 (falls back to 190).
    var maxHeartRateForZones: Int = 190
    /// Live recording graph: stripes span the full view width and use clearer zone colors in light mode.
    var liveZoneStripeRendering: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    private let axisWidth: CGFloat = 38
    private let trailingPadding: CGFloat = 12
    private let verticalPadding: CGFloat = 18

    /// Dark-mode stripe opacity for **live** recording (unchanged).
    private let zoneStripeLiveDarkOpacity = 0.085
    /// Dark-mode stripe opacity for **saved** session detail — slightly stronger than live.
    private let zoneStripeSavedDarkOpacity = 0.115
    /// Saved-session stripes in light mode — clearly visible.
    private let zoneStripeSavedLightOpacity = 0.19
    /// Live-session stripes in light mode (saturated base colors × this opacity).
    private let zoneStripeLiveLightOpacity = 0.22

    private var effectiveMaxHR: Int {
        maxHeartRateForZones > 0 ? maxHeartRateForZones : 190
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            let chartRect = CGRect(
                x: rect.minX + axisWidth,
                y: rect.minY + verticalPadding,
                width: max(1, rect.width - axisWidth - trailingPadding),
                height: max(1, rect.height - verticalPadding * 2)
            )
            let sourcePoints = graphPoints
            let points = smoothedPoints(from: sourcePoints)
            let range = bpmRange(for: sourcePoints)
            let ticks = axisTicks(for: range)
            let timeRange = timeRange(for: sourcePoints)
            let stripeMinX = liveZoneStripeRendering ? rect.minX : chartRect.minX
            let stripeWidth = liveZoneStripeRendering ? rect.width : chartRect.width

            ZStack {
                zoneStripeFragments(
                    chartRect: chartRect,
                    stripeMinX: stripeMinX,
                    stripeWidth: stripeWidth,
                    visibleRange: range
                )

                GraphGridView()
                    .stroke(gridColor, lineWidth: 0.5)

                axisLines(in: chartRect, range: range, ticks: ticks)
                    .stroke(axisGridColor, lineWidth: 0.5)

                ForEach(ticks, id: \.self) { bpm in
                    Text("\(bpm)")
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: axisWidth - 8, alignment: .trailing)
                        .position(
                            x: axisWidth / 2,
                            y: yPosition(for: bpm, in: chartRect, range: range)
                        )
                }

                heartRatePath(points: points, in: chartRect, range: range, timeRange: timeRange)
                    .stroke(
                        Color.red.opacity(colorScheme == .dark ? 0.20 : 0.16),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round)
                    )
                    .blur(radius: 3)

                heartRatePath(points: points, in: chartRect, range: range, timeRange: timeRange)
                    .stroke(
                        Color.red.opacity(colorScheme == .dark ? 0.92 : 0.86),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )

                // Lap markers
                if !lapTimestamps.isEmpty {
                    lapMarkerLines(in: chartRect, timeRange: timeRange)
                        .stroke(
                            Color.primary.opacity(colorScheme == .dark ? 0.30 : 0.22),
                            style: StrokeStyle(lineWidth: 2, dash: [5, 5])
                        )

                    ForEach(Array(lapTimestamps.enumerated()), id: \.offset) { index, time in
                        let elapsed = max(1.0, timeRange.upperBound - timeRange.lowerBound)
                        let xFraction = CGFloat((time - timeRange.lowerBound) / elapsed)
                        let x = chartRect.minX + chartRect.width * xFraction
                        if x > chartRect.minX + 2 && x < chartRect.maxX - 2 {
                            Text("\(index + 1)")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.primary.opacity(0.65))
                                .padding(.horizontal, 3.5)
                                .padding(.vertical, 1.5)
                                .background(
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(Color(.systemBackground).opacity(0.88))
                                )
                                .position(x: x, y: chartRect.minY + 9)
                        }
                    }
                }
            }
        }

            if let bpm = currentBpm, bpm > 0 {
                LiveSessionBpmBadge(bpm: bpm)
                    .padding(10)
            }
        }
    }

    @ViewBuilder
    private func zoneStripeFragments(
        chartRect: CGRect,
        stripeMinX: CGFloat,
        stripeWidth: CGFloat,
        visibleRange: ClosedRange<Double>
    ) -> some View {
        let zones: [HeartRateZone] = [.zone1, .zone2, .zone3, .zone4, .zone5]
        ForEach(zones, id: \.rawValue) { zone in
            if let stripe = zoneStripeRect(
                zone: zone,
                chartRect: chartRect,
                stripeMinX: stripeMinX,
                stripeWidth: stripeWidth,
                visibleRange: visibleRange
            ) {
                Rectangle()
                    .fill(zoneStripeFill(for: zone))
                    .frame(width: stripe.width, height: stripe.height)
                    .position(x: stripe.midX, y: stripe.midY)
            }
        }
    }

    private func zoneStripeFill(for zone: HeartRateZone) -> Color {
        zoneStripeBaseColor(for: zone).opacity(zoneStripeOpacity())
    }

    private func zoneStripeBaseColor(for zone: HeartRateZone) -> Color {
        if liveZoneStripeRendering, colorScheme != .dark {
            switch zone {
            case .zone1: return Color(red: 0.48, green: 0.52, blue: 0.58)
            case .zone2: return Color(red: 0.20, green: 0.42, blue: 0.92)
            case .zone3: return Color(red: 0.12, green: 0.68, blue: 0.38)
            case .zone4: return Color(red: 0.98, green: 0.48, blue: 0.06)
            case .zone5: return Color(red: 0.92, green: 0.18, blue: 0.22)
            case .none: return Color.gray
            }
        }
        return zone.color
    }

    private func zoneStripeOpacity() -> Double {
        switch colorScheme {
        case .dark:
            return liveZoneStripeRendering ? zoneStripeLiveDarkOpacity : zoneStripeSavedDarkOpacity
        default:
            return liveZoneStripeRendering ? zoneStripeLiveLightOpacity : zoneStripeSavedLightOpacity
        }
    }

    /// BPM band for each zone matches `HeartRateZone.current` thresholds (% of max HR).
    private func zoneStripeRect(
        zone: HeartRateZone,
        chartRect: CGRect,
        stripeMinX: CGFloat,
        stripeWidth: CGFloat,
        visibleRange: ClosedRange<Double>
    ) -> CGRect? {
        let m = Double(effectiveMaxHR)
        let zoneLow: Double
        let zoneHigh: Double
        switch zone {
        case .zone1:
            zoneLow = m * 0.5
            zoneHigh = m * 0.6
        case .zone2:
            zoneLow = m * 0.6
            zoneHigh = m * 0.7
        case .zone3:
            zoneLow = m * 0.7
            zoneHigh = m * 0.8
        case .zone4:
            zoneLow = m * 0.8
            zoneHigh = m * 0.9
        case .zone5:
            zoneLow = m * 0.9
            zoneHigh = visibleRange.upperBound + 1
        case .none:
            return nil
        }

        let lo = max(zoneLow, visibleRange.lowerBound)
        let hi = min(zoneHigh, visibleRange.upperBound)
        guard hi > lo + 0.25 else { return nil }

        let yAtHi = yPosition(for: hi, in: chartRect, range: visibleRange)
        let yAtLo = yPosition(for: lo, in: chartRect, range: visibleRange)
        let top = min(yAtHi, yAtLo)
        let bottom = max(yAtHi, yAtLo)
        guard bottom > top else { return nil }

        return CGRect(x: stripeMinX, y: top, width: stripeWidth, height: bottom - top)
    }

    private func lapMarkerLines(in rect: CGRect, timeRange: ClosedRange<TimeInterval>) -> Path {
        var path = Path()
        let elapsed = max(1.0, timeRange.upperBound - timeRange.lowerBound)
        for time in lapTimestamps {
            let xFraction = CGFloat((time - timeRange.lowerBound) / elapsed)
            let x = rect.minX + rect.width * xFraction
            guard x > rect.minX + 2 && x < rect.maxX - 2 else { continue }
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        return path
    }

    private var graphPoints: [HeartRateGraphPoint] {
        samples.compactMap { sample in
            guard let bpm = sample.bpm else { return nil }
            return HeartRateGraphPoint(elapsedTime: sample.elapsedTime, bpm: Double(bpm))
        }
    }

    private func smoothedPoints(from points: [HeartRateGraphPoint]) -> [HeartRateGraphPoint] {
        guard points.count > 2 else { return points }

        return points.indices.map { index in
            let lowerBound = max(points.startIndex, index - 2)
            let upperBound = min(points.index(before: points.endIndex), index + 2)
            let window = points[lowerBound...upperBound]
            let averageBpm = window.reduce(0) { $0 + $1.bpm } / Double(window.count)
            return HeartRateGraphPoint(elapsedTime: points[index].elapsedTime, bpm: averageBpm)
        }
    }

    private func bpmRange(for points: [HeartRateGraphPoint]) -> ClosedRange<Double> {
        let values = points.map(\.bpm)
        guard let minBpm = values.min(), let maxBpm = values.max() else {
            return 60...140
        }

        let lower = max(40, floor((minBpm - 10) / 20) * 20)
        let upper = max(lower + 40, ceil((maxBpm + 10) / 20) * 20)
        return lower...upper
    }

    private func axisTicks(for range: ClosedRange<Double>) -> [Int] {
        let first = Int(ceil(range.lowerBound / 20) * 20)
        let last = Int(floor(range.upperBound / 20) * 20)
        guard first <= last else { return [] }
        return stride(from: first, through: last, by: 20).map { $0 }
    }

    private func timeRange(for points: [HeartRateGraphPoint]) -> ClosedRange<TimeInterval> {
        let start = points.first?.elapsedTime ?? 0
        let end = max(start + 1, points.last?.elapsedTime ?? start + 1)
        return start...end
    }

    private var gridColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06)
    }

    private var axisGridColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.10)
    }

    private func heartRatePath(
        points: [HeartRateGraphPoint],
        in rect: CGRect,
        range: ClosedRange<Double>,
        timeRange: ClosedRange<TimeInterval>
    ) -> Path {
        var path = Path()
        guard let firstPoint = points.first else { return path }

        let start = position(for: firstPoint, in: rect, range: range, timeRange: timeRange)
        guard points.count > 1 else {
            path.addEllipse(in: CGRect(x: start.x - 2, y: start.y - 2, width: 4, height: 4))
            return path
        }

        path.move(to: start)

        let screenPoints = points.map { position(for: $0, in: rect, range: range, timeRange: timeRange) }
        for index in screenPoints.indices.dropFirst() {
            let previous = screenPoints[index - 1]
            let current = screenPoints[index]
            let midpoint = CGPoint(
                x: (previous.x + current.x) / 2,
                y: (previous.y + current.y) / 2
            )
            path.addQuadCurve(to: midpoint, control: previous)
        }

        if let last = screenPoints.last {
            path.addLine(to: last)
        }

        return path
    }

    private func axisLines(in rect: CGRect, range: ClosedRange<Double>, ticks: [Int]) -> Path {
        var path = Path()
        for bpm in ticks {
            let y = yPosition(for: bpm, in: rect, range: range)
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }

    private func position(
        for point: HeartRateGraphPoint,
        in rect: CGRect,
        range: ClosedRange<Double>,
        timeRange: ClosedRange<TimeInterval>
    ) -> CGPoint {
        let elapsedRange = max(1, timeRange.upperBound - timeRange.lowerBound)
        let xProgress = CGFloat((point.elapsedTime - timeRange.lowerBound) / elapsedRange)

        return CGPoint(
            x: rect.minX + rect.width * xProgress,
            y: yPosition(for: point.bpm, in: rect, range: range)
        )
    }

    private func yPosition(
        for bpm: Int,
        in rect: CGRect,
        range: ClosedRange<Double>
    ) -> CGFloat {
        yPosition(for: Double(bpm), in: rect, range: range)
    }

    private func yPosition(
        for bpm: Double,
        in rect: CGRect,
        range: ClosedRange<Double>
    ) -> CGFloat {
        let bpmSpan = max(1, range.upperBound - range.lowerBound)
        let progress = CGFloat((bpm - range.lowerBound) / bpmSpan)
        return rect.maxY - rect.height * progress
    }
}

struct GraphGridView: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 30

        for x in stride(from: rect.minX, through: rect.maxX, by: step) {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
        }

        for y in stride(from: rect.minY, through: rect.maxY, by: step) {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }

        return path
    }
}

private struct HeartRateGraphPoint {
    let elapsedTime: TimeInterval
    let bpm: Double
}

private struct LiveSessionBpmBadge: View {
    let bpm: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "heart.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
            Text("\(bpm)")
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }
}
