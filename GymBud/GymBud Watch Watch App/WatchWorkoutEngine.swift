import Foundation
import CoreMotion
import WatchConnectivity
import Combine
import WatchKit
import HealthKit

enum RepCountState {
    case idle
    case warmupCountdown
    case warmupRecording
    case counting
}

class WatchWorkoutEngine: NSObject, ObservableObject, WCSessionDelegate, WKExtendedRuntimeSessionDelegate, HKWorkoutSessionDelegate {
    
    static let shared = WatchWorkoutEngine()
    
    private var extendedSession: WKExtendedRuntimeSession?
    
    // UI State
    @Published var exerciseName: String = "Waiting for workout..."
    @Published var currentWeight: Int = 0
    @Published var currentReps: Int = 0
    @Published var restSecondsLeft: Int = 0
    @Published var restMaxSeconds: Int = 75
    @Published var gestureProgress: Int = 0

    // Rep tracking state
    @Published var repCountState: RepCountState = .idle
    @Published var warmupCountdown: Int = 5
    @Published var warmupRepsDetected: Int = 0
    @Published var isCalibrated: Bool = false
    @Published var fatigueModeEnabled: Bool = false
    private var firstRepDuration: TimeInterval = 0

    // Log set
    @Published var isShowingLogSet: Bool = false
    @Published var logSetWeight: Int = 0
    @Published var logSetReps: Int = 0
    
    // CoreMotion
    private let motionManager = CMMotionManager()
    private let motionQueue = OperationQueue()

    // HealthKit (keeps screen awake during workout — requires HealthKit entitlement)
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    
    // Constants
    private let warmupThreshold: Float = 0.6
    private let warmupReps: Int = 5
    private let flickThreshold: Double = 3.0
    private let gestureWindowMs: TimeInterval = 2.5
    private let cooldownMs: TimeInterval = 1.5
    private let gravityAlpha: Float = 0.85
    private let smoothAlpha: Float = 0.20
    
    // Variables
    private var calibAxis: Int = 1
    private var calibThreshold: Float = 1.0
    private var calibMinRepMs: TimeInterval = 0.3
    private var calibMaxRepMs: TimeInterval = 5.0
    
    private var wuSum = [Float](repeating: 0, count: 3)
    private var wuSumSq = [Float](repeating: 0, count: 3)
    private var wuN: Int = 0
    private var wuFirstRepTime: TimeInterval = 0
    private var wuLastRepTime: TimeInterval = 0
    private var wuRepPeakSpeeds: [Float] = []
    private var currentRepPeakSpeed: Float = 0
    private var avgWarmupPeakSpeed: Float = 0
    private var fastWarningSpeed: Float = 0
    private var minRepSpeed: Float = 0
    
    private enum Phase { case idle, up, down }
    private var phase: Phase = .idle
    private var halfReps: Int = 0
    private var cycleStart: TimeInterval = 0
    private var lastRepTime: TimeInterval = 0
    
    private var smooth = [Float](repeating: 0, count: 3)
    private var rawGravity = [Float](repeating: 0, count: 3)
    private var velocity: Float = 0.0
    private var lastProcessTime: TimeInterval = 0
    
    private var flickCount: Int = 0
    private var lastFlickTime: TimeInterval = 0
    private var lastFlickDir: Int = 0
    private var flickCooldownUntil: TimeInterval = 0
    
