import Foundation
import SwiftUI
import Combine
import ImagePlayground
import LiteRTLM

// MARK: - Models

struct AccountInfo: Codable, Equatable {
    var heightCm: String = ""
    var weightKg: String = ""
    var goals: String = ""
    var age: String = ""
    var gender: String = ""
    var activityLevel: String = ""
}

struct LastPerformance: Codable, Equatable {
    var weightKg: Int
    var reps: Int
    var date: Date = Date()
}

struct SessionStat: Codable, Equatable {
    var date: Date
    var totalVolume: Int
    var totalWeight: Int
    var totalReps: Int
    var setCount: Int

    var avgWeight: Double {
        guard setCount > 0 else { return 0 }
        return Double(totalWeight) / Double(setCount)
    }

    var avgReps: Double {
        guard setCount > 0 else { return 0 }
        return Double(totalReps) / Double(setCount)
    }
}

struct WorkoutExercise: Identifiable, Codable, Equatable {
    var exerciseId: String
    var name: String
    var sets: Int
    var targetReps: Int
    var imageUrl: String
    var videoUrl: String
    var description: String
    var localImagePath: String = ""

    var id: String { exerciseId }
}

struct WorkoutDay: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var heroImageUrl: String
    var localHeroImagePath: String = ""
    var exercises: [WorkoutExercise]
}

struct WorkoutPlan: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var description: String
    var days: [WorkoutDay]
}

struct ExerciseInput: Codable, Equatable {
    var name: String
    var sets: Int
    var reps: Int
}

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let byUser: Bool
    let text: String
}

// MARK: - Trainer Command Types

enum EditScope: Equatable {
    case allDays
    case specificDay(WorkoutDay)

    var displayTitle: String {
        switch self {
        case .allDays: return "All Days"
        case .specificDay(let day): return day.title
        }
    }
}

enum TrainerCommandMode: Equatable {
    case none
    case createWorkout
    case editWorkout(plan: WorkoutPlan, scope: EditScope)
}

private struct ExerciseSearchResponse: Codable {
    let success: Bool
    let data: [ExerciseDto]
}

private struct ExerciseDto: Codable {
    let exerciseId: String?
    let name: String?
    let imageUrl: String?
    let videoUrl: String?
    let overview: String?
    let instructions: [String]?
}

private struct PixabayResponse: Codable {
    let hits: [PixabayHit]
}

private struct PixabayHit: Codable {
    let webformatUrl: String?
    let largeImageUrl: String?

    private enum CodingKeys: String, CodingKey {
        case webformatUrl = "webformatURL"
        case largeImageUrl = "largeImageURL"
    }
}

// MARK: - LiteRT-LM Native Tool Calling

/// Shared context that lets Tool structs reach back into the app's view model.
/// Set once during GymViewModel.init(); never mutated after that.
final class GymToolContext: @unchecked Sendable {
    static let shared = GymToolContext()
    private init() {}
    weak var viewModel: GymViewModel?
}

/// Creates a new empty workout plan and returns its ID.
struct CreateWorkoutPlanTool: Tool {
    static let name = "create_workout_plan"
    static let description = "Creates a new workout plan and saves it to the user's 'Your Plans' page. Always call this first, then call add_workout_day for each training day."

    @ToolParam(description: "Display name for the plan, e.g. 'Push/Pull/Legs' or '4-Day Fat Loss'")
    var name: String = ""

    @ToolParam(description: "Short description of the plan's goal and structure")
    var description: String = ""

    func run() async throws -> Any {
        guard let vm = GymToolContext.shared.viewModel else {
            return ["success": false, "error": "App not ready"]
        }
        let planId = await vm.createWorkoutPlan(name: name, description: description)
        return ["success": true, "plan_id": planId]
    }
}

/// Lists all existing workout plans with their days and exercises.
struct ListWorkoutPlansTool: Tool {
    static let name = "list_workout_plans"
    static let description = "Returns all existing workout plans with their days and exercises. Call this first when the user wants to view, reference, or modify an existing plan."

    func run() async throws -> Any {
        guard let vm = GymToolContext.shared.viewModel else {
            return ["success": false, "error": "App not ready"]
        }
        let plans = await vm.listPlansData()
        return ["success": true, "plans": plans]
    }
}

/// Returns full details of a specific workout plan.
struct GetWorkoutPlanTool: Tool {
    static let name = "get_workout_plan"
    static let description = "Returns full details of a specific workout plan including all days and exercises."

    @ToolParam(description: "The plan_id of the plan to retrieve")
    var planId: String = ""

    func run() async throws -> Any {
        guard let vm = GymToolContext.shared.viewModel else {
            return ["success": false, "error": "App not ready"]
        }
        guard let planData = await vm.getPlanData(planId: planId) else {
            return ["success": false, "error": "Plan not found: \(planId)"]
        }
        return ["success": true, "plan": planData]
    }
}

/// Removes a training day from an existing plan.
struct RemoveWorkoutDayTool: Tool {
    static let name = "remove_workout_day"
    static let description = "Removes a training day from an existing plan. Call list_workout_plans first to get the correct plan_id and day_id."

    @ToolParam(description: "The plan_id containing the day to remove")
    var planId: String = ""

    @ToolParam(description: "The day_id of the training day to remove")
    var dayId: String = ""

    func run() async throws -> Any {
        guard let vm = GymToolContext.shared.viewModel else {
            return ["success": false, "error": "App not ready"]
        }
        await vm.removeWorkoutFromPlan(planId: planId, dayId: dayId)
        return ["success": true, "removed_day_id": dayId]
    }
}

/// Adds a single exercise to an existing training day.
struct AddExerciseToWorkoutTool: Tool {
    static let name = "add_exercise_to_workout"
    static let description = "Adds a single exercise to an existing training day. Call list_workout_plans first to get the correct plan_id and day_id."

    @ToolParam(description: "The plan_id containing the target day")
    var planId: String = ""

    @ToolParam(description: "The day_id of the training day to add the exercise to")
    var dayId: String = ""

    @ToolParam(description: "Name of the exercise, e.g. 'Bench Press'")
    var exerciseName: String = ""

    @ToolParam(description: "JSON string with sets and reps. Example: {\"sets\":4,\"reps\":8}")
    var setsRepsJson: String = "{\"sets\":3,\"reps\":10}"

