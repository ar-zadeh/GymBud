package com.example.hackathon

import android.Manifest
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import android.app.Application
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.MediaStore
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.filled.SmartToy
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.Videocam
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedCard
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.RadioButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import android.widget.Toast
import com.google.android.gms.wearable.NodeClient
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Star
import androidx.compose.ui.draw.scale
import androidx.compose.ui.text.style.TextAlign
import com.google.gson.Gson
import java.io.File
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.google.gson.annotations.SerializedName
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import java.util.UUID
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.http.Body
import retrofit2.http.POST
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.GET
import retrofit2.http.Query
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.util.Locale
import java.text.SimpleDateFormat
import java.util.Date
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Color
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.pose.Pose
import com.google.mlkit.vision.pose.PoseDetection
import com.google.mlkit.vision.pose.PoseLandmark
import com.google.mlkit.vision.pose.accurate.AccuratePoseDetectorOptions
import kotlinx.coroutines.tasks.await
import androidx.compose.ui.graphics.asImageBitmap
import kotlinx.coroutines.yield
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable

private const val FALLBACK_IMAGE_URL = "https://cdn.exercisedb.dev/media/images/CNKJtB2O5Y.webp"
private const val FALLBACK_VIDEO_URL = "https://cdn.exercisedb.dev/videos/Trn4QDW/41n2hxnFMotsXTj3__Barbell-Bench-Press_Chest2_.mp4"
private const val FALLBACK_DAY_IMAGE_URL = "https://images.pexels.com/photos/841130/pexels-photo-841130.jpeg"
private const val UNSPLASH_SOURCE_URL = "https://source.unsplash.com/featured/?"
private const val REST_SECONDS = 75

private val Context.accountDataStore by preferencesDataStore(name = "gym_account")
private val HeightKey = stringPreferencesKey("height_cm")
private val WeightKey = stringPreferencesKey("weight_kg")
private val GoalsKey = stringPreferencesKey("goals")
private val AgeKey = stringPreferencesKey("age")
private val GenderKey = stringPreferencesKey("gender")
private val ActivityLevelKey = stringPreferencesKey("activity_level")

private enum class DashboardTab {
    Plans,
    Account,
    Trainer
}

data class UserProfile(
    val id: String,
    val displayName: String,
    val tier: String,
    val streakDays: Int
)

data class AccountInfo(
    val heightCm: String = "",
    val weightKg: String = "",
    val goals: String = "",
    val age: String = "",
    val gender: String = "",
    val activityLevel: String = ""
)

data class SessionStat(
    val dateMillis: Long,
    val totalVolume: Int,
    val totalWeight: Int,
    val totalReps: Int,
    val setCount: Int
) {
    val avgWeight: Float get() = if (setCount > 0) totalWeight.toFloat() / setCount else 0f
    val avgReps: Float get() = if (setCount > 0) totalReps.toFloat() / setCount else 0f
}

data class LastPerformance(
    val weightKg: Int,
    val reps: Int,
    val dateMillis: Long = System.currentTimeMillis()
)

private data class WorkoutTemplate(
    val query: String,
    val sets: Int,
    val targetReps: Int
)

private data class WorkoutDayTemplate(
    val id: String,
    val title: String,
    val templates: List<WorkoutTemplate>
)

data class WorkoutExercise(
    val exerciseId: String,
    val name: String,
    val sets: Int,
    val targetReps: Int,
    val imageUrl: String,
    val videoUrl: String,
    val description: String
)

data class WorkoutDay(
    val id: String,
    val title: String,
    val heroImageUrl: String,
    val exercises: List<WorkoutExercise>
)

data class ChatMessage(
    val byUser: Boolean,
    val text: String
)

private data class PendingProgress(
    val nextExerciseIndex: Int,
    val nextSet: Int,
    val label: String
)

data class GymUiState(
    val isLoading: Boolean = false,
    val isLoggedIn: Boolean = false,
    val profile: UserProfile? = null,
    val workoutDays: List<WorkoutDay> = emptyList(),
    val workoutPlans: List<WorkoutPlan> = emptyList(),
    val temporaryReplacements: Map<String, WorkoutExercise> = emptyMap(),
    val isReplacingExercise: Boolean = false,
    val accountInfo: AccountInfo = AccountInfo(),
    val lastPerformance: Map<String, LastPerformance> = emptyMap(),
    val exerciseHistory: Map<String, List<SessionStat>> = emptyMap(), 
    val recordedVideos: Map<String, String> = emptyMap(),
    val isTrainerResponding: Boolean = false,
    val chatMessages: List<ChatMessage> = listOf(
        ChatMessage(
            byUser = false,
            text = "I am Your Personal Trainer. Ask me for workout, form, nutrition, or recovery tips."
        )
    ),
    val errorMessage: String? = null
)

private data class ExerciseSearchResponse(
    val success: Boolean = false,
    val data: List<ExerciseDto> = emptyList()
)

private data class ExerciseDto(
    @SerializedName("exerciseId") val exerciseId: String? = null,
    @SerializedName("name") val name: String? = null,
    @SerializedName("imageUrl") val imageUrl: String? = null,
    @SerializedName("videoUrl") val videoUrl: String? = null,
    @SerializedName("overview") val overview: String? = null,
    @SerializedName("instructions") val instructions: List<String>? = null
)

private interface ExerciseDbService {
    @GET("api/v1/exercises/search")
    suspend fun searchExercises(@Query("search") query: String): ExerciseSearchResponse
}

private data class PixabayResponse(
    @SerializedName("hits") val hits: List<PixabayHit> = emptyList()
)

private data class PixabayHit(
    @SerializedName("webformatURL") val webformatUrl: String? = null,
    @SerializedName("largeImageURL") val largeImageUrl: String? = null
)

private interface PixabayService {
    @GET("api/")
    suspend fun searchImages(
        @Query("key") apiKey: String,
        @Query("q") query: String,
        @Query("image_type") imageType: String = "photo",
        @Query("category") category: String = "sports",
        @Query("safesearch") safeSearch: Boolean = true,
        @Query("per_page") pageSize: Int = 3
    ): PixabayResponse
}

private data class GeminiRequest(
    @SerializedName("contents") val contents: List<GeminiRequestContent>,
    @SerializedName("systemInstruction") val systemInstruction: GeminiRequestContent? = null,
    @SerializedName("tools") val tools: List<GeminiTool>? = null
)

private data class GeminiTool(
    @SerializedName("functionDeclarations") val functionDeclarations: List<GeminiFunctionDecl>
)

private data class GeminiFunctionDecl(
    @SerializedName("name") val name: String,
    @SerializedName("description") val description: String,
    @SerializedName("parameters") val parameters: Map<String, Any>
)

private data class GeminiRequestContent(
    @SerializedName("role") val role: String? = null,
    @SerializedName("parts") val parts: List<GeminiRequestPart>
)

private data class GeminiRequestPart(
    @SerializedName("text") val text: String? = null,
    @SerializedName("functionCall") val functionCall: GeminiFunctionCall? = null
)

private data class GeminiResponse(
    @SerializedName("candidates") val candidates: List<GeminiCandidate> = emptyList()
)

private data class GeminiCandidate(
    @SerializedName("content") val content: GeminiResponseContent? = null
)

private data class GeminiResponseContent(
    @SerializedName("parts") val parts: List<GeminiResponsePart> = emptyList()
)

private data class GeminiResponsePart(
    @SerializedName("text") val text: String? = null,
    @SerializedName("functionCall") val functionCall: GeminiFunctionCall? = null
)

private data class GeminiFunctionCall(
    @SerializedName("name") val name: String,
    @SerializedName("args") val args: Map<String, Any>
)

private interface GeminiService {
    @POST("v1beta/models/gemini-3.1-flash-lite-preview:generateContent")
    suspend fun generateContent(
        @Query("key") apiKey: String,
        @Body request: GeminiRequest
    ): GeminiResponse
}

private data class RemoteTrainerRequest(
    @SerializedName("message") val message: String,
    @SerializedName("history") val history: List<Map<String, String>>,
    @SerializedName("goals") val goals: String
)

private data class RemoteTrainerResponse(
    @SerializedName("reply") val reply: String
)

private interface RemoteTrainerService {
    @POST("trainer/chat")
    suspend fun sendChatMessage(@Body request: RemoteTrainerRequest): RemoteTrainerResponse
}

class GymViewModel(application: Application) : AndroidViewModel(application) {

    private val _uiState = MutableStateFlow(GymUiState())
    val uiState: StateFlow<GymUiState> = _uiState.asStateFlow()

    private val exerciseCache = mutableMapOf<String, ExerciseDto?>()
    private val dayImageCache = mutableMapOf<String, String>()

    private val workoutTemplates = listOf(
        WorkoutDayTemplate(
            id = "monday",
            title = "Monday - Push",
            templates = listOf(
                WorkoutTemplate("Bench Press", sets = 4, targetReps = 8),
                WorkoutTemplate("Incline Dumbbell Press", sets = 3, targetReps = 10),
                WorkoutTemplate("Triceps Pushdown", sets = 3, targetReps = 12)
            )
        ),
        WorkoutDayTemplate(
            id = "wednesday",
            title = "Wednesday - Pull",
            templates = listOf(
                WorkoutTemplate("Lat Pulldown", sets = 4, targetReps = 10),
                WorkoutTemplate("Barbell Row", sets = 4, targetReps = 8),
                WorkoutTemplate("Face Pull", sets = 3, targetReps = 12)
            )
        ),
        WorkoutDayTemplate(
            id = "friday",
            title = "Friday - Legs",
            templates = listOf(
                WorkoutTemplate("Back Squat", sets = 4, targetReps = 6),
                WorkoutTemplate("Romanian Deadlift", sets = 3, targetReps = 8),
                WorkoutTemplate("Leg Press", sets = 3, targetReps = 12)
            )
        )
    )

    private val baseCachedClient: OkHttpClient by lazy {
        val logger = HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BASIC
        }
        val cacheSize = (50 * 1024 * 1024).toLong() // 50MB cache for images and json
        val cache = okhttp3.Cache(getApplication<android.app.Application>().cacheDir, cacheSize)

        val cacheInterceptor = okhttp3.Interceptor { chain ->
            val request = chain.request()
            // Force cache usage if network is not providing it
            val response = chain.proceed(request)
            if (response.isSuccessful) {
                response.newBuilder()
                    .removeHeader("Pragma")
                    .removeHeader("Cache-Control")
                    .header("Cache-Control", "public, max-age=6048000") // heavily cache for 70 days
                    .build()
            } else {
                response
            }
        }

