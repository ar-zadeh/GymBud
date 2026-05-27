import Foundation
import Combine
import SwiftUI
import LiteRTLM // Needs to be added via Swift Package Manager

@MainActor
class AIManager: ObservableObject {
    @Published var chatHistory: [[String: String]] = []
    @Published var isLoading = false
    @Published var isModelLoaded = false
    
    private var engine: Engine?
    /// Single conversation with tools — LiteRT-LM only supports one session at a time.
    private var conversation: Conversation?

    private let systemPrompt = """
        You are a helpful personal trainer in a fitness app. Keep answers concise, practical, and safe.
        When the user asks you to create or generate a workout plan, use the create_workout_plan and add_workout_day tools to build it directly into their app — do not just describe the plan in text.
        When the user asks to see, view, or reference existing plans, call list_workout_plans first to get the current plans with their plan_id and day_id values.
        When the user asks to modify an existing plan (add/remove a day or exercise), call list_workout_plans first to find the correct plan_id and day_id, then use the appropriate tool: add_workout_day, remove_workout_day, add_exercise_to_workout, or remove_exercise_from_workout.
        After creating or modifying a plan, confirm the change to the user.
        """
    
    init() {
        Task {
            await initializeEngine()
        }
    }
    
    private func initializeEngine() async {
        do {
            isLoading = true
            
            // Note: In a real deploy, the gemma-4-E2B-it.litertlm must be added to the Xcode App bundle targets and copied as a resource.
            guard let modelPath = Bundle.main.path(forResource: "gemma-4-E2B-it", ofType: "litertlm") else {
                print("Model file not found in bundle! Make sure gemma-4-E2B-it.litertlm is added to the Xcode target.")
                isLoading = false
                return
            }
            
            // CPU backend avoids kIOGPUCommandBufferCallbackErrorBackgroundExecutionNotPermitted —
            // Metal GPU work is blocked on background threads that LiteRT-LM's engine threadpool uses.
            let config = try EngineConfig(
                modelPath: modelPath,
                backend: .cpu(),
                cacheDir: NSTemporaryDirectory()
            )
            
            engine = Engine(engineConfig: config)
            try await engine?.initialize()
            
            // Single conversation with tools registered for function calling.
            // The model decides whether to invoke tools or just reply with text.
            let conversationConfig = ConversationConfig(
                systemMessage: Message(systemPrompt),
                tools: [
                    CreateWorkoutPlanTool(),
                    AddWorkoutDayTool(),
                    ListWorkoutPlansTool(),
                    GetWorkoutPlanTool(),
                    RemoveWorkoutDayTool(),
                    AddExerciseToWorkoutTool(),
                    RemoveExerciseFromWorkoutTool()
                ]
            )
            conversation = try await engine?.createConversation(with: conversationConfig)

            isModelLoaded = (conversation != nil)
            isLoading = false
            print("LiteRT-LM Engine Initialized Successfully!")
        } catch {
            print("Failed to initialize LiteRT-LM Engine: \(error)")
            isLoading = false
        }
    }
    
    func sendMessage(_ text: String) {
        guard let conversation = conversation else {
            print("Conversation engine not ready.")
            return
        }
        
        // Append user message to UI
        self.chatHistory.append(["role": "user", "content": text])
        self.isLoading = true
        
        Task {
            do {
                let aiResponse = try await conversation.sendMessage(Message(text))
                self.chatHistory.append(["role": "assistant", "content": aiResponse.toString])
                self.isLoading = false
            } catch {
                print("AI generation failed: \(error)")
                self.chatHistory.append(["role": "assistant", "content": "Error generating response: \(error.localizedDescription)"])
                self.isLoading = false
            }
        }
    }

    /// Send a message through the single tools-enabled conversation.
    /// Used for both regular chat and workout plan generation.
    func generateReply(_ prompt: String) async throws -> String {
        guard let conversation = conversation else {
            throw NSError(domain: "AIManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Conversation engine not ready"])
        }
        let response = try await conversation.sendMessage(Message(prompt))
        return response.toString
    }
}