    func run() async throws -> Any {
        guard let vm = GymToolContext.shared.viewModel else {
            return ["success": false, "error": "App not ready"]
        }
        var sets = 3
        var reps = 10
        if let data = setsRepsJson.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            sets = (dict["sets"] as? Int) ?? (dict["sets"] as? Double).map(Int.init) ?? 3
            reps = (dict["reps"] as? Int) ?? (dict["reps"] as? Double).map(Int.init) ?? 10
        }
        await vm.addExerciseToPlanDay(planId: planId, dayId: dayId, exerciseInput: ExerciseInput(name: exerciseName, sets: sets, reps: reps))
        return ["success": true, "exercise_name": exerciseName, "sets": sets, "reps": reps]
    }
}

/// Removes an exercise from a training day.
struct RemoveExerciseFromWorkoutTool: Tool {
    static let name = "remove_exercise_from_workout"
    static let description = "Removes an exercise from a training day. Call list_workout_plans first to get the correct plan_id, day_id, and exercise_id."

    @ToolParam(description: "The plan_id containing the exercise")
    var planId: String = ""

    @ToolParam(description: "The day_id containing the exercise")
    var dayId: String = ""

    @ToolParam(description: "The exercise_id of the exercise to remove")
    var exerciseId: String = ""

    func run() async throws -> Any {
        guard let vm = GymToolContext.shared.viewModel else {
            return ["success": false, "error": "App not ready"]
        }
        await vm.removeExerciseFromPlanDay(planId: planId, dayId: dayId, exerciseId: exerciseId)
        return ["success": true, "removed_exercise_id": exerciseId]
    }
}

/// Adds one training day (with exercises) to an existing plan.
struct AddWorkoutDayTool: Tool {
    static let name = "add_workout_day"
    static let description = "Adds one training day with exercises to an existing plan. Call once per training day after create_workout_plan."

    @ToolParam(description: "The plan_id returned by create_workout_plan")
    var planId: String = ""

    @ToolParam(description: "Title for this day, e.g. 'Monday – Push' or 'Day 1 – Chest & Triceps'")
    var dayTitle: String = ""

    @ToolParam(description: "JSON array of exercises. Each item must have: name (string), sets (number), reps (number). Example: [{\"name\":\"Bench Press\",\"sets\":4,\"reps\":8}]")
    var exercisesJson: String = ""

    func run() async throws -> Any {
        guard let vm = GymToolContext.shared.viewModel else {
            return ["success": false, "error": "App not ready"]
        }
        var inputs: [ExerciseInput] = []
        if let data = exercisesJson.data(using: .utf8),
           let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            inputs = array.compactMap { dict -> ExerciseInput? in
                guard let exerciseName = dict["name"] as? String else { return nil }
                let sets = (dict["sets"] as? Int) ?? (dict["sets"] as? Double).map(Int.init) ?? 3
                let reps = (dict["reps"] as? Int) ?? (dict["reps"] as? Double).map(Int.init) ?? 10
                return ExerciseInput(name: exerciseName, sets: sets, reps: reps)
            }
        }
        await vm.addWorkoutToPlan(planId: planId, dayTitle: dayTitle, exerciseInputs: inputs)
        return ["success": true, "day": dayTitle, "exerciseCount": inputs.count]
    }
}

private struct TrainerRequest: Codable {
    let message: String
    let history: [[String: String]]
    let goals: String
}

private struct TrainerResponse: Codable {
    let reply: String
}

private struct ToolCall {
    let name: String
    let args: [String: Any]
}

private enum WorkoutPlanTools {
    static let tools: [[String: Any]] = [
        [
            "name": "create_workout_plan",
            "description": "Creates a new, empty workout plan. Returns the generated plan_id.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "name": ["type": "string", "description": "Display name for the plan"],
                    "description": ["type": "string", "description": "Optional plan description"]
                ],
                "required": ["name"]
            ]
        ],
        [
            "name": "add_workout_to_plan",
            "description": "Adds a new workout day (with exercises) to an existing plan. Returns the day_id.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "plan_id": ["type": "string"],
                    "day_title": ["type": "string"],
                    "exercises": [
                        "type": "array",
                        "items": [
                            "type": "object",
                            "properties": [
                                "name": ["type": "string"],
                                "sets": ["type": "integer"],
                                "reps": ["type": "integer"]
                            ],
                            "required": ["name", "sets", "reps"]
                        ]
                    ]
                ],
                "required": ["plan_id", "day_title", "exercises"]
            ]
        ],
        [
            "name": "remove_workout_from_plan",
            "description": "Removes a workout day from a plan.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "plan_id": ["type": "string"],
                    "day_id": ["type": "string"]
                ],
                "required": ["plan_id", "day_id"]
            ]
        ],
        [
            "name": "add_exercise_to_workout",
            "description": "Adds a single exercise to an existing workout day within a plan.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "plan_id": ["type": "string"],
                    "day_id": ["type": "string"],
                    "exercise_name": ["type": "string"],
                    "sets": ["type": "integer"],
                    "reps": ["type": "integer"]
                ],
                "required": ["plan_id", "day_id", "exercise_name", "sets", "reps"]
            ]
        ],
        [
            "name": "remove_exercise_from_workout",
            "description": "Removes an exercise from a workout day within a plan.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "plan_id": ["type": "string"],
                    "day_id": ["type": "string"],
                    "exercise_id": ["type": "string"]
                ],
                "required": ["plan_id", "day_id", "exercise_id"]
            ]
        ],
        [
            "name": "list_workout_plans",
            "description": "Returns all user-created workout plans with their workout days.",
            "input_schema": [
                "type": "object",
                "properties": [:]
            ]
        ],
        [
            "name": "get_workout_plan",
            "description": "Returns full details of a specific workout plan.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "plan_id": ["type": "string"]
                ],
                "required": ["plan_id"]
            ]
        ]
    ]

    static var toolsJsonString: String {
        guard let data = try? JSONSerialization.data(withJSONObject: tools, options: [.prettyPrinted]),
              let text = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return text
    }

    static func ok(_ data: [String: Any] = [:]) -> String {
        let payload = ["success": true].merging(data) { _, new in new }
        guard let json = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return "{\"success\":true}"
        }
        return String(data: json, encoding: .utf8) ?? "{\"success\":true}"
    }

    static func err(_ message: String) -> String {
        let payload: [String: Any] = ["success": false, "error": message]
        guard let json = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return "{\"success\":false,\"error\":\"unknown\"}"
        }
        return String(data: json, encoding: .utf8) ?? "{\"success\":false,\"error\":\"unknown\"}"
    }
}