        OkHttpClient.Builder()
            .cache(cache)
            .addNetworkInterceptor(cacheInterceptor)
            // Add an interceptor to force read from cache if offline or to skip network if cached
            .addInterceptor { chain ->
                var request = chain.request()
                // Force cache for GET requests
                if (request.method == "GET") {
                    request = request.newBuilder()
                        .header("Cache-Control", "public, max-age=6048000")
                        .build()
                }
                chain.proceed(request)
            }
            .addInterceptor(logger)
            .build()
    }

    private val exerciseService: ExerciseDbService by lazy {
        val host = BuildConfig.EXERCISE_DB_API_HOST.ifBlank {
            "edb-with-videos-and-images-by-ascendapi.p.rapidapi.com"
        }
        val apiKey = BuildConfig.EXERCISE_DB_API_KEY
        
        val client = baseCachedClient.newBuilder()
            .addInterceptor { chain ->
                val builder = chain.request().newBuilder()
                    .header("Content-Type", "application/json")
                    .header("x-rapidapi-host", host)
                if (apiKey.isNotBlank()) {
                    builder.header("x-rapidapi-key", apiKey)
                }
                chain.proceed(builder.build())
            }
            .build()

        Retrofit.Builder()
            .baseUrl("https://$host/")
            .client(client)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(ExerciseDbService::class.java)
    }

    private val pixabayService: PixabayService by lazy {
        Retrofit.Builder()
            .baseUrl("https://pixabay.com/")
            .client(baseCachedClient)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(PixabayService::class.java)
    }

    private val geminiService: GeminiService by lazy {
        Retrofit.Builder()
            .baseUrl("https://generativelanguage.googleapis.com/")
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(GeminiService::class.java)
    }

    private val remoteTrainerService: RemoteTrainerService by lazy {
        Retrofit.Builder()
            // 10.0.2.2 is the special alias to your host loopback interface in Android Emulator
            .baseUrl("http://10.0.2.2:8000/")
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(RemoteTrainerService::class.java)
    }

    init {
        viewModelScope.launch {
            val saved = loadAccountInfo()
            _uiState.update { it.copy(accountInfo = saved) }

            // Whenever the state updates (which includes workout history, plans, profile, and account info changes),
            // serialize the entire context to the json file.
            _uiState.collect { state ->
                try {
                    val completeData = mapOf(
                        "accountInfo" to state.accountInfo,
                        "profile" to state.profile,
                        "workoutPlans" to state.workoutPlans,
                        "lastPerformance" to state.lastPerformance,
                        "exerciseHistory" to state.exerciseHistory,
                        "temporaryReplacements" to state.temporaryReplacements
                    )
                    val jsonFile = File(getApplication<Application>().filesDir, "account_settings.json")
                    jsonFile.writeText(Gson().toJson(completeData))
                } catch (e: Exception) {
                    android.util.Log.e("GymApp", "Failed to save complete user data to json", e)
                }
            }
        }
    }

    fun login(email: String, password: String) {
        if (email.isBlank() || password.isBlank()) {
            _uiState.update { it.copy(errorMessage = "Enter email and password to continue.") }
            return
        }

        _uiState.update { it.copy(isLoading = true, errorMessage = null) }
        viewModelScope.launch {
            delay(600)
            val profile = UserProfile(
                id = "athlete_001",
                displayName = email.substringBefore('@').replaceFirstChar { char ->
                    if (char.isLowerCase()) char.titlecase() else char.toString()
                },
                tier = "Pro Athlete",
                streakDays = 12
            )

            val days = withContext(Dispatchers.IO) {
                workoutTemplates.map { dayTemplate ->
                    val dayQuery = dayTemplate.title.substringAfter("-", dayTemplate.title).trim()
                    WorkoutDay(
                        id = dayTemplate.id,
                        title = dayTemplate.title,
                        heroImageUrl = findDayImage(dayQuery),
                        exercises = dayTemplate.templates.map { template ->
                            mapTemplateToExercise(template)
                        }
                    )
                }
            }

            _uiState.update {
                it.copy(
                    isLoading = false,
                    isLoggedIn = true,
                    profile = profile,
                    workoutDays = days,
                    errorMessage = null
                )
            }
        }
    }

    fun saveAccount(info: AccountInfo) {
        viewModelScope.launch {
            getApplication<Application>().accountDataStore.edit { prefs ->
                prefs[HeightKey] = info.heightCm
                prefs[WeightKey] = info.weightKg
                prefs[GoalsKey] = info.goals
                prefs[AgeKey] = info.age
                prefs[GenderKey] = info.gender
                prefs[ActivityLevelKey] = info.activityLevel
            }

            // the full state export will handle the json file explicitly now

            _uiState.update {
                it.copy(accountInfo = info)
            }
        }
    }

    fun generateRealtimeWorkoutPlan() {
        viewModelScope.launch {
            val app = getApplication<Application>()
            val geminiKey = BuildConfig.GEMINI_API_KEY.trim()
            if (geminiKey.isBlank()) return@launch

            val info = _uiState.value.accountInfo
            val userInfoStr = Gson().toJson(info)
            
            // Read MD Science Instructions if available from assets
            val mdContent = try {
                app.assets.open("science.md").bufferedReader().use { it.readText() }
            } catch (e: Exception) {
                "Provide a highly structured plan based on scientific training principles."
            }

            val geminiTools = WorkoutPlanTools.tools.map { tool ->
                GeminiFunctionDecl(
                    name = tool.name,
                    description = tool.description,
                    parameters = tool.inputSchema
                )
            }

val request = GeminiRequest(
                systemInstruction = GeminiRequestContent(
                    role = "system",
                    parts = listOf(GeminiRequestPart(text = "You are an expert trainer. Use the provided tools to create a structured workout plan. IMPORTANT: Do NOT output text. YOU MUST OUTPUT JSON USING 'add_workout_to_plan'. We will assume 'create_workout_plan' is already done, so you MUST immediately call 'add_workout_to_plan' multiple times containing all the exercises! to construct the plan payload. Here are the principles to follow:\n$mdContent"))
                ),
                contents = listOf(
                    GeminiRequestContent(
                        role = "user",
                        parts = listOf(GeminiRequestPart(text = "Generate a complete multi-day personalized workout plan for me using the mcp tools. My profile: $userInfoStr"))
                    )
                ),
                tools = listOf(GeminiTool(functionDeclarations = geminiTools))
            )

            _uiState.update { it.copy(isLoading = true) }

            try {
                // Initial generation call
                val response = geminiService.generateContent(
                    apiKey = geminiKey,
                    request = request
                )
                
                // Process tool calls (simulate the MCP execution loop locally for the UI)
                val newPlan = WorkoutPlan(id = java.util.UUID.randomUUID().toString(), name = "Generated Plan")
                var days = mutableListOf<WorkoutDay>()
                
                val parts = response.candidates.firstOrNull()?.content?.parts ?: emptyList()
                for (part in parts) {
                    val call = part.functionCall ?: continue
                    val args = call.args
                    
                    when (call.name) {
                        "create_workout_plan" -> {
                            // plan tracking
                        }
                        "add_workout_to_plan" -> {
                            val dayTitle = args["day_title"] as? String ?: "Workout Day"
                            val dayId = java.util.UUID.randomUUID().toString()
                            
                            val rawExercises = args["exercises"] as? List<Map<String,Any>> ?: emptyList()
                            val exercises = rawExercises.map {
                                WorkoutExercise(
                                    exerciseId = java.util.UUID.randomUUID().toString(),
                                    name = it["name"] as? String ?: "Exercise",
                                    sets = (it["sets"] as? Double)?.toInt() ?: 3,
                                    targetReps = (it["reps"] as? Double)?.toInt() ?: 10,
                                    imageUrl = "https://via.placeholder.com/300x200?text=Workout",
                                    videoUrl = "",
                                    description = "Perform with proper form."
                                )
                            }
                            
                            days.add(WorkoutDay(id = dayId, title = dayTitle, heroImageUrl = "https://via.placeholder.com/600x400?text=$dayTitle", exercises = exercises))
                        }
                    }
                }
                
                if (days.isNotEmpty()) {
                    val finalPlan = newPlan.copy(days = days)
                    _uiState.update { state ->
                        state.copy(workoutPlans = state.workoutPlans + finalPlan)
                    }
                }

            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                _uiState.update { it.copy(isLoading = false) }
            }
        }
    }

    fun replaceExerciseWithGemini(dayId: String, oldExercise: WorkoutExercise, isPermanent: Boolean) {
        viewModelScope.launch {
            _uiState.update { it.copy(isReplacingExercise = true) }
            val geminiKey = BuildConfig.GEMINI_API_KEY.trim()
            if (geminiKey.isBlank()) {
                _uiState.update { it.copy(isReplacingExercise = false) }
                return@launch
            }

val request = GeminiRequest(
                contents = listOf(
                    GeminiRequestContent(
                        role = "user",
                        parts = listOf(GeminiRequestPart(text = "Find an alternative exercise to replace '${oldExercise.name}' that activates similar muscle groups. Reply ONLY with the name of the new exercise, nothing else."))
                    )
                )
            )

            try {
                val response = geminiService.generateContent(
                    apiKey = geminiKey,
                    request = request
                )
                var newExerciseName = response.candidates.firstOrNull()?.content?.parts?.firstOrNull()?.text?.trim() ?: ""
                
                // Strip markdown formatting if any
                newExerciseName = newExerciseName.replace(Regex("[*#`]"), "").trim()

                if (newExerciseName.isNotBlank()) {
                    val newExercise = mapTemplateToExercise(WorkoutTemplate(newExerciseName, oldExercise.sets, oldExercise.targetReps))
                        .copy(exerciseId = if (isPermanent) java.util.UUID.randomUUID().toString() else oldExercise.exerciseId)
                    
                    if (isPermanent) {
                        _uiState.update { state ->
                            val updatedPlans = state.workoutPlans.map { plan ->
                                plan.copy(days = plan.days.map { day ->
                                    if (day.id == dayId) {
                                        day.copy(exercises = day.exercises.map {
                                            if (it.exerciseId == oldExercise.exerciseId) newExercise else it
                                        })
                                    } else day
                                })
                            }
                            val updatedDays = state.workoutDays.map { day ->
                                if (day.id == dayId) {
                                    day.copy(exercises = day.exercises.map {
                                        if (it.exerciseId == oldExercise.exerciseId) newExercise else it
                                    })
                                } else day
                            }
                            state.copy(workoutPlans = updatedPlans, workoutDays = updatedDays)
                        }
                    } else {
                        // Temporary replacement
                        _uiState.update { state ->
                            state.copy(temporaryReplacements = state.temporaryReplacements + (oldExercise.exerciseId to newExercise))
                        }
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                _uiState.update { it.copy(isReplacingExercise = false) }
            }
        }
    }

    fun recordSet(exerciseId: String, weightKg: Int, reps: Int) {
        _uiState.update { state ->
            val updated = state.lastPerformance.toMutableMap()
            updated[exerciseId] = LastPerformance(weightKg = weightKg, reps = reps)
            
            val updatedHistory = state.exerciseHistory.toMutableMap()
            val volume = weightKg * reps
            var history = updatedHistory[exerciseId]?.toMutableList()
            val now = System.currentTimeMillis()
            val dayMs = 24 * 60 * 60 * 1000L

            if (history == null) {
                // Mock historical sessions
                history = mutableListOf(
                    SessionStat(now - 3 * dayMs, (volume * 0.7).toInt(), (weightKg * 0.8).toInt(), reps, 1),
                    SessionStat(now - 2 * dayMs, (volume * 0.8).toInt(), (weightKg * 0.9).toInt(), reps, 1),
                    SessionStat(now - 1 * dayMs, (volume * 0.9).toInt(), weightKg, (reps * 0.9).toInt(), 1),
                    SessionStat(now, volume, weightKg, reps, 1)
                )
            } else {
                // Add to today's ongoing session volume
                val lastSession = history.last()
                history[history.lastIndex] = lastSession.copy(
                    totalVolume = lastSession.totalVolume + volume,
                    totalWeight = lastSession.totalWeight + weightKg,
                    totalReps = lastSession.totalReps + reps,
                    setCount = lastSession.setCount + 1
                )
            }
            updatedHistory[exerciseId] = history

            state.copy(
                lastPerformance = updated,
                exerciseHistory = updatedHistory
            )
        }
    }

    fun saveWorkoutVideo(exerciseId: String, videoUri: String) {
        _uiState.update {
            val updated = it.recordedVideos.toMutableMap()
            updated[exerciseId] = videoUri
            it.copy(recordedVideos = updated)
        }
    }

    // ── Workout Plan management ───────────────────────────────────────────────

    fun createWorkoutPlan(name: String, description: String = ""): String {
        val plan = WorkoutPlan(name = name, description = description)
        _uiState.update { it.copy(workoutPlans = it.workoutPlans + plan) }
        return plan.id
    }

    fun addWorkoutToPlan(planId: String, dayTitle: String, exerciseInputs: List<ExerciseInput>) {
        viewModelScope.launch {
            val plan = _uiState.value.workoutPlans.firstOrNull { it.id == planId } ?: return@launch
            val dayId = UUID.randomUUID().toString()
            val (exercises, heroImage) = withContext(Dispatchers.IO) {
                val exList = exerciseInputs.map { input ->
                    mapTemplateToExercise(WorkoutTemplate(input.name, input.sets, input.reps))
                }
                val img = findDayImage(dayTitle.substringAfter("-", dayTitle).trim())
                exList to img
            }
            val newDay = WorkoutDay(id = dayId, title = dayTitle, heroImageUrl = heroImage, exercises = exercises)
            _uiState.update { state ->
                state.copy(
                    workoutPlans = state.workoutPlans.map { p ->
                        if (p.id == planId) p.copy(days = p.days + newDay) else p
                    }
                )
            }
        }
    }

    fun removeWorkoutFromPlan(planId: String, dayId: String) {
        _uiState.update { state ->
            state.copy(
                workoutPlans = state.workoutPlans.map { plan ->
                    if (plan.id == planId) plan.copy(days = plan.days.filter { it.id != dayId })
                    else plan
                }
            )
        }
    }

    fun addExerciseToPlanDay(planId: String, dayId: String, exerciseInput: ExerciseInput) {
        viewModelScope.launch {
            val exercise = withContext(Dispatchers.IO) {
                mapTemplateToExercise(WorkoutTemplate(exerciseInput.name, exerciseInput.sets, exerciseInput.reps))
            }
            _uiState.update { state ->
                state.copy(
                    workoutPlans = state.workoutPlans.map { plan ->
                        if (plan.id != planId) return@map plan
                        plan.copy(
                            days = plan.days.map { day ->
                                if (day.id == dayId) day.copy(exercises = day.exercises + exercise) else day
                            }
                        )
                    }
                )
            }
        }
    }

    fun removeExerciseFromPlanDay(planId: String, dayId: String, exerciseId: String) {
        _uiState.update { state ->
            state.copy(
                workoutPlans = state.workoutPlans.map { plan ->
                    if (plan.id != planId) return@map plan
                    plan.copy(
                        days = plan.days.map { day ->
                            if (day.id == dayId) day.copy(exercises = day.exercises.filter { it.exerciseId != exerciseId })
                            else day
                        }
                    )
                }
            )
        }
    }

    // ── MCP tool dispatcher ───────────────────────────────────────────────────
    //
    // Call this from the AI integration layer. `params` is the tool's `input`
    // object deserialized to a Map (e.g. via Gson).  Returns a JSON string that
    // should be sent back as the tool_result content.

    @Suppress("UNCHECKED_CAST")
    suspend fun executeMcpTool(toolName: String, params: Map<String, Any>): String {
        return when (toolName) {

            "create_workout_plan" -> {
                val name = params["name"] as? String
                    ?: return WorkoutPlanTools.err("missing required param: name")
                val description = params["description"] as? String ?: ""
                val planId = createWorkoutPlan(name, description)
                WorkoutPlanTools.ok(mapOf("plan_id" to planId, "name" to name))
            }

            "add_workout_to_plan" -> {
                val planId = params["plan_id"] as? String
                    ?: return WorkoutPlanTools.err("missing required param: plan_id")
                val dayTitle = params["day_title"] as? String
                    ?: return WorkoutPlanTools.err("missing required param: day_title")
                val rawExercises = params["exercises"] as? List<Map<String, Any>>
                    ?: return WorkoutPlanTools.err("missing required param: exercises")

                if (_uiState.value.workoutPlans.none { it.id == planId }) {
                    return WorkoutPlanTools.err("plan not found: $planId")
                }

                val inputs = rawExercises.mapNotNull { ex ->
                    val n = ex["name"] as? String ?: return@mapNotNull null
                    val s = (ex["sets"] as? Double)?.toInt() ?: (ex["sets"] as? Int) ?: 3
                    val r = (ex["reps"] as? Double)?.toInt() ?: (ex["reps"] as? Int) ?: 10
                    ExerciseInput(n, s, r)
                }

                // addWorkoutToPlan launches its own coroutine; for the MCP result
                // we return the pending day_id immediately and let state update async.
                val dayId = UUID.randomUUID().toString()
                viewModelScope.launch {
                    val (exercises, heroImage) = withContext(Dispatchers.IO) {
                        val exList = inputs.map { input ->
                            mapTemplateToExercise(WorkoutTemplate(input.name, input.sets, input.reps))
                        }
                        val img = findDayImage(dayTitle.substringAfter("-", dayTitle).trim())
                        exList to img
                    }
                    val newDay = WorkoutDay(id = dayId, title = dayTitle, heroImageUrl = heroImage, exercises = exercises)
                    _uiState.update { state ->
                        state.copy(
                            workoutPlans = state.workoutPlans.map { p ->
                                if (p.id == planId) p.copy(days = p.days + newDay) else p
                            }
                        )
                    }
                }
                WorkoutPlanTools.ok(mapOf("day_id" to dayId, "title" to dayTitle, "status" to "loading"))
            }

            "remove_workout_from_plan" -> {
                val planId = params["plan_id"] as? String
                    ?: return WorkoutPlanTools.err("missing required param: plan_id")
                val dayId = params["day_id"] as? String
                    ?: return WorkoutPlanTools.err("missing required param: day_id")
                removeWorkoutFromPlan(planId, dayId)
                WorkoutPlanTools.ok(mapOf("removed_day_id" to dayId))
            }

            "add_exercise_to_workout" -> {
                val planId = params["plan_id"] as? String
                    ?: return WorkoutPlanTools.err("missing required param: plan_id")
                val dayId = params["day_id"] as? String
                    ?: return WorkoutPlanTools.err("missing required param: day_id")
                val exerciseName = params["exercise_name"] as? String
                    ?: return WorkoutPlanTools.err("missing required param: exercise_name")
                val sets = (params["sets"] as? Double)?.toInt() ?: (params["sets"] as? Int) ?: 3
                val reps = (params["reps"] as? Double)?.toInt() ?: (params["reps"] as? Int) ?: 10
                addExerciseToPlanDay(planId, dayId, ExerciseInput(exerciseName, sets, reps))
                WorkoutPlanTools.ok(mapOf("exercise_name" to exerciseName, "status" to "loading"))
            }

            "remove_exercise_from_workout" -> {
                val planId = params["plan_id"] as? String
                    ?: return WorkoutPlanTools.err("missing required param: plan_id")
                val dayId = params["day_id"] as? String
                    ?: return WorkoutPlanTools.err("missing required param: day_id")
                val exerciseId = params["exercise_id"] as? String
                    ?: return WorkoutPlanTools.err("missing required param: exercise_id")
                removeExerciseFromPlanDay(planId, dayId, exerciseId)
                WorkoutPlanTools.ok(mapOf("removed_exercise_id" to exerciseId))
            }

            "list_workout_plans" -> {
                val plans = _uiState.value.workoutPlans.map { plan ->
                    mapOf(
                        "plan_id" to plan.id,
                        "name" to plan.name,
                        "description" to plan.description,
                        "day_count" to plan.days.size,
                        "days" to plan.days.map { day ->
                            mapOf(
                                "day_id" to day.id,
                                "title" to day.title,
                                "exercise_count" to day.exercises.size
                            )
                        }
                    )
                }
                WorkoutPlanTools.ok(mapOf("plans" to plans))
            }

            "get_workout_plan" -> {
                val planId = params["plan_id"] as? String
                    ?: return WorkoutPlanTools.err("missing required param: plan_id")
                val plan = _uiState.value.workoutPlans.firstOrNull { it.id == planId }
                    ?: return WorkoutPlanTools.err("plan not found: $planId")
                val planData = mapOf(
                    "plan_id" to plan.id,
                    "name" to plan.name,
                    "description" to plan.description,
                    "days" to plan.days.map { day ->
                        mapOf(
                            "day_id" to day.id,
                            "title" to day.title,
                            "exercises" to day.exercises.map { ex ->
                                mapOf(
                                    "exercise_id" to ex.exerciseId,
                                    "name" to ex.name,
                                    "sets" to ex.sets,
                                    "reps" to ex.targetReps
                                )
                            }
                        )
                    }
                )
                WorkoutPlanTools.ok(planData)
            }

            else -> WorkoutPlanTools.err("unknown tool: $toolName")
        }
    }

    fun sendChat(text: String) {
        val trimmed = text.trim()
        if (trimmed.isBlank()) return

        _uiState.update {
            it.copy(
                chatMessages = it.chatMessages + ChatMessage(byUser = true, text = trimmed),
                isTrainerResponding = true
            )
        }

        viewModelScope.launch {
            val stateSnapshot = _uiState.value
            val botReply = withContext(Dispatchers.IO) {
                generateTrainerReply(
                    userMessage = trimmed,
                    goals = stateSnapshot.accountInfo.goals,
                    recentMessages = stateSnapshot.chatMessages.takeLast(8)
                )
            }
            _uiState.update {
                it.copy(
                    chatMessages = it.chatMessages + ChatMessage(byUser = false, text = botReply),
                    isTrainerResponding = false
                )
            }
        }
    }

    private suspend fun loadAccountInfo(): AccountInfo {
        // We could read from DataStore or from the JSON file. We'll read from DataStore 
        // to maintain continuity but the file exists here:
        // /data/user/0/com.example.hackathon/files/account_settings.json
        val prefs = getApplication<Application>().accountDataStore.data.first()
        return AccountInfo(
            heightCm = prefs[HeightKey] ?: "",
            weightKg = prefs[WeightKey] ?: "",
            goals = prefs[GoalsKey] ?: "",
            age = prefs[AgeKey] ?: "",
            gender = prefs[GenderKey] ?: "",
            activityLevel = prefs[ActivityLevelKey] ?: ""
        )
    }

    private suspend fun mapTemplateToExercise(template: WorkoutTemplate): WorkoutExercise {
        val remote = findExercise(template.query)
        val safeName = remote?.name ?: template.query
        val instructions = remote?.instructions?.takeIf { it.isNotEmpty() }?.joinToString(" ")
        val description = remote?.overview
            ?: instructions
            ?: "Focus on controlled form, full range of motion, and consistent tempo."

        return WorkoutExercise(
            exerciseId = remote?.exerciseId ?: "local_${template.query.lowercase().replace(' ', '_')}",
            name = safeName,
            sets = template.sets,
            targetReps = template.targetReps,
            imageUrl = remote?.imageUrl ?: FALLBACK_IMAGE_URL,
            videoUrl = remote?.videoUrl ?: FALLBACK_VIDEO_URL,
            description = description
        )
    }

    private suspend fun findExercise(query: String): ExerciseDto? {
        val key = query.lowercase()
        if (exerciseCache.containsKey(key)) return exerciseCache[key]
        if (BuildConfig.EXERCISE_DB_API_KEY.isBlank()) {
            exerciseCache[key] = null
            return null
        }

        return try {
            val response = exerciseService.searchExercises(query)
            val result = response.data.firstOrNull()
            exerciseCache[key] = result
            result
        } catch (_: Exception) {
            exerciseCache[key] = null
            null
        }
    }

    private suspend fun findDayImage(dayQuery: String): String {
        val normalized = dayQuery.lowercase()
        dayImageCache[normalized]?.let { return it }

        val pixabayKey = BuildConfig.PIXABAY_API_KEY.trim()
        val remoteImage = if (pixabayKey.isNotBlank()) {
            try {
                val response = pixabayService.searchImages(
                    apiKey = pixabayKey,
                    query = "$dayQuery workout gym"
                )
                response.hits.firstOrNull()?.largeImageUrl ?: response.hits.firstOrNull()?.webformatUrl
            } catch (_: Exception) {
                null
            }
        } else {
            null
        }

        val finalImage = remoteImage
            ?: if (dayQuery.isBlank()) {
                FALLBACK_DAY_IMAGE_URL
            } else {
                "$UNSPLASH_SOURCE_URL${encodeQuery(dayQuery)}%20workout%20gym"
            }

        dayImageCache[normalized] = finalImage
        return finalImage
    }

    private suspend fun generateTrainerReply(
        userMessage: String,
        goals: String,
        recentMessages: List<ChatMessage>
    ): String {
        // Option 1: Try Remote Custom Trainer Server first (via http://10.0.2.2:8000)
        try {
            val history = recentMessages.map { 
                mapOf("role" to if (it.byUser) "user" else "trainer", "text" to it.text)
            }
            val remoteResponse = remoteTrainerService.sendChatMessage(
                RemoteTrainerRequest(
                    message = userMessage,
                    history = history,
                    goals = goals
                )
            )
            if (remoteResponse.reply.isNotBlank()) {
                return remoteResponse.reply
            }
        } catch (e: Exception) {
            // Server might not be running or reachable, fallback to Gemini or local
            android.util.Log.e("Trainer", "Failed to reach remote server, falling back to Gemini", e)
        }

        val geminiKey = BuildConfig.GEMINI_API_KEY.trim()
        if (geminiKey.isBlank()) {
            return generateLocalTrainerReply(userMessage, goals)
        }

        return try {
            val prompt = buildTrainerPrompt(
                userMessage = userMessage,
                goals = goals,
                recentMessages = recentMessages
            )
            val response = geminiService.generateContent(
                apiKey = geminiKey,
                request = GeminiRequest(
                    contents = listOf(
                        GeminiRequestContent(parts = listOf(GeminiRequestPart(text = prompt)))
                    )
                )
            )

            val content = response.candidates
                .firstOrNull()
                ?.content
                ?.parts
                ?.firstOrNull()
                ?.text
                ?.trim()

            if (content.isNullOrBlank()) {
                generateLocalTrainerReply(userMessage, goals)
            } else {
                content
            }
        } catch (_: Exception) {
            generateLocalTrainerReply(userMessage, goals)
        }
    }

    private fun buildTrainerPrompt(
        userMessage: String,
        goals: String,
        recentMessages: List<ChatMessage>
    ): String {
        val history = recentMessages.joinToString("\n") { message ->
            if (message.byUser) "User: ${message.text}" else "Trainer: ${message.text}"
        }
        val goalLine = if (goals.isBlank()) "No explicit goal saved." else goals

        return """
            You are a helpful gym trainer in a mobile app. Keep responses concise, practical, and safe.
            Give specific coaching steps and avoid medical diagnosis.
            User's saved goal: $goalLine

            Recent chat:
            $history

            Latest user message:
            $userMessage
        """.trimIndent()
    }

    private fun generateLocalTrainerReply(text: String, goals: String): String {
        val normalized = text.lowercase()
        return when {
            "bench" in normalized || "chest" in normalized -> {
                "Keep your shoulder blades pinned back and drive your feet into the floor. Want a warm-up ramp for bench today?"
            }

            "cut" in normalized || "fat" in normalized || "diet" in normalized -> {
                "For fat loss, target a small calorie deficit, keep protein high, and keep your lifts progressive."
            }

            "bulk" in normalized || "gain" in normalized -> {
                "For lean gain, add 200-300 kcal per day and keep effort high in the 6-12 rep range for compounds."
            }

            "rest" in normalized || "recover" in normalized -> {
                "Recovery checklist: 7-9h sleep, hydration, 1-2 easy walks, and keep rest periods honest between sets."
            }

            goals.isNotBlank() -> {
                "Since your goal is '$goals', prioritize consistency this week: hit all planned sessions and track every set."
            }

            else -> {
                "Great question. Give me your current exercise, goal, and available equipment, and I will build a focused plan."
            }
        }
    }

    private fun encodeQuery(text: String): String {
        return try {
            URLEncoder.encode(text, StandardCharsets.UTF_8.toString()).replace("+", "%20")
        } catch (_: Exception) {
            "fitness"
        }
    }
}

@Composable
fun GymApp() {
    val gymViewModel: GymViewModel = viewModel()
    val uiState by gymViewModel.uiState.collectAsState()

    val context = LocalContext.current
    LaunchedEffect(Unit) {
        val nodeClient = Wearable.getNodeClient(context)
        try {
            val nodes = nodeClient.connectedNodes.await()
            android.util.Log.d("WearOS", "Connected nodes count: ${nodes.size}")
            if (nodes.isNotEmpty()) {
                Toast.makeText(context, "Watch Companion App Connected!", Toast.LENGTH_SHORT).show()
            } else {
                android.util.Log.w("WearOS", "No connected nodes found. Watch must be paired in Device Manager.")
            }
        } catch (e: Exception) {
            android.util.Log.e("WearOS", "Failed to check nodes.", e)
            // Ignore if wearable services are unavailable
        }
    }

    Surface(modifier = Modifier.fillMaxSize()) {
        if (!uiState.isLoggedIn) {
            LoginScreen(
                isLoading = uiState.isLoading,
                errorMessage = uiState.errorMessage,
                onLogin = gymViewModel::login
            )
        } else {
            DashboardScreen(
                state = uiState,
                onSaveAccount = gymViewModel::saveAccount,
                onRecordSet = gymViewModel::recordSet,
                onRecordWorkoutVideo = gymViewModel::saveWorkoutVideo,
                onSendChat = gymViewModel::sendChat,
                onGeneratePlan = { gymViewModel.generateRealtimeWorkoutPlan() },
                onReplaceExercise = gymViewModel::replaceExerciseWithGemini
            )
        }
    }
}

// ── Plan-detail screen ────────────────────────────────────────────────────────

@Composable
private fun PlanDetailScreen(
    modifier: Modifier,
    plan: WorkoutPlan,
    lastPerformance: Map<String, LastPerformance>,
    onBack: () -> Unit,
    onDayClick: (String) -> Unit
) {
    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    listOf(
                        MaterialTheme.colorScheme.surface,
                        MaterialTheme.colorScheme.surfaceContainerLow
                    )
                )
            )
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = onBack) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                }
                Column {
                    Text(plan.name, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                    if (plan.description.isNotBlank()) {
                        Text(plan.description, style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }
        }

        if (plan.days.isEmpty()) {
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp)
                ) {
                    Text(
                        text = "No workout days yet. Ask the AI trainer to add workouts to this plan.",
                        modifier = Modifier.padding(16.dp),
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
            }
        }

        items(plan.days) { day ->
            OutlinedCard(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onDayClick(day.id) },
                shape = RoundedCornerShape(18.dp)
            ) {
                Column {
                    AsyncImage(
                        model = day.heroImageUrl,
                        contentDescription = day.title,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(148.dp)
                    )
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(14.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(day.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                            Text(
                                "${day.exercises.size} exercises • ${day.exercises.sumOf { it.sets }} total sets",
                                style = MaterialTheme.typography.bodyMedium
                            )
                        }
                        FilledTonalButton(onClick = { onDayClick(day.id) }) {
                            Text("Open")
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun LoginScreen(
    isLoading: Boolean,
    errorMessage: String?,
    onLogin: (String, String) -> Unit
) {
    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                brush = Brush.verticalGradient(
                    listOf(
                        MaterialTheme.colorScheme.primaryContainer,
                        MaterialTheme.colorScheme.surface
                    )
                )
            )
            .padding(24.dp)
    ) {
        Column(
            modifier = Modifier.align(Alignment.Center),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Text(
                text = "GymBud",
                style = MaterialTheme.typography.headlineLarge,
                fontWeight = FontWeight.ExtraBold
            )
            Text(
                text = "Log in, load your profile, and train with structured day plans.",
                style = MaterialTheme.typography.bodyLarge
            )

            OutlinedTextField(
                value = email,
                onValueChange = { email = it },
                label = { Text("Email") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
            OutlinedTextField(
                value = password,
                onValueChange = { password = it },
                label = { Text("Password") },
                singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
                modifier = Modifier.fillMaxWidth()
            )

            if (!errorMessage.isNullOrBlank()) {
                Text(text = errorMessage, color = MaterialTheme.colorScheme.error)
            }

            Button(
                onClick = { onLogin(email, password) },
                enabled = !isLoading,
                modifier = Modifier.fillMaxWidth()
            ) {
                if (isLoading) {
                    CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                    Spacer(modifier = Modifier.width(8.dp))
                }
                Text("Login")
            }
        }
    }
}

@Composable
private fun DashboardScreen(
    state: GymUiState,
    onSaveAccount: (AccountInfo) -> Unit,
    onRecordSet: (String, Int, Int) -> Unit,
    onRecordWorkoutVideo: (String, String) -> Unit,
    onSendChat: (String) -> Unit,
    onGeneratePlan: () -> Unit,
    onReplaceExercise: (String, WorkoutExercise, Boolean) -> Unit
) {
    var selectedTab by rememberSaveable { mutableStateOf(DashboardTab.Plans.name) }
    var selectedDayId by rememberSaveable { mutableStateOf<String?>(null) }
    var selectedPlanId by rememberSaveable { mutableStateOf<String?>(null) }
    var workoutStart by rememberSaveable { mutableStateOf<Pair<String, Int>?>(null) }

    val tab = try { DashboardTab.valueOf(selectedTab) } catch (e: Exception) { DashboardTab.Plans }

    // Look up the active day from either default days or plan days
    val activeDay = state.workoutDays.firstOrNull { it.id == selectedDayId }
        ?: state.workoutPlans.flatMap { it.days }.firstOrNull { it.id == selectedDayId }

    Scaffold(
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = tab == DashboardTab.Plans,
                    onClick = { selectedTab = DashboardTab.Plans.name },
                    icon = { Icon(Icons.Filled.FitnessCenter, contentDescription = "Plans") },
                    label = { Text("Plans") }
                )
                NavigationBarItem(
                    selected = tab == DashboardTab.Account,
                    onClick = { selectedTab = DashboardTab.Account.name },
                    icon = { Icon(Icons.Filled.AccountCircle, contentDescription = "Account") },
                    label = { Text("Account") }
                )
                NavigationBarItem(
                    selected = tab == DashboardTab.Trainer,
                    onClick = { selectedTab = DashboardTab.Trainer.name },
                    icon = { Icon(Icons.Filled.SmartToy, contentDescription = "Trainer") },
                    label = { Text("Trainer") }
                )
            }
        }
    ) { innerPadding ->
        when (tab) {
            DashboardTab.Plans -> {
                val running = workoutStart

                when {
                    running != null && activeDay != null -> {
                        WorkoutSessionScreen(
                            dayTitle = activeDay.title,
                            exercises = activeDay.exercises,
                            startExerciseIndex = running.second,
                            recordedVideos = state.recordedVideos,
                            lastPerformance = state.lastPerformance,
                            exerciseHistory = state.exerciseHistory,
                            onBack = { workoutStart = null },
                            onRecordSet = onRecordSet,
                            onCaptureVideo = onRecordWorkoutVideo
                        )
                    }

                    activeDay != null -> {
                        DayWorkoutScreen(
                            modifier = Modifier.padding(innerPadding),
                            day = activeDay,
                            lastPerformance = state.lastPerformance,
                            temporaryReplacements = state.temporaryReplacements,
                            isReplacing = state.isReplacingExercise,
                            onBack = { selectedDayId = null },
                            onStartExercise = { exerciseIndex ->
                                workoutStart = activeDay.id to exerciseIndex
                            },
                            onReplaceExercise = { exercise, isPermanent ->
                                onReplaceExercise(activeDay.id, exercise, isPermanent)
                            }
                        )
                    }

                    selectedPlanId != null -> {
                        val plan = state.workoutPlans.firstOrNull { it.id == selectedPlanId }
                        if (plan != null) {
                            PlanDetailScreen(
                                modifier = Modifier.padding(innerPadding),
                                plan = plan,
                                lastPerformance = state.lastPerformance,
                                onBack = { selectedPlanId = null },
                                onDayClick = { selectedDayId = it }
                            )
                        }
                    }

                    else -> {
                        PlansOverviewScreen(
                            modifier = Modifier.padding(innerPadding),
                            profile = state.profile,
                            workoutDays = state.workoutDays,
                            workoutPlans = state.workoutPlans,
                            onDayClick = { selectedDayId = it },
                            onPlanClick = { selectedPlanId = it }
                        )
                    }
                }
            }

            DashboardTab.Account -> {
                AccountScreen(
                    modifier = Modifier.padding(innerPadding),
                    accountInfo = state.accountInfo,
                    onSave = onSaveAccount,
                    onGeneratePlan = onGeneratePlan
                )
            }

            DashboardTab.Trainer -> {
                TrainerScreen(
                    modifier = Modifier.padding(innerPadding),
                    messages = state.chatMessages,
                    isThinking = state.isTrainerResponding,
                    onSend = onSendChat
                )
            }
        }
    }
}

@Composable
private fun PlansOverviewScreen(
    modifier: Modifier,
    profile: UserProfile?,
    workoutDays: List<WorkoutDay>,
    workoutPlans: List<WorkoutPlan>,
    onDayClick: (String) -> Unit,
    onPlanClick: (String) -> Unit
) {
    val weeklyExercises = workoutDays.sumOf { it.exercises.size }
    val weeklySets = workoutDays.sumOf { day -> day.exercises.sumOf { it.sets } }

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    listOf(
                        MaterialTheme.colorScheme.surface,
                        MaterialTheme.colorScheme.surfaceContainerLow
                    )
                )
            )
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Card(
                shape = RoundedCornerShape(22.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)
            ) {
                Column(modifier = Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        text = "Welcome ${profile?.displayName ?: "Athlete"}",
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold
                    )
                    Text(text = "Tier: ${profile?.tier ?: "Starter"}")
                    Text(text = "Current streak: ${profile?.streakDays ?: 0} days")
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        AssistChip(onClick = {}, label = { Text("${workoutDays.size} days") })
                        AssistChip(onClick = {}, label = { Text("$weeklySets total sets") })
                    }
                }
            }
        }

        item {
            OutlinedCard(shape = RoundedCornerShape(20.dp)) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(14.dp),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text("This Week", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                        Text("$weeklyExercises exercises planned")
                    }
                    Text(
                        text = "Train smart, not random",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
            }
        }

        items(workoutDays) { day ->
            OutlinedCard(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onDayClick(day.id) },
                shape = RoundedCornerShape(18.dp)
            ) {
                Column {
                    AsyncImage(
                        model = day.heroImageUrl,
                        contentDescription = day.title,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(148.dp)
                    )

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(14.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(day.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                            Text(
                                "${day.exercises.size} exercises • ${day.exercises.sumOf { it.sets }} total sets",
                                style = MaterialTheme.typography.bodyMedium
                            )
                        }
                        FilledTonalButton(onClick = { onDayClick(day.id) }) {
                            Text("Open")
                        }
                    }
                }
            }
        }

        // ── My Plans (AI-created) ─────────────────────────────────────────────

        if (workoutPlans.isNotEmpty()) {
            item {
                Text(
                    text = "My Plans",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(top = 8.dp)
                )
            }

            items(workoutPlans) { plan ->
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onPlanClick(plan.id) },
                    shape = RoundedCornerShape(18.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(
                            modifier = Modifier.weight(1f),
                            verticalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            Text(plan.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                            if (plan.description.isNotBlank()) {
                                Text(plan.description, style = MaterialTheme.typography.bodySmall, maxLines = 2, overflow = TextOverflow.Ellipsis)
                            }
                            Text(
                                "${plan.days.size} workout day${if (plan.days.size != 1) "s" else ""}",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSecondaryContainer
                            )
                        }
                        FilledTonalButton(onClick = { onPlanClick(plan.id) }) {
                            Text("View")
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DayWorkoutScreen(
    modifier: Modifier,
    day: WorkoutDay,
    lastPerformance: Map<String, LastPerformance>,
    temporaryReplacements: Map<String, WorkoutExercise>,
    isReplacing: Boolean,
    onBack: () -> Unit,
    onStartExercise: (Int) -> Unit,
    onReplaceExercise: (WorkoutExercise, Boolean) -> Unit
) {
    var exerciseToReplace by remember { mutableStateOf<WorkoutExercise?>(null) }

    if (exerciseToReplace != null) {
        var isPermanent by remember { mutableStateOf(false) }
        AlertDialog(
            onDismissRequest = { exerciseToReplace = null },
            title = { Text("Replace Exercise") },
            text = {
                Column {
                    Text("Would you like this to be a permanent change to the plan or just for today's session?")
                    Spacer(modifier = Modifier.height(16.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        RadioButton(selected = !isPermanent, onClick = { isPermanent = false })
                        Text("Just for today", modifier = Modifier.clickable { isPermanent = false })
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        RadioButton(selected = isPermanent, onClick = { isPermanent = true })
                        Text("Permanent change", modifier = Modifier.clickable { isPermanent = true })
                    }
                }
            },
            confirmButton = {
                Button(onClick = {
                    onReplaceExercise(exerciseToReplace!!, isPermanent)
                    exerciseToReplace = null
                }) {
                    Text("Confirm")
                }
            },
            dismissButton = {
                TextButton(onClick = { exerciseToReplace = null }) {
                    Text("Cancel")
                }
            }
        )
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.surfaceContainerLowest)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
            }
            Text(day.title, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
            if (isReplacing) {
                Spacer(modifier = Modifier.width(16.dp))
                CircularProgressIndicator(modifier = Modifier.size(24.dp), strokeWidth = 2.dp)
            }
        }

        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            shape = RoundedCornerShape(18.dp)
        ) {
            AsyncImage(
                model = day.heroImageUrl,
                contentDescription = day.title,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(170.dp)
            )
        }

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp),
            contentPadding = PaddingValues(top = 12.dp, bottom = 12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(day.exercises.indices.toList()) { index ->
                val baseExercise = day.exercises[index]
                val exercise = temporaryReplacements[baseExercise.exerciseId] ?: baseExercise
                val lastSet = lastPerformance[exercise.exerciseId]

                Card(shape = RoundedCornerShape(18.dp)) {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        AsyncImage(
                            model = exercise.imageUrl,
                            contentDescription = exercise.name,
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(160.dp)
                                .clip(RoundedCornerShape(topStart = 18.dp, topEnd = 18.dp))
                        )

                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(14.dp),
                            verticalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                                Text(exercise.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                                TextButton(onClick = { exerciseToReplace = baseExercise }) {
                                    Text("Replace")
                                }
                            }
                            Text("Sets: ${exercise.sets}  Target reps: ${exercise.targetReps}")
                            Text(
                                text = if (lastSet != null) {
                                    "Last performance: ${lastSet.weightKg} kg x ${lastSet.reps} reps"
                                } else {
                                    "Last performance: no data yet"
                                }
                            )
                            Button(
                                onClick = { onStartExercise(index) },
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Text("Start Workout")
                            }
                        }
                    }
                }
            }

            item {
                Spacer(Modifier.height(12.dp))
            }
        }
    }
}

