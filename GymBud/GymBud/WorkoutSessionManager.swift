import Foundation
import Combine
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

struct PendingProgress {
    let nextExerciseIndex: Int
    let nextSet: Int
    let label: String
}

struct WatchSubmission: Equatable {
    let weight: Int
    let reps: Int
}

final class WorkoutSessionManager: ObservableObject {
    static let shared = WorkoutSessionManager()

    deinit {
        #if os(iOS)
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        #endif
    }

    // Session identity
    @Published var dayTitle: String = ""
    @Published var exercises: [WorkoutExercise] = []

    // Progress
    @Published var currentExerciseIndex: Int = 0
    @Published var currentSet: Int = 1

    // Rest
    @Published var restSecondsLeft: Int = 0
    @Published var restSessionId: Int = 0
    @Published var pendingProgress: PendingProgress? = nil
    @Published var restJustFinished: Bool = false

    // Outcome
    @Published var isFinished: Bool = false

    let maxRestSeconds: Int = 75
    private var restTimer: AnyCancellable?

    // MARK: - Derived

    var currentExercise: WorkoutExercise? {
        guard !exercises.isEmpty, currentExerciseIndex < exercises.count else { return nil }
        return exercises[currentExerciseIndex]
    }

    var hasMoreSets: Bool {
        guard let ex = currentExercise else { return false }
        return currentSet < ex.sets
    }

    var hasNextExercise: Bool {
        currentExerciseIndex < exercises.count - 1
    }

    var restProgress: Double {
        guard maxRestSeconds > 0 else { return 0 }
        return 1.0 - (Double(restSecondsLeft) / Double(maxRestSeconds))
    }

    // MARK: - Session lifecycle

    func startSession(dayTitle: String, exercises: [WorkoutExercise]) {
        #if os(iOS)
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = true
            print("GymBud: Idle timer disabled - screen will stay awake")
        }
        #endif
        restTimer?.cancel()
        cancelRestNotification()
        self.dayTitle = dayTitle
        self.exercises = exercises
        currentExerciseIndex = 0
        currentSet = 1
        restSecondsLeft = 0
        restSessionId = 0
        pendingProgress = nil
        isFinished = false
        restJustFinished = false
    }

    func finishSession() {
        #if os(iOS)
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
            print("GymBud: Idle timer re-enabled - screen can sleep")
        }
        #endif
        restTimer?.cancel()
        cancelRestNotification()
        isFinished = true
    }

    /// Update the exercise list in-place (e.g. when an image path changes).
    func updateExercises(_ updated: [WorkoutExercise]) {
        exercises = updated
    }

    // MARK: - Rest

    func startRest(pending: PendingProgress) {
        restSessionId += 1
        pendingProgress = pending
        restSecondsLeft = maxRestSeconds
        restJustFinished = false
        startRestTimer()
        scheduleRestNotification(seconds: maxRestSeconds)
    }

    func skipRest() {
        restSecondsLeft = 0
        restTimer?.cancel()
        cancelRestNotification()
        applyPendingProgress()
    }

    func clearRestJustFinished() {
        restJustFinished = false
    }

    func applyPendingProgress() {
        guard let progress = pendingProgress, !isFinished else { return }
        currentExerciseIndex = progress.nextExerciseIndex
        currentSet = progress.nextSet
        pendingProgress = nil
    }

    private func startRestTimer() {
        restTimer?.cancel()
        restTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.restSecondsLeft > 0 {
                    self.restSecondsLeft -= 1
                    if self.restSecondsLeft == 0 {
                        self.restTimer?.cancel()
                        self.cancelRestNotification()
                        self.applyPendingProgress()
                        self.restJustFinished = true
                    }
                }
            }
    }

    // MARK: - Notifications

    private func scheduleRestNotification(seconds: Int) {
        cancelRestNotification()
        let content = UNMutableNotificationContent()
        content.title = "Rest Over"
        content.body = "Time for your next set!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(seconds),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "gymBudRest",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelRestNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["gymBudRest"]
        )
    }
}
