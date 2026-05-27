# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Structure

This workspace contains two parallel implementations of the same GymBud fitness app — one for iOS/watchOS and one for Android/WearOS — plus a shared Python AI trainer server.

```
AppDevelopment/
├── GymBud/              # iOS + Apple Watch (Swift, SwiftUI)
├── GymBud_android/      # Android + WearOS (Kotlin, Jetpack Compose)
└── GymBud_android/trainer_server.py  # Shared FastAPI trainer backend
```

---

## GymBud (iOS)

**Build & Run:** Open `GymBud/GymBud.xcodeproj` in Xcode. Run on a physical iPhone or simulator. The watchOS target (`GymBud Watch Watch App`) runs on a paired Apple Watch or Watch Simulator.

**Key dependency:** LiteRT-LM is added via Swift Package Manager from `https://github.com/google-ai-edge/LiteRT-LM` (pinned to main branch). The on-device model file `gemma-4-E2B-it.litertlm` must be in the Xcode app bundle target. `AIManager` initializes the engine on a CPU backend — **do not switch to Metal/GPU** because Metal work is blocked on the LiteRT-LM background threadpool.

**API keys:** `exerciseDbApiKey` and `pixabayApiKey` are hardcoded string placeholders in `GymBud/GymBud/GymViewModel.swift`. Replace them directly; there is no secrets file.

**Architecture (iOS):**
- `GymBudApp.swift` — entry point; constructs and injects `AIManager`, `GymViewModel`, `PhoneWatchConnector`, `WorkoutSessionManager` as environment objects.
- `AIManager.swift` — wraps the LiteRT-LM `Engine` + a single `Conversation` with all workout plan tools registered. Exposes `generateReply(_:)` and `sendMessage(_:)`.
- `GymViewModel.swift` — core `@MainActor` state: workout plans, chat history, exercise history, account info. Persists to `UserDefaults`. Contains the MCP-style tool dispatcher (`executeMcpTool`) and LiteRT-LM native `Tool` structs (`CreateWorkoutPlanTool`, `AddWorkoutDayTool`, etc.) plus `GymToolContext.shared` singleton bridge.
- `WorkoutSessionManager.swift` — singleton managing active workout session: current exercise/set, rest timer (Combine), and push notifications for rest-end.
- `PhoneWatchConnector.swift` — `WCSession` delegate; sends workout start/rest updates to Watch; receives rep counts, weight, and skip-rest gestures from Watch.
- `WatchWorkoutEngine.swift` — Watch-side singleton; CoreMotion-based rep counting with warmup calibration, wrist-flick gesture detection, and HealthKit session for screen-wake.

---

## GymBud Android

**Build:** From `GymBud_android/`:
```bash
./gradlew assembleDebug          # build phone APK
./gradlew :wear:assembleDebug    # build WearOS APK
./gradlew test                   # unit tests
./gradlew connectedAndroidTest   # instrumented tests (device/emulator required)
```

**API keys:** Set in `~/.gradle/gradle.properties` (not committed):
```
GEMINI_API_KEY=...
EXERCISE_DB_API_KEY=...
EXERCISE_DB_HOST=edb-with-videos-and-images-by-ascendapi.p.rapidapi.com
PIXABAY_API_KEY=...
```
These are injected into `BuildConfig` via `app/build.gradle.kts`. Without them the app falls back gracefully (local keyword replies, fallback exercise images).

**Architecture (Android):**
- `MainActivity.kt` — single activity; initializes a global Coil `ImageLoader` with aggressive disk caching (`respectCacheHeaders(false)` to ignore CDN no-cache headers).
- `GymApp.kt` — a single large file containing: the `GymViewModel` (AndroidViewModel + StateFlow), all Retrofit service interfaces, all Composable screens, and all data classes. Navigation is state-driven (no NavGraph) — `selectedTab`, `selectedPlanId`, `selectedDayId` booleans inside `DashboardScreen` drive the stack.
- `McpTools.kt` — `WorkoutPlan` / `ExerciseInput` data classes; `WorkoutPlanTools` object with MCP tool schema definitions (compatible with Gemini `functionDeclarations` and Anthropic `tools` formats via `toAnthropicFormat()`).
- `wear/MainActivity.kt` — WearOS activity; all sensor processing, Compose UI, and Wearable Data API logic in one file. Rep counting uses a two-phase state machine (WARMUP → COUNTING) with per-workout accelerometer calibration.

**Data persistence:** Account info → DataStore (Preferences); full state snapshot → `files/account_settings.json` (Gson); exercise/image API results → in-memory `Map` caches.

---

## Shared Python Trainer Server

Located at `GymBud_android/trainer_server.py`. Serves **both** platforms.

```bash
pip install fastapi uvicorn litert-lm
uvicorn trainer_server:app --reload   # runs on port 8000
```

- iOS connects to `http://127.0.0.1:8000/trainer/chat`
- Android Emulator connects to `http://10.0.2.2:8000/trainer/chat` (special emulator alias for host loopback)
- Requires `gemma-4-E2B-it.litertlm` in the same directory; gracefully falls back if missing.
- Endpoints: `POST /trainer/chat`, `GET/PATCH /profile`, `GET/POST /kb/sleep`.

---

## Cross-Platform AI Tool-Calling Pattern

Both apps implement the same MCP-style workout plan tool loop:

1. User asks the AI trainer to create/modify a plan.
2. The AI (on-device Gemma via LiteRT-LM on iOS; cloud Gemini on Android) emits structured tool calls.
3. `executeMcpTool(toolName, params)` in the ViewModel dispatches to the appropriate mutation method.
4. State updates propagate to the UI immediately.

**Tool names** (identical across platforms): `create_workout_plan`, `add_workout_to_plan`, `remove_workout_from_plan`, `add_exercise_to_workout`, `remove_exercise_from_workout`, `list_workout_plans`, `get_workout_plan`.

**Trainer fallback chain (both platforms):** Remote server → Gemini API → local keyword-based replies.

---

## Watch / WearOS Rep Counting

Both watch implementations use the same calibration algorithm:
1. **Warmup phase** — user performs 5 warm-up reps; running variance statistics are collected on all three accelerometer axes.
2. **Calibration** — dominant axis selected by highest variance; threshold = 35% of std dev on that axis; speed range derived from inter-rep timing.
3. **Counting phase** — direction-aware phase state machine (IDLE → UP → DOWN → UP) fires on each full oscillation within the calibrated speed window.
4. **Fatigue mode** — stops counting when rep duration exceeds 1/0.7× the first rep duration.
5. **Wrist-flick gesture** — 4 alternating-direction gyroscope flicks within 2.5 s = submit set or skip rest.