@Composable
fun TrendGraph(history: List<SessionStat>, modifier: Modifier = Modifier) {
    if (history.size < 2) {
        Box(modifier, contentAlignment = Alignment.Center) {
            Text("Not enough data to show trend", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        return
    }

    val maxVal = history.maxOfOrNull { it.totalVolume }?.toFloat() ?: 1f
    val minVal = history.minOfOrNull { it.totalVolume }?.toFloat() ?: 0f
    val range = maxVal - minVal
    val yPaddedRange = if (range == 0f) maxVal * 0.2f else range * 0.2f
    val yMin = maxOf(0f, minVal - yPaddedRange)
    val yMax = maxVal + yPaddedRange
    val ySpan = if (yMax - yMin == 0f) 1f else yMax - yMin

    val lineColor = MaterialTheme.colorScheme.primary
    val surfaceColor = MaterialTheme.colorScheme.surface
    val onSurfaceColor = MaterialTheme.colorScheme.onSurface 
    
    var selectedIndex by remember { mutableStateOf<Int?>(null) }
    var tapOffset by remember { mutableStateOf<Offset?>(null) }

    Canvas(
        modifier = modifier.pointerInput(history) {
            detectTapGestures { offset ->
                tapOffset = offset
            }
        }
    ) {
        val width = size.width
        val height = size.height

        val xStep = width / (history.size - 1)

        val points = history.mapIndexed { index, stat ->
            val x = index * xStep
            val y = height - ((stat.totalVolume - yMin) / ySpan) * height
            Offset(x, y)
        }

        // Handle tap detection
        tapOffset?.let { tap ->
            // Find closest point by x coordinate
            val closestIndex = points.indices.minByOrNull { Math.abs(points[it].x - tap.x) } ?: -1
            if (closestIndex != -1) {
                // Determine if touch is close enough to a point to display popup
                val point = points[closestIndex]
                val distance = Math.hypot((point.x - tap.x).toDouble(), (point.y - tap.y).toDouble())
                if (distance < 50.dp.toPx()) {
                    selectedIndex = closestIndex
                } else {
                    selectedIndex = null
                }
            }
            tapOffset = null
        }

        val path = Path().apply {
            points.forEachIndexed { index, point ->
                if (index == 0) moveTo(point.x, point.y)
                else lineTo(point.x, point.y)
            }
        }

        drawPath(
            path = path,
            color = lineColor,
            style = Stroke(width = 4.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round)
        )

        points.forEachIndexed { index, point ->
            val isSelected = index == selectedIndex
            drawCircle(
                color = if (isSelected) onSurfaceColor else lineColor,
                radius = if (isSelected) 8.dp.toPx() else 6.dp.toPx(),
                center = point
            )
            if (isSelected) {
                drawCircle(
                    color = surfaceColor,
                    radius = 4.dp.toPx(),
                    center = point
                )
            }
        }
    }
    
    // Popup
    selectedIndex?.let { index ->
        val stat = history[index]
        val dateStr = SimpleDateFormat("MMM d, yyyy", Locale.getDefault()).format(Date(stat.dateMillis))
        val avgWt = String.format(Locale.US, "%.1f", stat.avgWeight)
        val avgRp = String.format(Locale.US, "%.1f", stat.avgReps)
        
        Card(
            modifier = Modifier.padding(top = 8.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer),
            shape = RoundedCornerShape(8.dp)
        ) {
            Column(modifier = Modifier.padding(12.dp)) {
                Text(dateStr, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(4.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    Text("Avg Weight: ${avgWt}kg", style = MaterialTheme.typography.bodySmall)
                    Text("Avg Reps: $avgRp", style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}

@Composable
private fun WorkoutSessionScreen(
    dayTitle: String,
    exercises: List<WorkoutExercise>,
    startExerciseIndex: Int,
    recordedVideos: Map<String, String>,
    lastPerformance: Map<String, LastPerformance>,
    exerciseHistory: Map<String, List<SessionStat>>,
    onBack: () -> Unit,
    onRecordSet: (String, Int, Int) -> Unit,
    onCaptureVideo: (String, String) -> Unit
) {
    var currentExerciseIndex by rememberSaveable { mutableIntStateOf(startExerciseIndex) }
    var currentSet by rememberSaveable { mutableIntStateOf(1) }
    var weightInput by rememberSaveable { mutableStateOf("") }
    var repsInput by rememberSaveable { mutableStateOf("") }
    var finished by rememberSaveable { mutableStateOf(false) }
    var restSecondsLeft by rememberSaveable { mutableIntStateOf(0) }
    var pendingProgress by remember { mutableStateOf<PendingProgress?>(null) }
    val restProgress = 1f - (restSecondsLeft.toFloat() / REST_SECONDS.toFloat())
    
    var analyzingVideoUri by remember { mutableStateOf<String?>(null) }
    var showLiveArcamera by remember { mutableStateOf(false) }

    val initialPerformance = remember { lastPerformance.toMap() }
    val sessionPerformances = remember { mutableMapOf<String, LastPerformance>() }

    // Animation state
    var showExerciseDone by remember { mutableStateOf(false) }
    var exerciseDoneNextName by remember { mutableStateOf("") }

    val currentExercise = exercises.getOrNull(currentExerciseIndex)

    val context = LocalContext.current
    
val submitSet = { weight: Int, reps: Int ->
        onRecordSet(currentExercise!!.exerciseId, weight, reps)
        val existing = sessionPerformances[currentExercise.exerciseId]
        if (existing == null || weight > existing.weightKg || (weight == existing.weightKg && reps > existing.reps)) {
            sessionPerformances[currentExercise.exerciseId] = LastPerformance(weight, reps)
        }
        val hasMoreSets = currentSet < currentExercise.sets
        val hasNextExercise = currentExerciseIndex < exercises.lastIndex

        when {
            hasMoreSets -> {
                pendingProgress = PendingProgress(
                    nextExerciseIndex = currentExerciseIndex,
                    nextSet = currentSet + 1,
                    label = "Next: ${currentExercise.name} - set ${currentSet + 1}"
                )
                restSecondsLeft = REST_SECONDS
            }
            hasNextExercise -> {
                val nextExerciseName = exercises[currentExerciseIndex + 1].name
                exerciseDoneNextName = nextExerciseName
                showExerciseDone = true
                pendingProgress = PendingProgress(
                    nextExerciseIndex = currentExerciseIndex + 1,
                    nextSet = 1,
                    label = "Next: $nextExerciseName"
                )
                restSecondsLeft = REST_SECONDS
            }
            else -> {
                finished = true
            }
        }
    }

    // --- Wear OS Data Sync ---
    val dataClient = remember { Wearable.getDataClient(context) }

    LaunchedEffect(currentExercise?.name, weightInput, repsInput, restSecondsLeft) {
        val putDataReq = PutDataMapRequest.create("/workout_sync").apply {
            dataMap.putString("exerciseName", currentExercise?.name ?: "Workout Complete")
            dataMap.putInt("weight", weightInput.toIntOrNull() ?: 0)
            dataMap.putInt("reps", repsInput.toIntOrNull() ?: 0)
            dataMap.putInt("restSecondsLeft", restSecondsLeft)
            dataMap.putLong("timestamp", System.currentTimeMillis())
        }.asPutDataRequest()
        putDataReq.setUrgent()
        dataClient.putDataItem(putDataReq)
            .addOnSuccessListener { android.util.Log.d("WearOS", "DataItem synced safely: ${putDataReq.uri}") }
            .addOnFailureListener { android.util.Log.e("WearOS", "Failed to sync DataItem", it) }
    }

    DisposableEffect(dataClient, currentExercise, currentExerciseIndex, currentSet, sessionPerformances) {
        val listener = DataClient.OnDataChangedListener { events ->
            for (event in events) {
                if (event.type == DataEvent.TYPE_CHANGED) {
                    val path = event.dataItem.uri.path
                    if (path == "/workout_done_from_watch") {
                        val dataMap = DataMapItem.fromDataItem(event.dataItem).dataMap
                        val newWeight = dataMap.getInt("weight", 0)
                        val newReps = dataMap.getInt("reps", 0)
                        if (newWeight > 0) weightInput = newWeight.toString()
                        if (newReps > 0) repsInput = newReps.toString()
                        
                        if (currentExercise != null) {
                            submitSet(newWeight, newReps)
                        }
                    } else if (path == "/skip_rest_from_watch") {
                        restSecondsLeft = 0
                    }
                }
            }
        }
        dataClient.addListener(listener)
        onDispose {
            dataClient.removeListener(listener)
        }
    }
    // -------------------------

    var hasCameraPermission by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
        )
    }

    val cameraPermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { isGranted: Boolean ->
        hasCameraPermission = isGranted
    }

    val videoCaptureLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.StartActivityForResult()
    ) { result ->
        val uri = result.data?.data ?: return@rememberLauncherForActivityResult
        currentExercise?.let { onCaptureVideo(it.exerciseId, uri.toString()) }
    }

    LaunchedEffect(currentExerciseIndex, currentSet) {
        currentExercise?.let { ex ->
            val last = lastPerformance[ex.exerciseId]
            weightInput = (last?.weightKg ?: 20).toString()
            repsInput = (last?.reps ?: ex.targetReps).toString()
        }
    }

    LaunchedEffect(restSecondsLeft, pendingProgress) {
        if (restSecondsLeft > 0) {
            delay(1_000)
            restSecondsLeft -= 1
        } else if (restSecondsLeft == 0 && pendingProgress != null) {
            val progress = pendingProgress ?: return@LaunchedEffect
            currentExerciseIndex = progress.nextExerciseIndex
            currentSet = progress.nextSet
            pendingProgress = null
        }
    }

    LaunchedEffect(showExerciseDone) {
        if (showExerciseDone) {
            delay(1_800)
            showExerciseDone = false
        }
    }

    if (showLiveArcamera) {
        LivePoseCameraScreen(onBack = { showLiveArcamera = false })
        return
    }

    if (analyzingVideoUri != null) {
        PosePlaybackScreen(
            videoUri = analyzingVideoUri!!,
            onBack = { analyzingVideoUri = null }
        )
        return
    }

    if (currentExercise == null || exercises.isEmpty()) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text("No exercises available")
        }
        return
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
            }
            Column {
                Text(dayTitle, style = MaterialTheme.typography.titleMedium)
                Text("Exercise ${currentExerciseIndex + 1}/${exercises.size}")
            }
        }

        Text(currentExercise.name, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)

        AsyncImage(
            model = currentExercise.imageUrl,
            contentDescription = currentExercise.name,
            modifier = Modifier
                .fillMaxWidth()
                .height(210.dp)
                .clip(RoundedCornerShape(20.dp))
        )

        OutlinedCard(shape = RoundedCornerShape(16.dp), border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)) {
            Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                    Text("Current set: $currentSet / ${currentExercise.sets}", fontWeight = FontWeight.SemiBold)
                    val last = lastPerformance[currentExercise.exerciseId]
                    Text(
                        text = last?.let { "Last: ${it.weightKg}kg x ${it.reps}" } ?: "Last: none",
                        style = MaterialTheme.typography.bodyMedium
                    )
                }

                Text(
                    text = currentExercise.description,
                    maxLines = 4,
                    overflow = TextOverflow.Ellipsis,
                    style = MaterialTheme.typography.bodyMedium
                )

                if (restSecondsLeft > 0) {
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(
                            text = "Rest active: ${formatSeconds(restSecondsLeft)}",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.primary
                        )
                        LinearProgressIndicator(
                            progress = { restProgress.coerceIn(0f, 1f) },
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                }

                VideoCardPlaceholder(videoUrl = currentExercise.videoUrl)

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    OutlinedTextField(
                        value = weightInput,
                        onValueChange = { weightInput = it.filter { ch -> ch.isDigit() } },
                        label = { Text("Weight (kg)") },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        modifier = Modifier.weight(1f)
                    )
                    OutlinedTextField(
                        value = repsInput,
                        onValueChange = { repsInput = it.filter { ch -> ch.isDigit() } },
                        label = { Text("Reps") },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        modifier = Modifier.weight(1f)
                    )
                }

                Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                    OutlinedButton(
                        onClick = {
                            if (hasCameraPermission) {
                                showLiveArcamera = true
                            } else {
                                cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
                            }
                        },
                        modifier = Modifier.weight(1f),
                        contentPadding = PaddingValues(0.dp)
                    ) {
                        Icon(Icons.Filled.Videocam, contentDescription = "AR", modifier = Modifier.size(20.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("Live AR", fontSize = 13.sp)
                    }

                    var showTempoGame by remember { mutableStateOf(false) }
                    if (showTempoGame) {
                        TempoGameDialog(onDismiss = { showTempoGame = false })
                    }

                    OutlinedButton(
                        onClick = { showTempoGame = true },
                        modifier = Modifier.weight(1f),
                        contentPadding = PaddingValues(0.dp)
                    ) {
                        Icon(Icons.Filled.SmartToy, contentDescription = "Game", modifier = Modifier.size(20.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("Tempo Game", fontSize = 13.sp)
                    }

                    Button(
                        onClick = {
                            val weight = weightInput.toIntOrNull() ?: return@Button
                            val reps = repsInput.toIntOrNull() ?: return@Button 
                            submitSet(weight, reps)
                        },
                        modifier = Modifier.weight(1f),
                        contentPadding = PaddingValues(0.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
                    ) {
                        Icon(Icons.Filled.CheckCircle, contentDescription = "Done", modifier = Modifier.size(20.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("Done", fontSize = 13.sp)
                    }
                }

                val recorded = recordedVideos[currentExercise.exerciseId]
                if (recorded != null) {
                    Row(
                        modifier = Modifier.fillMaxWidth().clickable { analyzingVideoUri = recorded },
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text("Form clip saved!", fontSize = 14.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                        Text("Analyze Form", fontSize = 14.sp, color = MaterialTheme.colorScheme.primary)
                    }
                }
            }
        }

    }

    if (restSecondsLeft > 0 && pendingProgress != null) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.scrim.copy(alpha = 0.45f)),
            contentAlignment = Alignment.Center
        ) {
            Card(shape = RoundedCornerShape(24.dp)) {
                Column(
                    modifier = Modifier.padding(20.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(
                            progress = { restProgress.coerceIn(0f, 1f) },
                            modifier = Modifier.size(96.dp),
                            strokeWidth = 8.dp,
                            trackColor = MaterialTheme.colorScheme.surfaceVariant
                        )
                        Icon(
                            Icons.Filled.Timer,
                            contentDescription = "Rest",
                            modifier = Modifier
                                .size(34.dp)
                                .clip(CircleShape)
                        )
                    }
                    Text("Rest Timer", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Text(formatSeconds(restSecondsLeft), style = MaterialTheme.typography.headlineSmall)
                    Text(pendingProgress?.label ?: "Up next")
                    FilledTonalButton(onClick = { restSecondsLeft = 0 }) {
                        Text("Skip Rest")
                    }
                }
            }
        }
    }

    // ── Exercise complete animation ───────────────────────────────────────────

    AnimatedVisibility(
        visible = showExerciseDone,
        enter = fadeIn(tween(200)) + scaleIn(
            initialScale = 0.4f,
            animationSpec = spring(
                dampingRatio = Spring.DampingRatioMediumBouncy,
                stiffness = Spring.StiffnessMedium
            )
        ),
        exit = fadeOut(tween(300)) + scaleOut(targetScale = 0.4f, animationSpec = tween(300))
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.scrim.copy(alpha = 0.65f))
                .clickable { showExerciseDone = false },
            contentAlignment = Alignment.Center
        ) {
            Card(
                shape = RoundedCornerShape(28.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
            ) {
                Column(
                    modifier = Modifier.padding(horizontal = 40.dp, vertical = 32.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Icon(
                        Icons.Filled.CheckCircle,
                        contentDescription = null,
                        modifier = Modifier.size(72.dp),
                        tint = MaterialTheme.colorScheme.primary
                    )
                    Text(
                        "Exercise Complete!",
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        "Next up",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        exerciseDoneNextName,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        textAlign = TextAlign.Center
                    )
                }
            }
        }
    }

    // ── Day complete animation ────────────────────────────────────────────────

    AnimatedVisibility(
        visible = finished,
        enter = fadeIn(tween(300)) + scaleIn(
            initialScale = 0.2f,
            animationSpec = spring(
                dampingRatio = Spring.DampingRatioLowBouncy,
                stiffness = Spring.StiffnessMediumLow
            )
        ),
        exit = fadeOut(tween(200))
    ) {
        val infiniteTransition = rememberInfiniteTransition(label = "trophy_pulse")
        val trophyScale by infiniteTransition.animateFloat(
            initialValue = 1f,
            targetValue = 1.12f,
            animationSpec = infiniteRepeatable(
                animation = tween(700),
                repeatMode = RepeatMode.Reverse
            ),
            label = "scale"
        )
        val starAlpha by infiniteTransition.animateFloat(
            initialValue = 0.4f,
            targetValue = 1f,
            animationSpec = infiniteRepeatable(
                animation = tween(900),
                repeatMode = RepeatMode.Reverse
            ),
            label = "alpha"
        )

        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.tertiaryContainer.copy(alpha = 0.97f)),
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(14.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(32.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Row(horizontalArrangement = Arrangement.spacedBy((-8).dp)) {
                        Icon(
                            Icons.Filled.Star,
                            contentDescription = null,
                            modifier = Modifier
                                .size(28.dp)
                                .scale(trophyScale * 0.85f),
                            tint = MaterialTheme.colorScheme.primary.copy(alpha = starAlpha * 0.6f)
                        )
                        Icon(
                            Icons.Filled.EmojiEvents,
                            contentDescription = null,
                            modifier = Modifier
                                .size(96.dp)
                                .scale(trophyScale),
                            tint = MaterialTheme.colorScheme.primary
                        )
                        Icon(
                            Icons.Filled.Star,
                            contentDescription = null,
                            modifier = Modifier
                                .size(28.dp)
                                .scale(trophyScale * 0.85f),
                            tint = MaterialTheme.colorScheme.primary.copy(alpha = starAlpha * 0.6f)
                        )
                    }
                }

                Text(
                    "Day Complete!",
                    style = MaterialTheme.typography.headlineLarge,
                    fontWeight = FontWeight.ExtraBold,
                    textAlign = TextAlign.Center
                )
                Text(
                    "You crushed every set today. Here's how you compare to last time:",
                    style = MaterialTheme.typography.bodyLarge,
                    textAlign = TextAlign.Center,
                    color = MaterialTheme.colorScheme.onTertiaryContainer
                )

                // Stat Sheet with Swipeable Pager
                val pagerState = rememberPagerState(pageCount = { exercises.size })
                
                HorizontalPager(
                    state = pagerState,
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f, fill = false)
                ) { page ->
                    val ex = exercises[page]
                    val today = sessionPerformances[ex.exerciseId]
                    val lastTime = initialPerformance[ex.exerciseId]
                    val history = exerciseHistory[ex.exerciseId] ?: emptyList()
                    
                    Card(
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.padding(horizontal = 8.dp)
                    ) {
                        Column(modifier = Modifier.padding(16.dp).fillMaxWidth()) {
                            Text(ex.name, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                            Row(
                                modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Column {
                                    Text("Last Time", style = MaterialTheme.typography.labelMedium)
                                    Text(
                                        text = lastTime?.let { "${it.weightKg}kg x ${it.reps}" } ?: "None",
                                        style = MaterialTheme.typography.bodyMedium
                                    )
                                }
                                Column(horizontalAlignment = Alignment.End) {
                                    Text("Today", style = MaterialTheme.typography.labelMedium)
                                    Text(
                                        text = today?.let { "${it.weightKg}kg x ${it.reps}" } ?: "Skipped",
                                        style = MaterialTheme.typography.bodyMedium,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.primary
                                    )
                                }
                            }

                            Spacer(modifier = Modifier.height(24.dp))
                            Text("Volume Trend (Total Weight × Reps)", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Spacer(modifier = Modifier.height(12.dp))
                            
                            TrendGraph(
                                history = history,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(140.dp)
                                    .padding(vertical = 8.dp, horizontal = 4.dp)
                            )
                        }
                    }
                }

                // Pager Indicator
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 4.dp, bottom = 8.dp),
                    horizontalArrangement = Arrangement.Center
                ) {
                    repeat(exercises.size) { iteration ->
                        val color = if (pagerState.currentPage == iteration) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f)
                        Box(
                            modifier = Modifier
                                .padding(horizontal = 3.dp)
                                .clip(CircleShape)
                                .background(color)
                                .size(8.dp)
                        )
                    }
                }

                Spacer(Modifier.height(8.dp))

                Button(
                    onClick = onBack,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("Finish Workout")
                }
            }
        }
    }
}

