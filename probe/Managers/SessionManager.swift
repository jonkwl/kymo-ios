import Foundation
import Observation
import Combine

@Observable
class SessionManager {
    enum SessionState {
        case idle
        case recording
        case paused
    }
    
    // MARK: State
    var state: SessionState = .idle
    var elapsedTime: TimeInterval = 0
    var laps: [TimeInterval] = []
    
    private var timer: AnyCancellable?
    private var startTime: Date?
    private var accumulatedTime: TimeInterval = 0
    
    // MARK: Formatting
    var timeString: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) / 60 % 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02i:%02i:%02i", hours, minutes, seconds)
    }
    
    // MARK: Actions
    func startSession() {
        guard state == .idle else { return }
        state = .recording
        startTime = Date()
        runTimer()
    }
    
    func pauseSession() {
        guard state == .recording else { return }
        state = .paused
        accumulatedTime += Date().timeIntervalSince(startTime ?? Date())
        timer?.cancel()
    }
    
    func resumeSession() {
        guard state == .paused else { return }
        state = .recording
        startTime = Date()
        runTimer()
    }
    
    func stopSession() {
        timer?.cancel()
        state = .idle
        // TODO: logic for triggering save modal!
        accumulatedTime = 0
        elapsedTime = 0
        laps.removeAll()
    }
    
    func addLap() {
        laps.append(elapsedTime)
    }
    
    private func runTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let start = self.startTime else { return }
                self.elapsedTime = self.accumulatedTime + Date().timeIntervalSince(start)
            }
    }
}
