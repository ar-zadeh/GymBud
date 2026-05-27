import SwiftUI
import UserNotifications

@main
struct GymBudApp: App {
    @StateObject private var aiManager: AIManager
    @StateObject private var phoneWatchConnector: PhoneWatchConnector
    @StateObject private var gymViewModel: GymViewModel
    @StateObject private var sessionManager = WorkoutSessionManager.shared

    private let imageService: ImagePlaygroundService

    init() {
        let ai = AIManager()
        let imgService = ImagePlaygroundService()
        _aiManager = StateObject(wrappedValue: ai)
        _phoneWatchConnector = StateObject(wrappedValue: PhoneWatchConnector.shared)
        _gymViewModel = StateObject(wrappedValue: GymViewModel(aiManager: ai, imageService: imgService))
        self.imageService = imgService
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(aiManager)
                .environmentObject(phoneWatchConnector)
                .environmentObject(gymViewModel)
                .environmentObject(sessionManager)
                .task {
                    try? await UNUserNotificationCenter.current()
                        .requestAuthorization(options: [.alert, .sound])
                    await imageService.configure()
                }
        }
    }
}