@Composable
private fun VideoCardPlaceholder(videoUrl: String) {
    val context = LocalContext.current

    OutlinedCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 4.dp),
        shape = RoundedCornerShape(14.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text("Tutorial Video", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(16f / 9f)
                    .clip(RoundedCornerShape(12.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
                    .clickable(enabled = videoUrl.isNotBlank()) {
                        if (videoUrl.isNotBlank()) {
                            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(videoUrl)))
                        }
                    },
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        Icons.Filled.PlayCircle,
                        contentDescription = "Play",
                        modifier = Modifier.size(44.dp)
                    )
                    Text(
                        text = if (videoUrl.isNotBlank()) "Tap to play API video" else "No video yet",
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }
        }
    }
}

@Composable
private fun AccountScreen(
    modifier: Modifier,
    accountInfo: AccountInfo,
    onSave: (AccountInfo) -> Unit,
    onGeneratePlan: () -> Unit
) {
    var height by rememberSaveable(accountInfo.heightCm) { mutableStateOf(accountInfo.heightCm) }
    var weight by rememberSaveable(accountInfo.weightKg) { mutableStateOf(accountInfo.weightKg) }
    var age by rememberSaveable(accountInfo.age) { mutableStateOf(accountInfo.age) }
    var gender by rememberSaveable(accountInfo.gender) { mutableStateOf(accountInfo.gender) }
    var activityLevel by rememberSaveable(accountInfo.activityLevel) { mutableStateOf(accountInfo.activityLevel) }
    var goals by rememberSaveable(accountInfo.goals) { mutableStateOf(accountInfo.goals) }
    var saved by remember { mutableStateOf(false) }

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text("Account", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Text("Save your body metrics and gym goals.")

        // We wrap things in rows to save vertical space
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
            OutlinedTextField(
                value = height,
                onValueChange = {
                    height = it.filter { ch -> ch.isDigit() }
                    saved = false
                },
                label = { Text("Height (cm)") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                modifier = Modifier.weight(1f)
            )

            OutlinedTextField(
                value = weight,
                onValueChange = {
                    weight = it.filter { ch -> ch.isDigit() }
                    saved = false
                },
                label = { Text("Weight (kg)") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                modifier = Modifier.weight(1f)
            )
        }

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
            OutlinedTextField(
                value = age,
                onValueChange = {
                    age = it.filter { ch -> ch.isDigit() }
                    saved = false
                },
                label = { Text("Age") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                modifier = Modifier.weight(1f)
            )

            OutlinedTextField(
                value = gender,
                onValueChange = {
                    gender = it
                    saved = false
                },
                label = { Text("Gender") },
                modifier = Modifier.weight(1f)
            )
        }

        OutlinedTextField(
            value = activityLevel,
            onValueChange = {
                activityLevel = it
                saved = false
            },
            label = { Text("Activity Level") },
            modifier = Modifier.fillMaxWidth()
        )

        OutlinedTextField(
            value = goals,
            onValueChange = {
                goals = it
                saved = false
            },
            label = { Text("Gym goals") },
            minLines = 3,
            modifier = Modifier.fillMaxWidth()
        )

        Button(
            onClick = {
                onSave(
                    AccountInfo(
                        heightCm = height,
                        weightKg = weight,
                        goals = goals,
                        age = age,
                        gender = gender,
                        activityLevel = activityLevel
                    )
                )
                saved = true
            },
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Save Account")
        }

        Spacer(modifier = Modifier.height(16.dp))

        Button(
            onClick = onGeneratePlan,
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.secondary)
        ) {
            Text("Generate Workout Plan")
        }

        if (saved) {
            Text("Saved", color = MaterialTheme.colorScheme.primary)
        }
    }
}

