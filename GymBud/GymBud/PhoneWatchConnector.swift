import Foundation
import WatchConnectivity
import Combine

class PhoneWatchConnector: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = PhoneWatchConnector()
    
    @Published var currentWeight: Int = 0
    @Published var currentReps: Int = 0
    @Published var liveDataValue: Float = 0.0
    @Published var liveSpeedValue: Float = 0.0
    @Published var speedHistory: [Float] = []
    @Published var fastWarningSpeed: Float = 0.0
    @Published var skipRestTriggerToggle: Bool = false
    @Published var workoutDoneToggle: Bool = false
    @Published var isFlick: Bool = false

    // Watch rep-counter live state
    @Published var watchState: String = "idle"   // idle | warmupCountdown | warmupRecording | counting
    @Published var watchWarmupReps: Int = 0
    @Published var watchLiveReps: Int = 0
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    // Start workout on the watch
    func sendStartWorkoutInfo(exerciseName: String, startingWeight: Int) {
        guard WCSession.isSupported() else { return }
        
        let context: [String: Any] = ["action": "START_WORKOUT", "exerciseName": exerciseName, "weight": startingWeight]
        
        do {
            try WCSession.default.updateApplicationContext(context)
            print("Successfully updated application context with workout info")
        } catch {
            print("Error updating application context: \(error.localizedDescription)")
        }
        
        if WCSession.default.isReachable {
             WCSession.default.sendMessage(
                 context,
                 replyHandler: nil, errorHandler: { error in
                     print("Error sending message to watch: \(error.localizedDescription)")
                 }
             )
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("WCSession activation state on Phone: \(activationState.rawValue)")
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) { }
    
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            self.processMessage(applicationContext)
        }
    }
    
    // Receive messages from Watch
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            self.processMessage(message)
        }
    }
    
    private func processMessage(_ message: [String: Any]) {
        if let liveData = message["liveData"] as? Float {
            self.liveDataValue = liveData
        }
        if let speed = message["liveSpeed"] as? Float {
            self.liveSpeedValue = speed
            self.speedHistory.append(speed)
            if self.speedHistory.count > 150 { self.speedHistory.removeFirst() }
        }
        if let warn = message["fastWarningSpeed"] as? Float, warn > 0 {
            self.fastWarningSpeed = warn
        }
        if let state = message["watchState"] as? String {
            // Clear speed history at the start of each new counting session
            if state == "counting" && self.watchState != "counting" {
                self.speedHistory = []
                self.fastWarningSpeed = 0
            }
            self.watchState = state
        }
        if let warmupReps = message["warmupReps"] as? Int {
            self.watchWarmupReps = warmupReps
        }
        if let watchReps = message["watchReps"] as? Int {
            self.watchLiveReps = watchReps
        }
        
        if let action = message["action"] as? String {
            switch action {
            case "WORKOUT_DONE":
                if let reps = message["reps"] as? Int, let weight = message["weight"] as? Int {
                    self.currentWeight = weight
                    self.currentReps = reps
                    self.isFlick = message["isFlick"] as? Bool ?? false
                    self.workoutDoneToggle.toggle()
                    print("Workout Done from Watch! Reps: \(reps), Weight: \(weight), isFlick: \(self.isFlick)")
                }
            case "SKIP_REST":
                self.skipRestTriggerToggle.toggle()
                print("Skip rest requested from watch")
                WorkoutSessionManager.shared.skipRest()
                self.sendRestUpdate(seconds: 0, sessionId: WorkoutSessionManager.shared.restSessionId)
            default:
                break
            }
        }
    }
    
    func sendStartWarmup() {
        guard WCSession.isSupported() else { return }
        let message: [String: Any] = ["action": "START_WARMUP"]
        do {
            try WCSession.default.updateApplicationContext(message)
        } catch {}
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        }
    }

    // Send Rest Update to Watch
    func sendRestUpdate(seconds: Int, sessionId: Int) {
        guard WCSession.isSupported() else { return }
        
        let message: [String: Any] = [
            "action": "REST_UPDATE",
            "restSecondsLeft": seconds,
            "restSessionId": sessionId
        ]
        do {
            try WCSession.default.updateApplicationContext(message)
        } catch { }
        
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        }
    }
}