@MainActor
final class GymViewModel: ObservableObject {
    @Published var workoutPlans: [WorkoutPlan] = [] {
        didSet {
            saveWorkoutPlans()
        }
    }
    @Published var chatMessages: [ChatMessage] = [
        ChatMessage(byUser: false, text: "I am your personal trainer. Ask me about training, form, nutrition, or recovery.")
    ]
    @Published var isTrainerResponding = false
    @Published var isGeneratingPlan = false
    @Published var commandMode: TrainerCommandMode = .none
    @Published var accountInfo = AccountInfo() {
        didSet {
            saveAccountInfo()
        }
    }
    @Published var lastPerformance: [String: LastPerformance] = [:] {
        didSet {
            saveLastPerformance()
        }
    }
    @Published var exerciseHistory: [String: [SessionStat]] = [:] {
        didSet {
            saveExerciseHistory()
        }
    }

    private func saveLastPerformance() {
        if let encoded = try? JSONEncoder().encode(lastPerformance) {
            UserDefaults.standard.set(encoded, forKey: "gymbud_last_performance")
        }
    }

    private func saveExerciseHistory() {
        if let encoded = try? JSONEncoder().encode(exerciseHistory) {
            UserDefaults.standard.set(encoded, forKey: "gymbud_exercise_history")
        }
    }

    private func saveWorkoutPlans() {
        if let encoded = try? JSONEncoder().encode(workoutPlans) {
            UserDefaults.standard.set(encoded, forKey: "gymbud_workout_plans")
        }
    }