@Composable
private fun TrainerScreen(
    modifier: Modifier,
    messages: List<ChatMessage>,
    isThinking: Boolean,
    onSend: (String) -> Unit
) {
    var text by rememberSaveable { mutableStateOf("") }

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(12.dp)
    ) {
        Text(
            text = "Your Personal Trainer",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(4.dp)
        )

        LazyColumn(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(messages.indices.toList()) { idx ->
                val message = messages[idx]
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = if (message.byUser) Arrangement.End else Arrangement.Start
                ) {
                    Card(
                        shape = RoundedCornerShape(14.dp),
                        colors = CardDefaults.cardColors(
                            containerColor = if (message.byUser) {
                                MaterialTheme.colorScheme.primaryContainer
                            } else {
                                MaterialTheme.colorScheme.surfaceVariant
                            }
                        )
                    ) {
                        Text(
                            text = message.text,
                            modifier = Modifier.padding(10.dp),
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                }
            }

            if (isThinking) {
                item {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Start) {
                        Card(
                            shape = RoundedCornerShape(14.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer)
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 8.dp),
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                                Text("Trainer is thinking...", style = MaterialTheme.typography.bodyMedium)
                            }
                        }
                    }
                }
            }
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            OutlinedTextField(
                value = text,
                onValueChange = { text = it },
                label = { Text("Ask trainer") },
                modifier = Modifier.weight(1f)
            )

            TextButton(
                onClick = {
                    onSend(text)
                    text = ""
                },
                enabled = text.isNotBlank() && !isThinking
            ) {
                Text("Send")
            }
        }
    }
}

