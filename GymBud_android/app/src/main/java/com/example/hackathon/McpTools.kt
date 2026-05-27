package com.example.hackathon

import com.google.gson.Gson
import java.util.UUID

// ── Workout Plan model ────────────────────────────────────────────────────────

data class WorkoutPlan(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val description: String = "",
    val days: List<WorkoutDay> = emptyList()
)

/** Lightweight exercise spec the AI passes when building a plan day. */
data class ExerciseInput(
    val name: String,
    val sets: Int,
    val reps: Int
)

// ── MCP tool schema ───────────────────────────────────────────────────────────

data class McpTool(
    val name: String,
    val description: String,
    val inputSchema: Map<String, Any>
)

/**
 * Definitions for all workout-plan MCP tools.
 *
 * Call [toAnthropicFormat] to get the list ready to pass to the Claude API
 * `tools` parameter when you wire up the AI.
 */
object WorkoutPlanTools {

    private val gson = Gson()

    val tools: List<McpTool> = listOf(

        McpTool(
            name = "create_workout_plan",
            description = "Creates a new, empty workout plan. Returns the generated plan_id.",
            inputSchema = mapOf(
                "type" to "object",
                "properties" to mapOf(
                    "name" to mapOf(
                        "type" to "string",
                        "description" to "Display name for the plan (e.g. '5-Day Hypertrophy Split')"
                    ),
                    "description" to mapOf(
                        "type" to "string",
                        "description" to "Optional short description of the plan's goal or structure"
                    )
                ),
                "required" to listOf("name")
            )
        ),

        McpTool(
            name = "add_workout_to_plan",
            description = "Adds a new workout day (with exercises) to an existing plan. " +
                    "Returns the generated day_id.",
            inputSchema = mapOf(
                "type" to "object",
                "properties" to mapOf(
                    "plan_id" to mapOf(
                        "type" to "string",
                        "description" to "ID of the plan to add the day to"
                    ),
                    "day_title" to mapOf(
                        "type" to "string",
                        "description" to "Title for the workout day, e.g. 'Monday – Push'"
                    ),
                    "exercises" to mapOf(
                        "type" to "array",
                        "description" to "Exercises to include in this workout day",
                        "items" to mapOf(
                            "type" to "object",
                            "properties" to mapOf(
                                "name" to mapOf("type" to "string"),
                                "sets" to mapOf("type" to "integer"),
                                "reps" to mapOf("type" to "integer")
                            ),
                            "required" to listOf("name", "sets", "reps")
                        )
                    )
                ),
                "required" to listOf("plan_id", "day_title", "exercises")
            )
        ),

        McpTool(
            name = "remove_workout_from_plan",
            description = "Removes a workout day from a plan.",
            inputSchema = mapOf(
                "type" to "object",
                "properties" to mapOf(
                    "plan_id" to mapOf(
                        "type" to "string",
                        "description" to "ID of the plan"
                    ),
                    "day_id" to mapOf(
                        "type" to "string",
                        "description" to "ID of the workout day to remove"
                    )
                ),
                "required" to listOf("plan_id", "day_id")
            )
        ),

        McpTool(
            name = "add_exercise_to_workout",
            description = "Adds a single exercise to an existing workout day within a plan.",
            inputSchema = mapOf(
                "type" to "object",
                "properties" to mapOf(
                    "plan_id" to mapOf("type" to "string", "description" to "ID of the plan"),
                    "day_id" to mapOf("type" to "string", "description" to "ID of the workout day"),
                    "exercise_name" to mapOf(
                        "type" to "string",
                        "description" to "Name of the exercise to add"
                    ),
                    "sets" to mapOf("type" to "integer", "description" to "Number of sets"),
                    "reps" to mapOf("type" to "integer", "description" to "Target reps per set")
                ),
                "required" to listOf("plan_id", "day_id", "exercise_name", "sets", "reps")
            )
        ),

        McpTool(
            name = "remove_exercise_from_workout",
            description = "Removes an exercise from a workout day within a plan.",
            inputSchema = mapOf(
                "type" to "object",
                "properties" to mapOf(
                    "plan_id" to mapOf("type" to "string", "description" to "ID of the plan"),
                    "day_id" to mapOf("type" to "string", "description" to "ID of the workout day"),
                    "exercise_id" to mapOf(
                        "type" to "string",
                        "description" to "ID of the exercise to remove"
                    )
                ),
                "required" to listOf("plan_id", "day_id", "exercise_id")
            )
        ),

        McpTool(
            name = "list_workout_plans",
            description = "Returns all user-created workout plans with their workout days " +
                    "(day IDs, titles, and exercise counts).",
            inputSchema = mapOf(
                "type" to "object",
                "properties" to emptyMap<String, Any>()
            )
        ),

        McpTool(
            name = "get_workout_plan",
            description = "Returns full details of a specific workout plan including all " +
                    "exercises (IDs, names, sets, reps).",
            inputSchema = mapOf(
                "type" to "object",
                "properties" to mapOf(
                    "plan_id" to mapOf(
                        "type" to "string",
                        "description" to "ID of the plan to retrieve"
                    )
                ),
                "required" to listOf("plan_id")
            )
        )
    )

    /**
     * Returns the tool list in the format expected by the Claude API `tools` field.
     * Pass this directly when you set up the AI conversation.
     */
    fun toAnthropicFormat(): List<Map<String, Any>> = tools.map { tool ->
        mapOf(
            "name" to tool.name,
            "description" to tool.description,
            "input_schema" to tool.inputSchema
        )
    }

    // ── Helpers used by GymViewModel ─────────────────────────────────────────

    fun ok(data: Map<String, Any> = emptyMap()): String =
        gson.toJson(mapOf("success" to true) + data)

    fun err(message: String): String =
        gson.toJson(mapOf("success" to false, "error" to message))

    fun toJson(value: Any): String = gson.toJson(value)
}
