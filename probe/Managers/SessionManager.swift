import Observation
import ActivityKit
import Foundation
import Combine

@Observable
class SessionManager {
    enum SessionState: Equatable {
        case idle
        case recording
        case paused
    }

    struct HeartRateSample: Equatable {
        let elapsedTime: TimeInterval
        let bpm: Int?
    }

    struct LapMetrics: Equatable {
        let number: Int
        let startTime: TimeInterval
        let endTime: TimeInterval
        let duration: TimeInterval
        let averageBpm: Int?
        let averagePaceSecondsPerKilometer: TimeInterval?
        let distanceMeters: Double?
    }
    
    // MARK: State
    var state: SessionState = .idle
    var sport: Sport?
    var elapsedTime: TimeInterval = 0
    var laps: [TimeInterval] = []
    private(set) var heartRateSamples: ContiguousArray<HeartRateSample> = []
    private(set) var lapMetrics: [LapMetrics] = []
    private(set) var latestLapMetrics: LapMetrics? = nil
    private(set) var maxBpm: Int? = nil
    var distanceMeters: Double? = nil
    var currentPaceSecondsPerKilometer: TimeInterval? = nil
    var sensorManagerRef: SensorManager?
    
    private var timer: AnyCancellable?
    private var startTime: Date?
    private var accumulatedTime: TimeInterval = 0
    private let sampleInterval: TimeInterval = 1
    private let initialHeartRateSampleCapacity = 6 * 60 * 60
    private var heartRateCumulativeSums: [Int] = [0]
    private var heartRateCumulativeCounts: [Int] = [0]
    private var currentLapStartTime: TimeInterval = 0
    private var currentLapStartSampleIndex: Int = 0
    private var currentLapStartDistanceMeters: Double?
    
    private var activity: Activity<SessionAttributes>?
    