    private func saveAccountInfo() {
        if let encoded = try? JSONEncoder().encode(accountInfo) {
            UserDefaults.standard.set(encoded, forKey: "gymbud_account_info")
        }
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: "gymbud_last_performance"),
           let decoded = try? JSONDecoder().decode([String: LastPerformance].self, from: data) {
            self.lastPerformance = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "gymbud_exercise_history"),
           let decoded = try? JSONDecoder().decode([String: [SessionStat]].self, from: data) {
            self.exerciseHistory = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "gymbud_workout_plans"),
           let decoded = try? JSONDecoder().decode([WorkoutPlan].self, from: data) {
            self.workoutPlans = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "gymbud_account_info"),
           let decoded = try? JSONDecoder().decode(AccountInfo.self, from: data) {
            self.accountInfo = decoded
        }
    }

    private var exerciseCache: [String: ExerciseDto?] = [:]
    private var dayImageCache: [String: String] = [:]

    private let aiManager: AIManager
    let imageService: ImagePlaygroundService

    private let exerciseDbApiKey = "YOUR_EXERCISEDB_API_KEY"
    private let exerciseDbApiHost = "edb-with-videos-and-images-by-ascendapi.p.rapidapi.com"
    private let pixabayApiKey = "YOUR_PIXABAY_API_KEY"
    private let trainerServerBaseUrl = "http://127.0.0.1:8000/"

    private let fallbackImageUrl = "https://cdn.exercisedb.dev/media/images/CNKJtB2O5Y.webp"
    private let fallbackVideoUrl = "https://cdn.exercisedb.dev/videos/Trn4QDW/41n2hxnFMotsXTj3__Barbell-Bench-Press_Chest2_.mp4"
    private let fallbackDayImageUrl = "https://images.pexels.com/photos/841130/pexels-photo-841130.jpeg"
    private let unsplashSourceUrl = "https://source.unsplash.com/featured/?"

    private let workoutTemplates: [String: [ExerciseInput]] = [
        "Monday - Push": [
            ExerciseInput(name: "Bench Press", sets: 4, reps: 8),
            ExerciseInput(name: "Incline Dumbbell Press", sets: 3, reps: 10),
            ExerciseInput(name: "Triceps Pushdown", sets: 3, reps: 12)
        ],
        "Wednesday - Pull": [
            ExerciseInput(name: "Lat Pulldown", sets: 4, reps: 10),
            ExerciseInput(name: "Barbell Row", sets: 4, reps: 8),
            ExerciseInput(name: "Face Pull", sets: 3, reps: 12)
        ],
        "Friday - Legs": [
            ExerciseInput(name: "Back Squat", sets: 4, reps: 6),
            ExerciseInput(name: "Romanian Deadlift", sets: 3, reps: 8),
            ExerciseInput(name: "Leg Press", sets: 3, reps: 12)
        ]
    ]

    init(aiManager: AIManager, imageService: ImagePlaygroundService) {
        self.aiManager = aiManager
        self.imageService = imageService
        GymToolContext.shared.viewModel = self
        loadData()
        Task { await seedDefaultPlansIfNeeded() }
        // Pre-embed science sections in the background so semantic search is ready
        // by the time the user sends their first command.
        Task { await WorkoutScienceRAG.shared.precomputeSectionEmbeddings() }
    }

    func generateWorkoutPlan() {
        Task {
            await generateWorkoutPlanInternal()
        }
    }

    func sendChat(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        chatMessages.append(ChatMessage(byUser: true, text: trimmed))
        isTrainerResponding = true

        Task {
            let reply = await generateTrainerReply(
                userMessage: trimmed,
                goals: accountInfo.goals,
                recentMessages: Array(chatMessages.suffix(8))
            )
            chatMessages.append(ChatMessage(byUser: false, text: reply))
            isTrainerResponding = false
        }
    }

    // MARK: - Command Chat Dispatch

    func sendCommandChat(userIntent: String) {
        let mode = commandMode
        commandMode = .none
        switch mode {
        case .none:
            sendChat(userIntent)
        case .createWorkout:
            sendCreateWorkoutCommand(intent: userIntent)
        case .editWorkout(let plan, let scope):
            sendEditWorkoutCommand(plan: plan, scope: scope, intent: userIntent)
        }
    }

    private func sendCreateWorkoutCommand(intent: String) {
        let userDisplay = intent.isEmpty ? "a balanced multi-day workout plan" : intent
        chatMessages.append(ChatMessage(byUser: true, text: "/create workout — \(userDisplay)"))
        isTrainerResponding = true

        let planId = UUID().uuidString
        workoutPlans.append(WorkoutPlan(id: planId, name: "New Plan", description: "AI generated", days: []))

        let toolsJson = WorkoutPlanTools.toolsJsonString
        let profileJson = accountInfoJson()
        let profileSnapshot = accountInfo

        Task {
            let rag = WorkoutScienceRAG.shared
            let scienceSections = await rag.relevantSections(query: userDisplay, profile: profileSnapshot)
            let scienceContext = rag.formatForPrompt(scienceSections)

            let prompt = buildCreatePrompt(
                planId: planId,
                userDisplay: userDisplay,
                profileJson: profileJson,
                toolsJson: toolsJson,
                scienceContext: scienceContext
            )
            if let rawResponse = try? await aiManager.generateReply(prompt) {
                let (trainerNote, toolsText) = splitCommandResponse(rawResponse)
                let calls = parseToolCalls(from: toolsText.isEmpty ? rawResponse : toolsText)

                if !calls.isEmpty {
                    for call in calls {
                        if call.name == "create_workout_plan" {
                            if let name = call.args["name"] as? String,
                               let idx = workoutPlans.firstIndex(where: { $0.id == planId }) {
                                workoutPlans[idx] = WorkoutPlan(
                                    id: planId,
                                    name: name,
                                    description: call.args["description"] as? String ?? "AI generated",
                                    days: []
                                )
                            }
                            continue
                        }
                        var params = call.args
                        if params["plan_id"] == nil { params["plan_id"] = planId }
                        _ = await executeMcpTool(call.name, params: params)
                    }
                    let replyText = buildTrainerReply(
                        note: trainerNote,
                        sections: scienceSections,
                        fallback: "Your new workout plan is ready! Check the Plans tab."
                    )
                    chatMessages.append(ChatMessage(byUser: false, text: replyText))
                } else {
                    await buildFallbackPlan(planId: planId)
                    chatMessages.append(ChatMessage(byUser: false, text: "I built a starter plan for you — check the Plans tab!"))
                }
            } else {
                await buildFallbackPlan(planId: planId)
                chatMessages.append(ChatMessage(byUser: false, text: "Used a default template to get you started — check the Plans tab!"))
            }
            isTrainerResponding = false
        }
    }

    private func sendEditWorkoutCommand(plan: WorkoutPlan, scope: EditScope, intent: String) {
        let scopeLabel = scope.displayTitle
        chatMessages.append(ChatMessage(byUser: true, text: "/edit \(plan.name) [\(scopeLabel)] — \(intent)"))
        isTrainerResponding = true

        let xmlContext = workoutContextXml(plan: plan, scope: scope)
        let toolsJson = WorkoutPlanTools.toolsJsonString
        let profileSnapshot = accountInfo
        let planName = plan.name

        Task {
            let rag = WorkoutScienceRAG.shared
            let scienceSections = await rag.relevantSections(query: intent, profile: profileSnapshot)
            let scienceContext = rag.formatForPrompt(scienceSections)

            let prompt = buildEditPrompt(
                intent: intent,
                xmlContext: xmlContext,
                toolsJson: toolsJson,
                scienceContext: scienceContext
            )

            if let rawResponse = try? await aiManager.generateReply(prompt) {
                let (trainerNote, toolsText) = splitCommandResponse(rawResponse)
                let calls = parseToolCalls(from: toolsText.isEmpty ? rawResponse : toolsText)

                if !calls.isEmpty {
                    for call in calls {
                        _ = await executeMcpTool(call.name, params: call.args)
                    }
                    let replyText = buildTrainerReply(
                        note: trainerNote,
                        sections: scienceSections,
                        fallback: "Done! \(planName) has been updated. Check the Plans tab."
                    )
                    chatMessages.append(ChatMessage(byUser: false, text: replyText))
                } else {
                    let fallback = rawResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                    chatMessages.append(ChatMessage(byUser: false,
                        text: fallback.isEmpty ? "Couldn't process that edit — try describing the changes more specifically." : fallback))
                }
            } else {
                chatMessages.append(ChatMessage(byUser: false, text: "Having trouble right now. Please try again."))
            }
            isTrainerResponding = false
        }
    }

    // MARK: - Prompt Builders

    private func buildCreatePrompt(
        planId: String,
        userDisplay: String,
        profileJson: String,
        toolsJson: String,
        scienceContext: String
    ) -> String {
        let scienceBlock = scienceContext.isEmpty ? "" : """

        \(scienceContext)
        Apply the above science guidelines to produce an evidence-based plan. If the user has \
        specified a complete exercise structure, honor it directly and use the guidelines \
        only where they add value.

        """
        return """
        You are an expert personal trainer creating a new workout plan from scratch.
        \(scienceBlock)
        OUTPUT FORMAT — follow exactly, in this order:
        1. A line starting with "TRAINER_NOTE:" followed by 2-3 sentences explaining your \
        design choices and which science principles you applied (e.g. volume targets, \
        frequency rationale, load recommendations). Name specific principles by their \
        section title if you used them.
        2. A line containing only the text: TOOLS_BEGIN
        3. A raw JSON array of tool calls — no markdown fences, no extra text.

        DESIGN RULES:
        - Use plan_id "\(planId)" for ALL add_workout_to_plan calls.
        - Include ALL training days in ONE response — never ask for confirmation.
        - Create 3 to 5 training days. Each day: 3 to 6 exercises. Sets: 3–5. Reps: 6–15.
        - Distribute muscle groups across days to respect the per-session volume cap.
        - Exercise names must be specific and real (e.g. "Barbell Back Squat", not "Squats").

        Tool call format:
        [{"name": "add_workout_to_plan", "args": {"plan_id": "\(planId)", "day_title": "Day 1 – Push", "exercises": [{"name": "Barbell Bench Press", "sets": 4, "reps": 8}, {"name": "Overhead Press", "sets": 3, "reps": 10}]}}]

        Available tools:
        \(toolsJson)

        User profile: \(profileJson)
        User request: \(userDisplay)
        """
    }

    private func buildEditPrompt(
        intent: String,
        xmlContext: String,
        toolsJson: String,
        scienceContext: String
    ) -> String {
        let scienceBlock = scienceContext.isEmpty ? "" : """

        \(scienceContext)
        Apply the above guidelines when choosing replacement exercises, adjusting sets/reps, \
        or restructuring the plan. If the user's instructions are fully explicit, follow them \
        directly without deviation.

        """
        return """
        You are an expert personal trainer modifying an existing workout plan.
        \(scienceBlock)
        OUTPUT FORMAT — follow exactly, in this order:
        1. A line starting with "TRAINER_NOTE:" followed by 2-3 sentences summarising \
        the changes you are making and the science reasoning behind them. \
        Name specific principles by their section title if you applied them.
        2. A line containing only the text: TOOLS_BEGIN
        3. A raw JSON array of tool calls — no markdown fences, no extra text.

        MODIFICATION RULES:
        - Use the EXACT plan_id and day_id values from <workout_context> below.
        - All modifications in ONE response — never ask for confirmation.
        - To replace an exercise: call remove_exercise_from_workout then add_exercise_to_workout.
        - Do NOT call list_workout_plans, get_workout_plan, or create_workout_plan.

        Tool call format:
        [{"name": "tool_name", "args": {...}}, {"name": "tool_name", "args": {...}}]

        Available tools:
        \(toolsJson)

        Current workout data:
        \(xmlContext)

        User request: \(intent)
        """
    }

    // MARK: - Response Parsing Helpers

    // Splits the model's response into (trainerNote, toolCallsJson).
    // The model is instructed to separate them with "TOOLS_BEGIN" on its own line.
    // Falls back to empty note if the separator is absent.
    private func splitCommandResponse(_ raw: String) -> (note: String, toolsJson: String) {
        let separator = "TOOLS_BEGIN"
        if let range = raw.range(of: separator) {
            let notePart = String(raw[..<range.lowerBound])
                .replacingOccurrences(of: "TRAINER_NOTE:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let toolsPart = String(raw[range.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (notePart, toolsPart)
        }
        // Fallback: if there's a '[' that starts a JSON array, split there
        if let bracketRange = raw.range(of: "\n[") {
            let notePart = String(raw[..<bracketRange.lowerBound])
                .replacingOccurrences(of: "TRAINER_NOTE:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let toolsPart = String(raw[bracketRange.upperBound...])
            return (notePart, "[\(toolsPart)")
        }
        return ("", raw)
    }

    // Assembles the final trainer reply message with optional science citations.
    private func buildTrainerReply(note: String, sections: [ScienceSection], fallback: String) -> String {
        var parts: [String] = []

        let noteText = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !noteText.isEmpty {
            parts.append(noteText)
        } else {
            parts.append(fallback)
        }

        if !sections.isEmpty {
            let citationList = sections.map { "• \($0.title)" }.joined(separator: "\n")
            parts.append("─────────────────\nScience applied:\n\(citationList)")
        }

        return parts.joined(separator: "\n\n")
    }

    // Serialize plan (or subset of days) to XML for prompt injection
    private func workoutContextXml(plan: WorkoutPlan, scope: EditScope) -> String {
        let days: [WorkoutDay]
        switch scope {
        case .allDays: days = plan.days
        case .specificDay(let day): days = [day]
        }
        var xml = "<workout_context>\n"
        xml += "  <plan id=\"\(plan.id)\" name=\"\(plan.name.xmlEscaped)\">\n"
        for (i, day) in days.enumerated() {
            xml += "    <day_\(i + 1) id=\"\(day.id)\" title=\"\(day.title.xmlEscaped)\">\n"
            for ex in day.exercises {
                xml += "      <exercise id=\"\(ex.exerciseId)\" name=\"\(ex.name.xmlEscaped)\" sets=\"\(ex.sets)\" reps=\"\(ex.targetReps)\"/>\n"
            }
            xml += "    </day_\(i + 1)>\n"
        }
        xml += "  </plan>\n"
        xml += "</workout_context>"
        return xml
    }

    func recordSet(exerciseId: String, weightKg: Int, reps: Int) {
        lastPerformance[exerciseId] = LastPerformance(weightKg: weightKg, reps: reps)

        var history = exerciseHistory[exerciseId] ?? []
        let volume = weightKg * reps
        let now = Date()
        let daySeconds: TimeInterval = 24 * 60 * 60

        if history.isEmpty {
            history = [
                SessionStat(date: now.addingTimeInterval(-3 * daySeconds), totalVolume: Int(Double(volume) * 0.7), totalWeight: Int(Double(weightKg) * 0.8), totalReps: reps, setCount: 1),
                SessionStat(date: now.addingTimeInterval(-2 * daySeconds), totalVolume: Int(Double(volume) * 0.8), totalWeight: Int(Double(weightKg) * 0.9), totalReps: reps, setCount: 1),
                SessionStat(date: now.addingTimeInterval(-1 * daySeconds), totalVolume: Int(Double(volume) * 0.9), totalWeight: weightKg, totalReps: Int(Double(reps) * 0.9), setCount: 1),
                SessionStat(date: now, totalVolume: volume, totalWeight: weightKg, totalReps: reps, setCount: 1)
            ]
        } else {
            let last = history[history.count - 1]
            if Calendar.current.isDate(last.date, inSameDayAs: now) {
                history[history.count - 1] = SessionStat(
                    date: last.date,
                    totalVolume: last.totalVolume + volume,
                    totalWeight: last.totalWeight + weightKg,
                    totalReps: last.totalReps + reps,
                    setCount: last.setCount + 1
                )
            } else {
                history.append(SessionStat(
                    date: now,
                    totalVolume: volume,
                    totalWeight: weightKg,
                    totalReps: reps,
                    setCount: 1
                ))
            }
        }

        exerciseHistory[exerciseId] = history
    }

    func createWorkoutPlan(name: String, description: String = "") -> String {
        let plan = WorkoutPlan(id: UUID().uuidString, name: name, description: description, days: [])
        workoutPlans.append(plan)
        return plan.id
    }

    func addWorkoutToPlan(planId: String, dayTitle: String, exerciseInputs: [ExerciseInput]) async {
        let dayId = UUID().uuidString
        let exercises: [WorkoutExercise]

        if exerciseInputs.isEmpty {
            exercises = []
        } else {
            var mapped: [WorkoutExercise] = []
            for input in exerciseInputs {
                let ex = await mapTemplateToExercise(name: input.name, sets: input.sets, reps: input.reps)
                mapped.append(ex)
            }
            exercises = mapped
        }

        let newDay = WorkoutDay(id: dayId, title: dayTitle, heroImageUrl: "", localHeroImagePath: "", exercises: exercises)

        if let index = workoutPlans.firstIndex(where: { $0.id == planId }) {
            workoutPlans[index].days.append(newDay)
        }
    }

    func removeWorkoutFromPlan(planId: String, dayId: String) {
        guard let index = workoutPlans.firstIndex(where: { $0.id == planId }) else { return }
        workoutPlans[index].days.removeAll { $0.id == dayId }
    }

    func addExerciseToPlanDay(planId: String, dayId: String, exerciseInput: ExerciseInput) async {
        let exercise = await mapTemplateToExercise(name: exerciseInput.name, sets: exerciseInput.sets, reps: exerciseInput.reps)
        guard let planIndex = workoutPlans.firstIndex(where: { $0.id == planId }) else { return }
        guard let dayIndex = workoutPlans[planIndex].days.firstIndex(where: { $0.id == dayId }) else { return }
        workoutPlans[planIndex].days[dayIndex].exercises.append(exercise)
    }

    func removeExerciseFromPlanDay(planId: String, dayId: String, exerciseId: String) {
        guard let planIndex = workoutPlans.firstIndex(where: { $0.id == planId }) else { return }
        guard let dayIndex = workoutPlans[planIndex].days.firstIndex(where: { $0.id == dayId }) else { return }
        workoutPlans[planIndex].days[dayIndex].exercises.removeAll { $0.exerciseId == exerciseId }
    }

    func executeMcpTool(_ toolName: String, params: [String: Any]) async -> String {
        switch toolName {
        case "create_workout_plan":
            guard let name = params["name"] as? String else {
                return WorkoutPlanTools.err("missing required param: name")
            }
            let description = params["description"] as? String ?? ""
            let planId = createWorkoutPlan(name: name, description: description)
            return WorkoutPlanTools.ok(["plan_id": planId, "name": name])

        case "add_workout_to_plan":
            guard let planId = params["plan_id"] as? String else {
                return WorkoutPlanTools.err("missing required param: plan_id")
            }
            guard let dayTitle = params["day_title"] as? String else {
                return WorkoutPlanTools.err("missing required param: day_title")
            }
            guard let rawExercises = params["exercises"] as? [[String: Any]] else {
                return WorkoutPlanTools.err("missing required param: exercises")
            }

            if workoutPlans.first(where: { $0.id == planId }) == nil {
                return WorkoutPlanTools.err("plan not found: \(planId)")
            }

            let inputs = rawExercises.compactMap { ex -> ExerciseInput? in
                guard let name = ex["name"] as? String else { return nil }
                let sets = (ex["sets"] as? Double).map(Int.init) ?? (ex["sets"] as? Int) ?? 3
                let reps = (ex["reps"] as? Double).map(Int.init) ?? (ex["reps"] as? Int) ?? 10
                return ExerciseInput(name: name, sets: sets, reps: reps)
            }

            await addWorkoutToPlan(planId: planId, dayTitle: dayTitle, exerciseInputs: inputs)
            return WorkoutPlanTools.ok(["plan_id": planId, "title": dayTitle, "status": "loading"])

        case "remove_workout_from_plan":
            guard let planId = params["plan_id"] as? String else {
                return WorkoutPlanTools.err("missing required param: plan_id")
            }
            guard let dayId = params["day_id"] as? String else {
                return WorkoutPlanTools.err("missing required param: day_id")
            }
            removeWorkoutFromPlan(planId: planId, dayId: dayId)
            return WorkoutPlanTools.ok(["removed_day_id": dayId])

        case "add_exercise_to_workout":
            guard let planId = params["plan_id"] as? String else {
                return WorkoutPlanTools.err("missing required param: plan_id")
            }
            guard let dayId = params["day_id"] as? String else {
                return WorkoutPlanTools.err("missing required param: day_id")
            }
            guard let exerciseName = params["exercise_name"] as? String else {
                return WorkoutPlanTools.err("missing required param: exercise_name")
            }
            let sets = (params["sets"] as? Double).map(Int.init) ?? (params["sets"] as? Int) ?? 3
            let reps = (params["reps"] as? Double).map(Int.init) ?? (params["reps"] as? Int) ?? 10
            await addExerciseToPlanDay(planId: planId, dayId: dayId, exerciseInput: ExerciseInput(name: exerciseName, sets: sets, reps: reps))
            return WorkoutPlanTools.ok(["exercise_name": exerciseName, "status": "loading"])

        case "remove_exercise_from_workout":
            guard let planId = params["plan_id"] as? String else {
                return WorkoutPlanTools.err("missing required param: plan_id")
            }
            guard let dayId = params["day_id"] as? String else {
                return WorkoutPlanTools.err("missing required param: day_id")
            }
            guard let exerciseId = params["exercise_id"] as? String else {
                return WorkoutPlanTools.err("missing required param: exercise_id")
            }
            removeExerciseFromPlanDay(planId: planId, dayId: dayId, exerciseId: exerciseId)
            return WorkoutPlanTools.ok(["removed_exercise_id": exerciseId])

        case "list_workout_plans":
            let plans = workoutPlans.map { plan in
                [
                    "plan_id": plan.id,
                    "name": plan.name,
                    "description": plan.description,
                    "day_count": plan.days.count,
                    "days": plan.days.map { day in
                        [
                            "day_id": day.id,
                            "title": day.title,
                            "exercise_count": day.exercises.count
                        ]
                    }
                ] as [String: Any]
            }
            return WorkoutPlanTools.ok(["plans": plans])

        case "get_workout_plan":
            guard let planId = params["plan_id"] as? String else {
                return WorkoutPlanTools.err("missing required param: plan_id")
            }
            guard let plan = workoutPlans.first(where: { $0.id == planId }) else {
                return WorkoutPlanTools.err("plan not found: \(planId)")
            }
            let planData: [String: Any] = [
                "plan_id": plan.id,
                "name": plan.name,
                "description": plan.description,
                "days": plan.days.map { day in
                    [
                        "day_id": day.id,
                        "title": day.title,
                        "exercises": day.exercises.map { ex in
                            [
                                "exercise_id": ex.exerciseId,
                                "name": ex.name,
                                "sets": ex.sets,
                                "reps": ex.targetReps
                            ]
                        }
                    ]
                }
            ]
            return WorkoutPlanTools.ok(planData)

        default:
            return WorkoutPlanTools.err("unknown tool: \(toolName)")
        }
    }

    private func generateWorkoutPlanInternal() async {
        guard !isGeneratingPlan else { return }
        isGeneratingPlan = true
        defer { isGeneratingPlan = false }

        let planId = UUID().uuidString
        let planName = "Generated Plan"
        let plan = WorkoutPlan(id: planId, name: planName, description: "AI generated", days: [])
        workoutPlans.append(plan)

        let profileJson = accountInfoJson()
        let toolsJson = WorkoutPlanTools.toolsJsonString
        let prompt = """
        You are an expert trainer. Use the provided MCP tools to build a structured multi-day plan.
        Output ONLY JSON. No commentary or markdown.

        Tool call format:
        [ {\"name\": \"add_workout_to_plan\", \"args\": { ... } } ]

        Required rules:
        - Use plan_id: \(planId) for every add_workout_to_plan call.
        - Create 3 to 5 training days.
        - Each day should have 3 to 6 exercises.
        - Sets range 2 to 5, reps range 6 to 15.

        Tools schema:
        \(toolsJson)

        User profile JSON:
        \(profileJson)
        """

        if let toolCallsText = try? await aiManager.generateReply(prompt) {
            let calls = parseToolCalls(from: toolCallsText)
            if calls.isEmpty {
                await buildFallbackPlan(planId: planId)
                return
            }
            for call in calls {
                if call.name == "create_workout_plan" { continue }
                var params = call.args
                params["plan_id"] = planId
                _ = await executeMcpTool(call.name, params: params)
            }
        } else {
            await buildFallbackPlan(planId: planId)
        }
    }

    private func buildFallbackPlan(planId: String) async {
        for (title, inputs) in workoutTemplates {
            await addWorkoutToPlan(planId: planId, dayTitle: title, exerciseInputs: inputs)
        }
    }

    private func accountInfoJson() -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(accountInfo),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    private func generateTrainerReply(
        userMessage: String,
        goals: String,
        recentMessages: [ChatMessage]
    ) async -> String {
        // Try remote server first (if available)
        if let reply = try? await sendTrainerServerMessage(userMessage: userMessage, goals: goals, recentMessages: recentMessages),
           !reply.isEmpty {
            return reply
        }

        // Native function calling: the model decides whether to invoke
        // CreateWorkoutPlanTool / AddWorkoutDayTool or simply reply with text.
        // No keyword-based fallback — the model is the sole decision maker.
        let messageWithContext = goals.isEmpty ? userMessage : "My goal: \(goals)\n\n\(userMessage)"
        if let reply = try? await aiManager.generateReply(messageWithContext), !reply.isEmpty {
            return reply
        }

        return "I'm having trouble responding right now. Please try again in a moment."
    }

    private func sendTrainerServerMessage(
        userMessage: String,
        goals: String,
        recentMessages: [ChatMessage]
    ) async throws -> String {
        guard let url = URL(string: "\(trainerServerBaseUrl)trainer/chat") else { return "" }
        let history = recentMessages.map { [
            "role": $0.byUser ? "user" : "trainer",
            "text": $0.text
        ] }
        let requestBody = TrainerRequest(message: userMessage, history: history, goals: goals)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(TrainerResponse.self, from: data)
        return response.reply
    }

    private func buildTrainerPrompt(
        userMessage: String,
        goals: String,
        recentMessages: [ChatMessage]
    ) -> String {
        let history = recentMessages.map { message in
            message.byUser ? "User: \(message.text)" : "Trainer: \(message.text)"
        }.joined(separator: "\n")
        let goalLine = goals.isEmpty ? "No explicit goal saved." : goals

        return """
        You are a helpful gym trainer in a mobile app. Keep responses concise, practical, and safe.
        Give specific coaching steps and avoid medical diagnosis.
        User's saved goal: \(goalLine)

        Recent chat:
        \(history)

        Latest user message:
        \(userMessage)
        """
    }

    private func generateLocalTrainerReply(text: String, goals: String) -> String {
        let normalized = text.lowercased()
        if normalized.contains("bench") || normalized.contains("chest") {
            return "Keep your shoulder blades pinned back and drive your feet into the floor. Want a warm-up ramp for bench today?"
        }
        if normalized.contains("cut") || normalized.contains("fat") || normalized.contains("diet") {
            return "For fat loss, target a small calorie deficit, keep protein high, and keep your lifts progressive."
        }
        if normalized.contains("bulk") || normalized.contains("gain") {
            return "For lean gain, add 200-300 kcal per day and keep effort high in the 6-12 rep range for compounds."
        }
        if normalized.contains("rest") || normalized.contains("recover") {
            return "Recovery checklist: 7-9h sleep, hydration, 1-2 easy walks, and keep rest periods honest between sets."
        }
        if !goals.isEmpty {
            return "Since your goal is '\(goals)', prioritize consistency this week: hit all planned sessions and track every set."
        }
        return "Give me your current exercise, goal, and available equipment, and I will build a focused plan."
    }

    private func mapTemplateToExercise(name: String, sets: Int, reps: Int) async -> WorkoutExercise {
        let remote = await findExercise(query: name)
        let safeName = remote?.name ?? name
        let instructions = remote?.instructions?.joined(separator: " ")
        let description = remote?.overview ?? instructions ?? "Focus on controlled form and consistent tempo."

        return WorkoutExercise(
            exerciseId: remote?.exerciseId ?? "local_\(name.lowercased().replacingOccurrences(of: " ", with: "_"))",
            name: safeName,
            sets: sets,
            targetReps: reps,
            imageUrl: remote?.imageUrl ?? fallbackImageUrl,
            videoUrl: remote?.videoUrl ?? fallbackVideoUrl,
            description: description
        )
    }

    private func findExercise(query: String) async -> ExerciseDto? {
        let key = query.lowercased()
        if let cached = exerciseCache[key] {
            return cached
        }

        if exerciseDbApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            exerciseCache[key] = nil
            return nil
        }

        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://\(exerciseDbApiHost)/api/v1/exercises/search?search=\(encodedQuery)") else {
            exerciseCache[key] = nil
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(exerciseDbApiHost, forHTTPHeaderField: "x-rapidapi-host")
        if !exerciseDbApiKey.isEmpty {
            request.setValue(exerciseDbApiKey, forHTTPHeaderField: "x-rapidapi-key")
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(ExerciseSearchResponse.self, from: data)
            let result = response.data.first
            exerciseCache[key] = result
            return result
        } catch {
            exerciseCache[key] = nil
            return nil
        }
    }

    private func findDayImage(_ dayQuery: String) async -> String {
        let normalized = dayQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let cached = dayImageCache[normalized] {
            return cached
        }

        let pixabayKey = pixabayApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        var remoteImage: String? = nil

        if !pixabayKey.isEmpty,
           let encoded = encodeQuery("\(dayQuery) workout gym"),
           let url = URL(string: "https://pixabay.com/api/?key=\(pixabayKey)&q=\(encoded)&image_type=photo&category=sports&safesearch=true&per_page=3") {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(PixabayResponse.self, from: data)
                remoteImage = response.hits.first?.largeImageUrl ?? response.hits.first?.webformatUrl
            } catch {
                remoteImage = nil
            }
        }

        let finalImage: String
        if let remoteImage {
            finalImage = remoteImage
        } else if normalized.isEmpty {
            finalImage = fallbackDayImageUrl
        } else if let encoded = encodeQuery(normalized) {
            finalImage = "\(unsplashSourceUrl)\(encoded)%20workout%20gym"
        } else {
            finalImage = fallbackDayImageUrl
        }

        dayImageCache[normalized] = finalImage
        return finalImage
    }

    private func encodeQuery(_ text: String) -> String? {
        return text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    }

    private func parseToolCalls(from text: String) -> [ToolCall] {
        let cleaned = stripCodeFences(text)
        guard let jsonString = extractJson(from: cleaned),
              let data = jsonString.data(using: .utf8) else {
            return []
        }

        let json = try? JSONSerialization.jsonObject(with: data, options: [])
        if let array = json as? [[String: Any]] {
            return array.compactMap { parseToolCall(dict: $0) }
        }

        if let obj = json as? [String: Any], let calls = obj["tool_calls"] as? [[String: Any]] {
            return calls.compactMap { parseToolCall(dict: $0) }
        }

        return []
    }

    private func parseToolCall(dict: [String: Any]) -> ToolCall? {
        guard let name = dict["name"] as? String else { return nil }
        let args = dict["args"] as? [String: Any]
            ?? dict["input"] as? [String: Any]
            ?? dict["arguments"] as? [String: Any]
            ?? [:]
        return ToolCall(name: name, args: args)
    }

    private func stripCodeFences(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned.replacingOccurrences(of: "```json", with: "")
            cleaned = cleaned.replacingOccurrences(of: "```", with: "")
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return cleaned
    }

    private func extractJson(from text: String) -> String? {
        if let start = text.firstIndex(of: "["), let end = text.lastIndex(of: "]"), start < end {
            return String(text[start...end])
        }
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end {
            return String(text[start...end])
        }
        return nil
    }

    /// Update a specific exercise's local image path (used when Image Playground sheet generates a new image).
    func updateExerciseLocalImage(planId: String, dayId: String, exerciseId: String, localPath: String) {
        guard let planIndex = workoutPlans.firstIndex(where: { $0.id == planId }) else { return }
        guard let dayIndex = workoutPlans[planIndex].days.firstIndex(where: { $0.id == dayId }) else { return }
        guard let exIndex = workoutPlans[planIndex].days[dayIndex].exercises.firstIndex(where: { $0.exerciseId == exerciseId }) else { return }
        workoutPlans[planIndex].days[dayIndex].exercises[exIndex].localImagePath = localPath
    }

    /// Update a specific day's local hero image path.
    func updateDayLocalHeroImage(planId: String, dayId: String, localPath: String) {
        guard let planIndex = workoutPlans.firstIndex(where: { $0.id == planId }) else { return }
        guard let dayIndex = workoutPlans[planIndex].days.firstIndex(where: { $0.id == dayId }) else { return }
        workoutPlans[planIndex].days[dayIndex].localHeroImagePath = localPath
    }

    func listPlansData() -> [[String: Any]] {
        workoutPlans.map { plan in
            [
                "plan_id": plan.id,
                "name": plan.name,
                "description": plan.description,
                "days": plan.days.map { day in
                    [
                        "day_id": day.id,
                        "title": day.title,
                        "exercises": day.exercises.map { ex in
                            ["exercise_id": ex.exerciseId, "name": ex.name, "sets": ex.sets, "reps": ex.targetReps] as [String: Any]
                        }
                    ] as [String: Any]
                }
            ] as [String: Any]
        }
    }

    func getPlanData(planId: String) -> [String: Any]? {
        guard let plan = workoutPlans.first(where: { $0.id == planId }) else { return nil }
        return [
            "plan_id": plan.id,
            "name": plan.name,
            "description": plan.description,
            "days": plan.days.map { day in
                [
                    "day_id": day.id,
                    "title": day.title,
                    "exercises": day.exercises.map { ex in
                        ["exercise_id": ex.exerciseId, "name": ex.name, "sets": ex.sets, "reps": ex.targetReps] as [String: Any]
                    }
                ] as [String: Any]
            }
        ]
    }

    private func seedDefaultPlansIfNeeded() async {
        guard workoutPlans.isEmpty else { return }
        let planId = createWorkoutPlan(name: "Starter Plan", description: "Sample split to get going")
        for (title, inputs) in workoutTemplates {
            await addWorkoutToPlan(planId: planId, dayTitle: title, exerciseInputs: inputs)
        }
    }
}

private extension String {
    func substringAfter(_ token: String) -> String {
        guard let range = range(of: token) else { return self }
        return String(self[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var xmlEscaped: String {
        self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