    private var countdownTimer: AnyCancellable?
    private var restCountdownTimer: AnyCancellable?
    private var currentRestSessionId = 0
    private var isRestSkipped = false
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    func startSensors() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 50.0
        motionQueue.maxConcurrentOperationCount = 1
        motionQueue.qualityOfService = .userInteractive
        // Use a background queue so updates keep arriving when the display sleeps
        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] (data, error) in
            guard let data = data, let self = self else { return }
            DispatchQueue.main.async { self.processSensorData(data) }
        }
        startExtendedSession()
        startHKWorkout()
    }

    func stopSensors() {
        motionManager.stopDeviceMotionUpdates()
        stopExtendedSession()
        stopHKWorkout()
    }

    // Starts an HKWorkoutSession so the system keeps the display alive (won't dim on wrist-down).
    // Requires the HealthKit capability to be enabled in the Watch app target in Xcode.
    private func startHKWorkout() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor
        healthStore.requestAuthorization(toShare: [HKObjectType.workoutType()], read: nil) { [weak self] granted, _ in
            guard let self = self, granted else { return }
            do {
                let session = try HKWorkoutSession(healthStore: self.healthStore, configuration: config)
                session.delegate = self
                self.workoutSession = session
                session.startActivity(with: Date())
            } catch {
                print("GymBud Watch: HKWorkoutSession start failed: \(error)")
            }
        }
    }

    private func stopHKWorkout() {
        workoutSession?.end()
        workoutSession = nil
    }

    // HKWorkoutSessionDelegate
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState, date: Date) {}
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("GymBud Watch: HKWorkoutSession error: \(error)")
    }
    
    private func processSensorData(_ data: CMDeviceMotion) {
        let now = Date().timeIntervalSince1970
        
        // Process Gyroscope for gestures
        let rotationX = data.rotationRate.x
        if rotationX > flickThreshold {
            recordFlick(dir: 1, now: now)
        } else if rotationX < -flickThreshold {
            recordFlick(dir: -1, now: now)
        }
        
        // Process Accelerometer (Linear Acceleration since CoreMotion removes gravity)
        let lin = [Float(data.userAcceleration.x * 9.81), Float(data.userAcceleration.y * 9.81), Float(data.userAcceleration.z * 9.81)]
        
        for i in 0..<3 {
            smooth[i] += smoothAlpha * (lin[i] - smooth[i])
        }

        // Integrate acceleration → velocity (leaky integrator prevents drift; ~2 s time constant at 50 Hz)
        let dt = lastProcessTime == 0 ? 0.02 : min(now - lastProcessTime, 0.1)
        lastProcessTime = now
        let axisIdx = isCalibrated ? calibAxis : 1
        velocity += smooth[axisIdx] * Float(dt)
        velocity *= 0.99

        // Send live data
        sendLiveDataToPhone(smooth[calibAxis])
        
        switch repCountState {
        case .warmupRecording:
            for i in 0..<3 {
                wuSum[i] += smooth[i]
                wuSumSq[i] += smooth[i] * smooth[i]
            }
            wuN += 1
            currentRepPeakSpeed = max(currentRepPeakSpeed, abs(velocity))

            runPhase(v: smooth[1], threshold: warmupThreshold, now: now) { [weak self] duration in
                guard let self = self else { return }
                if self.wuFirstRepTime == 0 { self.wuFirstRepTime = now }
                self.wuLastRepTime = now

                let peakSpeed = self.currentRepPeakSpeed
                self.currentRepPeakSpeed = 0

                DispatchQueue.main.async {
                    self.wuRepPeakSpeeds.append(peakSpeed)
                    self.warmupRepsDetected += 1
                    if self.warmupRepsDetected >= self.warmupReps {
                        self.finishWarmup()
                    }
                }
            }
            
        case .counting:
            currentRepPeakSpeed = max(currentRepPeakSpeed, abs(velocity))

            runPhase(v: smooth[calibAxis], threshold: calibThreshold, now: now) { [weak self] duration in
                guard let self = self else { return }
                let peakSpeed = self.currentRepPeakSpeed
                self.currentRepPeakSpeed = 0

                // Reject movement that is too slow compared to warmup — likely noise or a partial shift
                if self.minRepSpeed > 0 && peakSpeed < self.minRepSpeed { return }

                if duration >= self.calibMinRepMs && duration <= self.calibMaxRepMs {
                    let t = Date().timeIntervalSince1970
                    if t - self.lastRepTime > self.calibMinRepMs {
                        self.lastRepTime = t
                        DispatchQueue.main.async {
                            self.currentReps += 1
                            WKInterfaceDevice.current().play(.click)
                            if self.fatigueModeEnabled {
                                if self.firstRepDuration == 0 {
                                    self.firstRepDuration = duration
                                } else if duration >= (self.firstRepDuration / 0.7) {
                                    self.repCountState = .idle
                                    WKInterfaceDevice.current().play(.success)
                                    self.sendWorkoutDoneToPhone(weight: self.currentWeight, reps: self.currentReps)
                                }
                            }
                        }
                    }
                }
            }
            
        default:
            break
        }
    }
    
    private func runPhase(v: Float, threshold: Float, now: TimeInterval, onRep: @escaping (TimeInterval) -> Void) {
        switch phase {
        case .idle:
            if v > threshold {
                phase = .up
                cycleStart = now
            } else if v < -threshold {
                phase = .down
                cycleStart = now
            }
        case .up:
            if v < -threshold {
                phase = .down
                halfReps += 1
                if halfReps >= 2 {
                    onRep(now - cycleStart)
                    halfReps = 0
                    cycleStart = now
                }
            }
        case .down:
            if v > threshold {
                phase = .up
                halfReps += 1
                if halfReps >= 2 {
                    onRep(now - cycleStart)
                    halfReps = 0
                    cycleStart = now
                }
            }
        }
    }
    
    func showLogSet() {
        logSetWeight = currentWeight
        logSetReps = max(currentReps, 1)
        isShowingLogSet = true
    }

    func dismissLogSet() {
        isShowingLogSet = false
    }

    func submitLogSet() {
        let w = logSetWeight
        let r = logSetReps
        isShowingLogSet = false
        currentReps = 0
        firstRepDuration = 0
        repCountState = .idle
        resetPhase()
        sendWorkoutDoneToPhone(weight: w, reps: r)
    }

    func skipRest() {
        isRestSkipped = true
        restSecondsLeft = 0
        restCountdownTimer?.cancel()
        sendSkipRestToPhone()
    }

    func startCounting() {
        currentReps = 0
        firstRepDuration = 0
        lastRepTime = 0
        resetPhase()
        repCountState = .counting
    }

    private func startLocalRestCountdown() {
        restCountdownTimer?.cancel()
        guard restSecondsLeft > 0 else { return }
        restCountdownTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.restSecondsLeft > 1 {
                    self.restSecondsLeft -= 1
                } else {
                    self.restSecondsLeft = 0
                    self.restCountdownTimer?.cancel()
                    WKInterfaceDevice.current().play(.notification)
                }
            }
    }

    func startWarmup() {
        countdownTimer?.cancel()
        repCountState = .warmupCountdown
        warmupCountdown = 5
        
        countdownTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.warmupCountdown > 1 {
                    self.warmupCountdown -= 1
                } else {
                    self.countdownTimer?.cancel()
                    // Default haptic feedback here
                    
                    self.wuSum = [Float](repeating: 0, count: 3)
                    self.wuSumSq = [Float](repeating: 0, count: 3)
                    self.wuN = 0
                    self.wuFirstRepTime = 0
                    self.wuLastRepTime = 0
                    self.warmupRepsDetected = 0
                    self.wuRepPeakSpeeds = []
                    self.currentRepPeakSpeed = 0
                    self.resetPhase()
                    self.repCountState = .warmupRecording
                }
            }
    }
    
    func finishWarmup() {
        guard repCountState == .warmupRecording else { return }
        repCountState = .idle
        
        if wuN > 0 {
            let n = Float(wuN)
            var vars = [Float](repeating: 0, count: 3)
            for i in 0..<3 {
                let mean = wuSum[i] / n
                let variance = (wuSumSq[i] / n) - (mean * mean)
                vars[i] = max(variance, 0)
            }
            
            if let maxIndex = vars.firstIndex(of: vars.max() ?? 0) {
                calibAxis = maxIndex
            } else {
                calibAxis = 1
            }
            calibThreshold = max(0.35 * sqrt(vars[calibAxis]), 0.15)
        }
        
        let totalMs = wuLastRepTime - wuFirstRepTime
        let repCount = warmupRepsDetected
        if totalMs > 0 && repCount > 1 {
            let avgPeriod = totalMs / Double(repCount - 1)
            calibMinRepMs = max(avgPeriod / 3.0, 0.3)
            calibMaxRepMs = min(avgPeriod * 3.0, 10.0)
        } else {
            calibMinRepMs = 0.3
            calibMaxRepMs = 8.0
        }

        // Derive speed bounds from warmup peak speeds
        if !wuRepPeakSpeeds.isEmpty {
            avgWarmupPeakSpeed = wuRepPeakSpeeds.reduce(0, +) / Float(wuRepPeakSpeeds.count)
            fastWarningSpeed = avgWarmupPeakSpeed * 1.5   // warn if 50% faster than warmup average
            minRepSpeed = avgWarmupPeakSpeed * 0.25       // reject if only 25% of warmup speed (noise)
        }

        currentReps = 0
        lastRepTime = 0
        resetPhase()
        isCalibrated = true
        repCountState = .counting
    }
    
    private func resetPhase() {
        phase = .idle
        halfReps = 0
        cycleStart = 0
        smooth = [Float](repeating: 0, count: 3)
        velocity = 0.0
        lastProcessTime = 0
    }
    
    private func recordFlick(dir: Int, now: TimeInterval) {
        if now < flickCooldownUntil { return }
        
        if now - lastFlickTime > gestureWindowMs {
            flickCount = 0
        }
        
        if dir != lastFlickDir || flickCount == 0 {
            flickCount += 1
            lastFlickDir = dir
            lastFlickTime = now
            gestureProgress = flickCount
            
            // Play a click haptic for flick progress feedback
            WKInterfaceDevice.current().play(.click)
            
            if flickCount >= 4 {
                flickCooldownUntil = now + cooldownMs
                flickCount = 0
                gestureProgress = 0
                triggerGestureAction()
            }
        }
    }
    
    private func triggerGestureAction() {
        DispatchQueue.main.async {
            if self.restSecondsLeft > 0 {
                // Play success haptic for skipping rest
                WKInterfaceDevice.current().play(.success)
                self.skipRest()
            } else {
                // Play a distinct premium haptic sequence for concluding a set by flicking the wrist:
                // A satisfying success triple-pulse followed by a deep stop rumble
                WKInterfaceDevice.current().play(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    WKInterfaceDevice.current().play(.stop)
                }
                
                let w = self.currentWeight
                let r = max(self.currentReps, 1)
                self.isShowingLogSet = false
                self.currentReps = 0
                self.firstRepDuration = 0
                self.repCountState = .idle
                self.resetPhase()
                self.sendWorkoutDoneToPhone(weight: w, reps: r, isFlick: true)
            }
        }
    }
    
    // WatchConnectivity Stubs
    private var lastLiveDataSend: TimeInterval = 0

    private func sendLiveDataToPhone(_ value: Float) {
        guard WCSession.default.activationState == .activated else { return }
        let now = Date().timeIntervalSince1970
        guard now - lastLiveDataSend >= 0.05 else { return } // throttle to 20 Hz
        lastLiveDataSend = now

        let stateStr: String
        switch repCountState {
        case .idle:            stateStr = "idle"
        case .warmupCountdown: stateStr = "warmupCountdown"
        case .warmupRecording: stateStr = "warmupRecording"
        case .counting:        stateStr = "counting"
        }

        let message: [String: Any] = [
            "liveData": value,
            "liveSpeed": abs(velocity),
            "fastWarningSpeed": fastWarningSpeed,
            "watchState": stateStr,
            "warmupReps": warmupRepsDetected,
            "watchReps": currentReps
        ]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            do {
                try WCSession.default.updateApplicationContext(message)
            } catch {
                print("Failed to send context")
            }
        }
    }
    
    private func sendWorkoutDoneToPhone(weight: Int, reps: Int, isFlick: Bool = false) {
        guard WCSession.default.activationState == .activated else { return }
        
        let message: [String: Any] = ["action": "WORKOUT_DONE", "weight": weight, "reps": reps, "isFlick": isFlick]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            do {
                try WCSession.default.updateApplicationContext(message)
            } catch {
                print("Failed to send context")
            }
        }
    }
    
    private func sendSkipRestToPhone() {
        guard WCSession.default.activationState == .activated else { return }
        
        let message: [String: Any] = ["action": "SKIP_REST"]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            do {
                try WCSession.default.updateApplicationContext(message)
            } catch {
                print("Failed to send context")
            }
        }
    }
    
    // WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    
    // Receive messages from Phone
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            self.processMessage(message)
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            self.processMessage(applicationContext)
        }
    }
    
    private func processMessage(_ message: [String: Any]) {
        if let action = message["action"] as? String {
            switch action {
            case "START_WORKOUT":
                self.currentRestSessionId = 0
                self.isRestSkipped = false
                self.restSecondsLeft = 0
                self.restCountdownTimer?.cancel()
                if let exercise = message["exerciseName"] as? String {
                    if exercise != self.exerciseName {
                        self.isCalibrated = false
                        self.repCountState = .idle
                    }
                    self.exerciseName = exercise
                }
                if let weight = message["weight"] as? Int {
                    self.currentWeight = weight
                }
            case "REST_UPDATE":
                if let restSeconds = message["restSecondsLeft"] as? Int,
                   let sessionId = message["restSessionId"] as? Int {
                    
                    if sessionId > self.currentRestSessionId {
                        self.currentRestSessionId = sessionId
                        self.isRestSkipped = false
                        self.restMaxSeconds = restSeconds
                        self.restSecondsLeft = restSeconds
                        if restSeconds > 0 {
                            self.startLocalRestCountdown()
                        } else {
                            self.restCountdownTimer?.cancel()
                        }
                    } else if sessionId == self.currentRestSessionId {
                        if !self.isRestSkipped {
                            self.restSecondsLeft = restSeconds
                            if restSeconds > 0 {
                                self.startLocalRestCountdown()
                            } else {
                                self.restCountdownTimer?.cancel()
                            }
                        }
                    } else {
                        print("Ignoring stale rest update. Current ID: \(self.currentRestSessionId), received: \(sessionId)")
                    }
                }
            case "START_WARMUP":
                self.startWarmup()
            default:
                break
            }
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif

    // Extended Session Helpers
    private func startExtendedSession() {
        #if os(watchOS)
        guard extendedSession == nil else { return }
        extendedSession = WKExtendedRuntimeSession()
        extendedSession?.delegate = self
        extendedSession?.start()
        print("GymBud Watch: WKExtendedRuntimeSession started")
        #endif
    }
    
    private func stopExtendedSession() {
        #if os(watchOS)
        extendedSession?.invalidate()
        extendedSession = nil
        print("GymBud Watch: WKExtendedRuntimeSession stopped")
        #endif
    }

    // WKExtendedRuntimeSessionDelegate
    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        print("GymBud Watch: Extended session invalidated: \(reason.rawValue), error: \(String(describing: error))")
        self.extendedSession = nil
    }
    
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("GymBud Watch: Extended session started successfully")
    }
    
    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("GymBud Watch: Extended session will expire soon")
    }
}