    // MARK: Formatting
    var timeString: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) / 60 % 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02i:%02i:%02i", hours, minutes, seconds)
    }

    var currentLapElapsedTime: TimeInterval {
        max(0, elapsedTime - currentLapStartTime)
    }

    var averageBpm: Int? {
        averageBpm(from: 0, to: heartRateSamples.count)
    }

    var currentLapMetrics: LapMetrics {
        makeLapMetrics(
            number: lapMetrics.count + 1,
            startTime: currentLapStartTime,
            endTime: elapsedTime,
            startSampleIndex: currentLapStartSampleIndex,
            endSampleIndex: heartRateSamples.count,
            startDistanceMeters: currentLapStartDistanceMeters,
            endDistanceMeters: distanceMeters
        )
    }
    
    // MARK: Actions
    func startSession(sport: Sport) {
        guard state == .idle else { return }
        resetSessionData(keepingCapacity: true)
        state = .recording
        self.sport = sport
        startTime = Date()
        
        let attributes = SessionAttributes(sessionName: sport.rawValue)
        let initialState = SessionAttributes.ContentState(currentBpm: 0, elapsedTime: 0)
        
        do {
            activity = try Activity.request(attributes: attributes, content: .init(state: initialState, staleDate: nil))
        } catch {
            print("Error starting Live Activity: \(error.localizedDescription)")
        }
        
        runTimer()
    }
    
    func pauseSession() {
        guard state == .recording else { return }
        state = .paused
        if let startTime {
            accumulatedTime += Date().timeIntervalSince(startTime)
            elapsedTime = accumulatedTime
        }
        startTime = nil
        timer?.cancel()
    }
    
    func resumeSession() {
        guard state == .paused else { return }
        state = .recording
        startTime = Date()
        runTimer()
    }
    
    func stopSession() {
        sensorManagerRef?.stopEcgStreaming()
        timer?.cancel()
        state = .idle
        let liveActivity = activity
        activity = nil
        sport = nil
        startTime = nil
        resetSessionData(keepingCapacity: true)
        
        Task {
            await liveActivity?.end(nil, dismissalPolicy: .immediate)
        }
    }
    
    func addLap() {
        guard state == .recording else { return }
        updateElapsedTime()
        let metrics = currentLapMetrics
        laps.append(elapsedTime)
        lapMetrics.append(metrics)
        latestLapMetrics = metrics
        currentLapStartTime = elapsedTime
        currentLapStartSampleIndex = heartRateSamples.count
        currentLapStartDistanceMeters = distanceMeters
    }
    
    private func runTimer() {
        timer?.cancel()
        timer = Timer.publish(every: sampleInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.state == .recording else { return }
                
                self.updateElapsedTime()
                
                let currentBpm = self.sensorManagerRef?.currentBpm ?? 0
                self.recordHeartRateSample(currentBpm: currentBpm)
                
                let newState = SessionAttributes.ContentState(
                    currentBpm: currentBpm,
                    elapsedTime: self.elapsedTime
                )

                let content = ActivityContent(state: newState, staleDate: nil)
                
                Task {
                    await self.activity?.update(content)
                }
            }
    }

    private func updateElapsedTime(now: Date = Date()) {
        guard let startTime else { return }
        elapsedTime = accumulatedTime + now.timeIntervalSince(startTime)
    }

    private func recordHeartRateSample(currentBpm: Int) {
        let bpm = currentBpm > 0 ? currentBpm : nil
        if let bpm {
            maxBpm = max(maxBpm ?? bpm, bpm)
        }

        heartRateSamples.append(
            HeartRateSample(
                elapsedTime: elapsedTime,
                bpm: bpm
            )
        )

        heartRateCumulativeSums.append((heartRateCumulativeSums.last ?? 0) + (bpm ?? 0))
        heartRateCumulativeCounts.append((heartRateCumulativeCounts.last ?? 0) + (bpm == nil ? 0 : 1))
    }

    private func resetSessionData(keepingCapacity: Bool) {
        accumulatedTime = 0
        elapsedTime = 0
        laps.removeAll(keepingCapacity: keepingCapacity)
        lapMetrics.removeAll(keepingCapacity: keepingCapacity)
        latestLapMetrics = nil
        maxBpm = nil
        distanceMeters = nil
        currentPaceSecondsPerKilometer = nil
        currentLapStartTime = 0
        currentLapStartSampleIndex = 0
        currentLapStartDistanceMeters = nil
        heartRateSamples.removeAll(keepingCapacity: keepingCapacity)
        heartRateCumulativeSums = [0]
        heartRateCumulativeCounts = [0]

        if keepingCapacity {
            heartRateSamples.reserveCapacity(initialHeartRateSampleCapacity)
            heartRateCumulativeSums.reserveCapacity(initialHeartRateSampleCapacity + 1)
            heartRateCumulativeCounts.reserveCapacity(initialHeartRateSampleCapacity + 1)
        }
    }

    private func makeLapMetrics(
        number: Int,
        startTime: TimeInterval,
        endTime: TimeInterval,
        startSampleIndex: Int,
        endSampleIndex: Int,
        startDistanceMeters: Double?,
        endDistanceMeters: Double?
    ) -> LapMetrics {
        let duration = max(0, endTime - startTime)
        let distance = distanceDelta(from: startDistanceMeters, to: endDistanceMeters)

        return LapMetrics(
            number: number,
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            averageBpm: averageBpm(from: startSampleIndex, to: endSampleIndex),
            averagePaceSecondsPerKilometer: averagePaceSecondsPerKilometer(duration: duration, distanceMeters: distance),
            distanceMeters: distance
        )
    }

    private func averageBpm(from startIndex: Int, to endIndex: Int) -> Int? {
        let lowerBound = max(0, min(startIndex, heartRateSamples.count))
        let upperBound = max(lowerBound, min(endIndex, heartRateSamples.count))
        guard heartRateCumulativeCounts.indices.contains(lowerBound),
              heartRateCumulativeCounts.indices.contains(upperBound),
              heartRateCumulativeSums.indices.contains(lowerBound),
              heartRateCumulativeSums.indices.contains(upperBound) else {
            return nil
        }

        let sampleCount = heartRateCumulativeCounts[upperBound] - heartRateCumulativeCounts[lowerBound]

        guard sampleCount > 0 else { return nil }

        let bpmSum = heartRateCumulativeSums[upperBound] - heartRateCumulativeSums[lowerBound]
        return Int((Double(bpmSum) / Double(sampleCount)).rounded())
    }

    private func averagePaceSecondsPerKilometer(duration: TimeInterval, distanceMeters: Double?) -> TimeInterval? {
        guard duration > 0, let distanceMeters, distanceMeters.isFinite, distanceMeters > 0 else { return nil }
        return duration / (distanceMeters / 1_000)
    }

    private func distanceDelta(from startDistanceMeters: Double?, to endDistanceMeters: Double?) -> Double? {
        guard let startDistanceMeters, let endDistanceMeters else { return nil }
        guard startDistanceMeters.isFinite, endDistanceMeters.isFinite else { return nil }
        return max(0, endDistanceMeters - startDistanceMeters)
    }
}
