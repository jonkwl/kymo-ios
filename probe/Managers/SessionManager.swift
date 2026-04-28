import Observation
import ActivityKit
import Foundation
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
    var sensorManagerRef: SensorManager?
    
    private var timer: AnyCancellable?
    private var startTime: Date?
    private var accumulatedTime: TimeInterval = 0
    
    private var activity: Activity<SessionAttributes>?
    
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
        
        let attributes = SessionAttributes(sessionName: "Session")
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
        
        Task {
            await activity?.end(nil, dismissalPolicy: .immediate)
        }
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
                
                let currentBpm = self.sensorManagerRef?.currentBpm ?? 0
                
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
}