private fun formatSeconds(totalSeconds: Int): String {
    val minutes = totalSeconds / 60
    val seconds = totalSeconds % 60
    return String.format(Locale.US, "%d:%02d", minutes, seconds)
}


@Composable
fun PosePlaybackScreen(videoUri: String, onBack: () -> Unit) {
    val context = LocalContext.current
    var currentFrame by remember { mutableStateOf<Bitmap?>(null) }
    var currentPose by remember { mutableStateOf<Pose?>(null) }
    var isPlaying by remember { mutableStateOf(true) }

    LaunchedEffect(videoUri) {
        withContext(Dispatchers.IO) {
            val retriever = MediaMetadataRetriever()
            try {
                retriever.setDataSource(context, Uri.parse(videoUri))
                val durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                val durationMs = durationStr?.toLongOrNull() ?: 0L
                val frameRateStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_CAPTURE_FRAMERATE)
                val fps = frameRateStr?.toFloatOrNull() ?: 30f
                val frameIntervalUs = (1000000L / fps).toLong()

                val options = AccuratePoseDetectorOptions.Builder()
                    .setDetectorMode(AccuratePoseDetectorOptions.STREAM_MODE)
                    .build()
                val poseDetector = PoseDetection.getClient(options)

                var timeUs = 0L
                while (timeUs <= durationMs * 1000 && isPlaying) {
                    val bitmap = retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST)
                    if (bitmap != null) {
                        val inputImage = InputImage.fromBitmap(bitmap, 0)
                        try {
                            val pose = poseDetector.process(inputImage).await()
                            withContext(Dispatchers.Main) {
                                currentFrame = bitmap
                                currentPose = pose
                            }
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
                    timeUs += frameIntervalUs
                    delay((1000 / fps).toLong())
                }
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                retriever.release()
            }
        }
    }

    Column(modifier = Modifier.fillMaxSize().background(Color.Black)) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Color.White)
            }
            Text("AI Form Analysis", style = MaterialTheme.typography.titleMedium, color = Color.White)
        }

        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            val frame = currentFrame
            if (frame != null) {
                val imageBitmap = frame.asImageBitmap()
                Canvas(
                    modifier = Modifier
                        .fillMaxWidth()
                        .aspectRatio(frame.width.toFloat() / frame.height.toFloat())
                ) {
                    drawImage(image = imageBitmap)
                    
                    val pose = currentPose
                    if (pose != null) {
                        val scaleX = size.width / frame.width.toFloat()
                        val scaleY = size.height / frame.height.toFloat()

                        fun getPoint(landmarkType: Int): Offset? {
                            val lm = pose.getPoseLandmark(landmarkType) ?: return null
                            return Offset(lm.position.x * scaleX, lm.position.y * scaleY)
                        }

                        val connections = listOf(
                            PoseLandmark.LEFT_SHOULDER to PoseLandmark.RIGHT_SHOULDER,
                            PoseLandmark.LEFT_HIP to PoseLandmark.RIGHT_HIP,
                            PoseLandmark.LEFT_SHOULDER to PoseLandmark.LEFT_HIP,
                            PoseLandmark.RIGHT_SHOULDER to PoseLandmark.RIGHT_HIP,
                            PoseLandmark.LEFT_SHOULDER to PoseLandmark.LEFT_ELBOW,
                            PoseLandmark.LEFT_ELBOW to PoseLandmark.LEFT_WRIST,
                            PoseLandmark.RIGHT_SHOULDER to PoseLandmark.RIGHT_ELBOW,
                            PoseLandmark.RIGHT_ELBOW to PoseLandmark.RIGHT_WRIST,
                            PoseLandmark.LEFT_HIP to PoseLandmark.LEFT_KNEE,
                            PoseLandmark.LEFT_KNEE to PoseLandmark.LEFT_ANKLE,
                            PoseLandmark.RIGHT_HIP to PoseLandmark.RIGHT_KNEE,
                            PoseLandmark.RIGHT_KNEE to PoseLandmark.RIGHT_ANKLE,
                            PoseLandmark.LEFT_EAR to PoseLandmark.LEFT_EYE,
                            PoseLandmark.LEFT_EYE to PoseLandmark.NOSE,
                            PoseLandmark.RIGHT_EAR to PoseLandmark.RIGHT_EYE,
                            PoseLandmark.RIGHT_EYE to PoseLandmark.NOSE
                        )

                        connections.forEach { (startType, endType) ->
                            val startPoint = getPoint(startType)
                            val endPoint = getPoint(endType)
                            if (startPoint != null && endPoint != null) {
                                drawLine(
                                    color = Color.Green,
                                    start = startPoint,
                                    end = endPoint,
                                    strokeWidth = 6f
                                )
                            }
                        }

                        pose.allPoseLandmarks.forEach { lm ->
                            val point = Offset(lm.position.x * scaleX, lm.position.y * scaleY)
                            drawCircle(color = Color.Red, radius = 8f, center = point)
                        }
                    }
                }
            } else {
                CircularProgressIndicator(color = Color.White)
                Text("Analyzing Video...", color = Color.White, modifier = Modifier.padding(top = 16.dp))
            }
        }
    }
}

 

@androidx.annotation.OptIn(androidx.camera.core.ExperimentalGetImage::class)
@Composable
fun LivePoseCameraScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val lifecycleOwner = androidx.lifecycle.compose.LocalLifecycleOwner.current

    var currentPose by remember { mutableStateOf<Pose?>(null) }
    var imageSize by remember { mutableStateOf(androidx.compose.ui.unit.IntSize(1, 1)) }
    var isFrontCamera by remember { mutableStateOf(true) }
    var isMirrored by remember { mutableStateOf(true) }

    val poseDetector = remember {
        val options = com.google.mlkit.vision.pose.accurate.AccuratePoseDetectorOptions.Builder()
            .setDetectorMode(com.google.mlkit.vision.pose.accurate.AccuratePoseDetectorOptions.STREAM_MODE)
            .build()
        com.google.mlkit.vision.pose.PoseDetection.getClient(options)
    }
    val executor = remember { java.util.concurrent.Executors.newSingleThreadExecutor() }

    Box(modifier = Modifier.fillMaxSize().background(Color.Black)) {
        androidx.compose.ui.viewinterop.AndroidView(
            modifier = Modifier.fillMaxSize(),
            factory = { ctx ->
                androidx.camera.view.PreviewView(ctx).apply {
                    scaleType = androidx.camera.view.PreviewView.ScaleType.FILL_CENTER
                }
            },
            update = { previewView ->
                val cameraProviderFuture = androidx.camera.lifecycle.ProcessCameraProvider.getInstance(context)
                cameraProviderFuture.addListener({
                    val cameraProvider = cameraProviderFuture.get()
                    val preview = androidx.camera.core.Preview.Builder().build().also {
                        it.setSurfaceProvider(previewView.surfaceProvider)
                    }
                    
                    val imageAnalysis = androidx.camera.core.ImageAnalysis.Builder()
                        .setBackpressureStrategy(androidx.camera.core.ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build()

                    imageAnalysis.setAnalyzer(executor) { imageProxy ->
                        val mediaImage = imageProxy.image
                        if (mediaImage != null) {
                            val image = com.google.mlkit.vision.common.InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
                            
                            val is90or270 = imageProxy.imageInfo.rotationDegrees == 90 || imageProxy.imageInfo.rotationDegrees == 270
                            val width = if (is90or270) image.height else image.width
                            val height = if (is90or270) image.width else image.height
                            imageSize = androidx.compose.ui.unit.IntSize(width, height)

                            poseDetector.process(image)
                                .addOnSuccessListener { pose ->
                                    currentPose = pose
                                }
                                .addOnCompleteListener {
                                    imageProxy.close()
                                }
                        } else {
                            imageProxy.close()
                        }
                    }

                    var cameraSelector = if (isFrontCamera) {
                        androidx.camera.core.CameraSelector.DEFAULT_FRONT_CAMERA
                    } else {
                        androidx.camera.core.CameraSelector.DEFAULT_BACK_CAMERA 
                    }

                    try {
                        var actualMirrored = isFrontCamera
                        if (!cameraProvider.hasCamera(cameraSelector)) {
                            cameraSelector = if (isFrontCamera) {
                                actualMirrored = false
                                androidx.camera.core.CameraSelector.DEFAULT_BACK_CAMERA
                            } else {
                                actualMirrored = true
                                androidx.camera.core.CameraSelector.DEFAULT_FRONT_CAMERA
                            }
                        }
                        isMirrored = actualMirrored
                        cameraProvider.unbindAll()
                        cameraProvider.bindToLifecycle(
                            lifecycleOwner,
                            cameraSelector,
                            preview,
                            imageAnalysis
                        )
                    } catch(e: Exception) {
                        e.printStackTrace()
                    }
                }, androidx.core.content.ContextCompat.getMainExecutor(context))
            }
        )

        Canvas(modifier = Modifier.fillMaxSize()) {
            val pose = currentPose
            if (pose != null && imageSize.width > 1 && imageSize.height > 1) {
                val canvasWidth = size.width
                val canvasHeight = size.height
                
                val imageAspectRatio = imageSize.width.toFloat() / imageSize.height.toFloat()
                val canvasAspectRatio = canvasWidth / canvasHeight

                var scaleX = 1f
                var scaleY = 1f
                var offsetX = 0f
                var offsetY = 0f

                if (imageAspectRatio > canvasAspectRatio) {
                    scaleY = canvasHeight / imageSize.height
                    scaleX = scaleY
                    offsetX = -(imageSize.width * scaleX - canvasWidth) / 2f
                } else {
                    scaleX = canvasWidth / imageSize.width
                    scaleY = scaleX
                    offsetY = -(imageSize.height * scaleY - canvasHeight) / 2f
                }

                fun getPoint(landmarkType: Int): androidx.compose.ui.geometry.Offset? {
                    val lm = pose.getPoseLandmark(landmarkType) ?: return null
                    val x = if (isMirrored) {
                        imageSize.width - lm.position.x
                    } else {
                        lm.position.x
                    }
                    return androidx.compose.ui.geometry.Offset(
                        x * scaleX + offsetX,
                        lm.position.y * scaleY + offsetY
                    )
                }

                val connections = listOf(
                    com.google.mlkit.vision.pose.PoseLandmark.LEFT_SHOULDER to com.google.mlkit.vision.pose.PoseLandmark.RIGHT_SHOULDER,
                    com.google.mlkit.vision.pose.PoseLandmark.LEFT_HIP to com.google.mlkit.vision.pose.PoseLandmark.RIGHT_HIP,
                    com.google.mlkit.vision.pose.PoseLandmark.LEFT_SHOULDER to com.google.mlkit.vision.pose.PoseLandmark.LEFT_HIP,
                    com.google.mlkit.vision.pose.PoseLandmark.RIGHT_SHOULDER to com.google.mlkit.vision.pose.PoseLandmark.RIGHT_HIP,
                    com.google.mlkit.vision.pose.PoseLandmark.LEFT_SHOULDER to com.google.mlkit.vision.pose.PoseLandmark.LEFT_ELBOW,
                    com.google.mlkit.vision.pose.PoseLandmark.LEFT_ELBOW to com.google.mlkit.vision.pose.PoseLandmark.LEFT_WRIST,
                    com.google.mlkit.vision.pose.PoseLandmark.RIGHT_SHOULDER to com.google.mlkit.vision.pose.PoseLandmark.RIGHT_ELBOW,
                    com.google.mlkit.vision.pose.PoseLandmark.RIGHT_ELBOW to com.google.mlkit.vision.pose.PoseLandmark.RIGHT_WRIST,
                    com.google.mlkit.vision.pose.PoseLandmark.LEFT_HIP to com.google.mlkit.vision.pose.PoseLandmark.LEFT_KNEE,
                    com.google.mlkit.vision.pose.PoseLandmark.LEFT_KNEE to com.google.mlkit.vision.pose.PoseLandmark.LEFT_ANKLE,
                    com.google.mlkit.vision.pose.PoseLandmark.RIGHT_HIP to com.google.mlkit.vision.pose.PoseLandmark.RIGHT_KNEE,
                    com.google.mlkit.vision.pose.PoseLandmark.RIGHT_KNEE to com.google.mlkit.vision.pose.PoseLandmark.RIGHT_ANKLE
                )

                connections.forEach { (startType, endType) ->
                    val startPoint = getPoint(startType)
                    val endPoint = getPoint(endType)
                    if (startPoint != null && endPoint != null) {
                        drawLine(
                            color = Color.Green,
                            start = startPoint,
                            end = endPoint,
                            strokeWidth = 6f
                        )
                    }
                }

                pose.allPoseLandmarks.forEach { lm ->
                    val point = getPoint(lm.landmarkType)
                    if (point != null) {
                        drawCircle(color = Color.Red, radius = 8f, center = point)
                    }
                }
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Color.White)
            }
            
            IconButton(onClick = { isFrontCamera = !isFrontCamera }) {
                Icon(Icons.Filled.AccountCircle, contentDescription = "Flip Camera", tint = Color.White)
            }
        }
    }
}

@Composable
fun TempoGameDialog(onDismiss: () -> Unit) {
    val context = LocalContext.current
    val messageClient = remember { Wearable.getMessageClient(context) }
    var liveAccel by remember { mutableStateOf(0f) }

    DisposableEffect(messageClient) {
        val listener = com.google.android.gms.wearable.MessageClient.OnMessageReceivedListener { event ->
            if (event.path == "/live_accel") {
                val buffer = java.nio.ByteBuffer.wrap(event.data)
                liveAccel = buffer.float
            }
        }
        messageClient.addListener(listener)
        onDispose { messageClient.removeListener(listener) }
    }

    androidx.compose.ui.window.Dialog(onDismissRequest = onDismiss) {
        Card(
            modifier = Modifier.fillMaxWidth().height(520.dp),
            shape = RoundedCornerShape(16.dp)
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("Tempo Game", modifier = Modifier.padding(16.dp), style = MaterialTheme.typography.titleLarge)
                
                var isPush by remember { mutableStateOf(true) }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Pull")
                    androidx.compose.material3.Switch(
                        checked = isPush,
                        onCheckedChange = { isPush = it },
                        modifier = Modifier.padding(horizontal = 8.dp)
                    )
                    Text("Push")
                }
                Text("Match the 2x tempo: ${if(isPush) "fast push, slow return" else "fast pull, slow return"}", modifier = Modifier.padding(bottom = 8.dp), fontSize = 14.sp)
                
                TempoGameCanvas(liveAccel, isPush, modifier = Modifier.weight(1f).fillMaxWidth().padding(16.dp).clip(RoundedCornerShape(8.dp)).background(Color.DarkGray))
                
                Button(onClick = onDismiss, modifier = Modifier.padding(16.dp)) {
                    Text("Close")
                }
            }
        }
    }
}

@Composable
fun TempoGameCanvas(liveAccel: Float, isPush: Boolean, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val currentLiveAccel by androidx.compose.runtime.rememberUpdatedState(liveAccel)
    val currentIsPush by androidx.compose.runtime.rememberUpdatedState(isPush)
    var ballVel by remember { mutableStateOf(0f) }
    var ballY by remember { mutableStateOf(0f) }
    var targetY by remember { mutableStateOf(0f) }
    val vibrator = remember {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            (context.getSystemService(android.content.Context.VIBRATOR_MANAGER_SERVICE) as android.os.VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(android.content.Context.VIBRATOR_SERVICE) as android.os.Vibrator
        }
    }
    
    LaunchedEffect(Unit) {
        val startTime = System.currentTimeMillis()
        var lastVibrateTime = 0L
        while (true) {
            val now = System.currentTimeMillis()
            val dt = 16f / 1000f
            ballVel = ballVel * 0.90f + currentLiveAccel * dt * 80f
            ballY = ballY * 0.95f + ballVel * dt
            ballY = ballY.coerceIn(-1f, 1f)
            
            val t = now - startTime
            val cycleTime = t % 3000
            val fastPhase = 1000f
            val slowPhase = 2000f

            targetY = if (currentIsPush) {
                if (cycleTime < fastPhase) {
                    -0.8f + 1.6f * (cycleTime / fastPhase)
                } else {
                    0.8f - 1.6f * ((cycleTime - fastPhase) / slowPhase)
                }
            } else {
                if (cycleTime < fastPhase) {
                    0.8f - 1.6f * (cycleTime / fastPhase)
                } else {
                    -0.8f + 1.6f * ((cycleTime - fastPhase) / slowPhase)
                }
            }
            
            val lowerWall = targetY - 0.35f
            val upperWall = targetY + 0.35f
            
            // If ball escapes, vibrate
            if (ballY < lowerWall || ballY > upperWall) {
                if (now - lastVibrateTime > 500) {
                    lastVibrateTime = now
                    vibrator.vibrate(
                        android.os.VibrationEffect.createOneShot(50, android.os.VibrationEffect.DEFAULT_AMPLITUDE)
                    )
                }
            }
            delay(16)
        }
    }

    Canvas(modifier = modifier) {
        val h = size.height
        val w = size.width
        val centerY = h / 2f
        
        fun yToPx(y: Float) = centerY - y * (h / 2.2f)
        
        val lowerPx = yToPx(targetY - 0.35f)
        val upperPx = yToPx(targetY + 0.35f)
        
        // Target bracket
        drawRoundRect(
            color = Color.Green.copy(alpha = 0.3f),
            topLeft = Offset(0f, upperPx),
            size = androidx.compose.ui.geometry.Size(w, lowerPx - upperPx),
            cornerRadius = CornerRadius(8f)
        )
        // Wall lines
        drawLine(Color.Red, Offset(0f, upperPx), Offset(w, upperPx), strokeWidth = 4f)
        drawLine(Color.Red, Offset(0f, lowerPx), Offset(w, lowerPx), strokeWidth = 4f)
        
        // Ball
        drawCircle(
            color = Color.Cyan,
            radius = 24f,
            center = Offset(w / 2f, yToPx(ballY))
        )
    }
}



