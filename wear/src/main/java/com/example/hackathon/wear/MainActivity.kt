package com.example.hackathon.wear

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.*
import android.view.KeyEvent
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.lifecycleScope
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.ButtonDefaults
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.*
import kotlinx.coroutines.tasks.await
import kotlin.math.sqrt
import java.nio.ByteBuffer

class MainActivity : ComponentActivity(), DataClient.OnDataChangedListener {

    private lateinit var dataClient: DataClient
    private lateinit var sensorManager: SensorManager
    private var gyroscope: Sensor? = null
    private var accelerometer: Sensor? = null
    private var accelIsRaw = false

    // ── UI state ──────────────────────────────────────────────────────────────
    var exerciseName    by mutableStateOf("Waiting for workout...")
    var currentWeight   by mutableIntStateOf(0)
    var currentReps     by mutableIntStateOf(0)
    var restSecondsLeft by mutableIntStateOf(0)
    var gestureProgress by mutableIntStateOf(0)

    // ── Rep counting state ────────────────────────────────────────────────────
    enum class RCS { IDLE, WARMUP_COUNTDOWN, WARMUP_RECORDING, COUNTING }
    var repCountState      by mutableStateOf(RCS.IDLE)
    var warmupCountdown    by mutableIntStateOf(5)
    var warmupRepsDetected by mutableIntStateOf(0)
    // Once calibrated, skip the warm-up for all subsequent sets of this workout
    var isCalibrated       by mutableStateOf(false)
    var fatigueModeEnabled by mutableStateOf(false)
    private var firstRepDuration = 0L

    // Calibration (written by sensor thread, read after state→IDLE guard)
    private var calibAxis      = 1        // 0=X 1=Y 2=Z
    private var calibThreshold = 1.0f
    private var calibMinRepMs  = 300L
    private var calibMaxRepMs  = 5000L

    // Running warm-up statistics (all three axes simultaneously)
    private val wuSum   = FloatArray(3)
    private val wuSumSq = FloatArray(3)
    private var wuN     = 0
    private var wuFirstRepTime = 0L   // set on first rep detected
    private var wuLastRepTime  = 0L   // updated on every rep detected

    // Phase state machine (reused for warmup + counting)
    private enum class Phase { IDLE, UP, DOWN }
    private var phase        = Phase.IDLE
    private var halfReps     = 0
    private var cycleStart   = 0L
    private var lastRepTime  = 0L

    // Smoothed linear acceleration
    private val smooth     = FloatArray(3)
    private val rawGravity = FloatArray(3)

    private val GRAVITY_ALPHA    = 0.85f
    private val SMOOTH_ALPHA     = 0.20f
    // Permissive threshold for warmup Y-axis detection; real threshold is calibrated after
    private val WARMUP_THRESHOLD = 0.6f
    private val WARMUP_REPS      = 5

    // ── Gesture ───────────────────────────────────────────────────────────────
    private var flickCount        = 0
    private var lastFlickTime     = 0L
    private var lastFlickDir      = 0
    private var flickCooldownUntil = 0L

    private val FLICK_THRESHOLD   = 3.0f
    private val GESTURE_WINDOW_MS = 2500L
    private val COOLDOWN_MS       = 1500L

    private var countdownJob: Job? = null

    // ─────────────────────────────────────────────────────────────────────────
    //  Sensor listener
    // ─────────────────────────────────────────────────────────────────────────

    private val sensorListener = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent) {
            when (event.sensor.type) {
                Sensor.TYPE_GYROSCOPE -> {
                    val r = event.values[0]
                    when {
                        r >  FLICK_THRESHOLD -> recordFlick(1)
                        r < -FLICK_THRESHOLD -> recordFlick(-1)
                    }
                }
                Sensor.TYPE_ACCELEROMETER,
                Sensor.TYPE_LINEAR_ACCELERATION -> {
                    processAccel(event)
                }
            }
        }
        override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {}
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Accelerometer processing
    // ─────────────────────────────────────────────────────────────────────────

    private fun processAccel(event: SensorEvent) {
        // Gravity removal
        val lin = FloatArray(3)
        if (accelIsRaw) {
            for (i in 0..2) {
                rawGravity[i] = GRAVITY_ALPHA * rawGravity[i] + (1 - GRAVITY_ALPHA) * event.values[i]
                lin[i] = event.values[i] - rawGravity[i]
            }
        } else {
            event.values.copyInto(lin, endIndex = 3)
        }
        for (i in 0..2) smooth[i] += SMOOTH_ALPHA * (lin[i] - smooth[i])

        // ALWAYS stream data for the game, regardless of rep count state
        sendLiveDataToPhone(smooth[calibAxis])

        val now = System.currentTimeMillis()

        when (repCountState) {
            RCS.WARMUP_RECORDING -> {
                // Accumulate running statistics for all axes (for post-analysis)
                for (i in 0..2) { wuSum[i] += smooth[i]; wuSumSq[i] += smooth[i] * smooth[i] }
                wuN++
                // Live detection on Y-axis to auto-count 5 reps
                runPhase(smooth[1], WARMUP_THRESHOLD, now) {
                    if (wuFirstRepTime == 0L) wuFirstRepTime = now
                    wuLastRepTime = now
                    runOnUiThread {
                        warmupRepsDetected++
                        if (warmupRepsDetected >= WARMUP_REPS) finishWarmup()
                    }
                }
            }
            RCS.COUNTING -> {
                runPhase(smooth[calibAxis], calibThreshold, now) { duration ->
                    if (duration in calibMinRepMs..calibMaxRepMs) {
                        val t = System.currentTimeMillis()
                        if (t - lastRepTime > calibMinRepMs) {
                            lastRepTime = t
                            runOnUiThread { 
                                currentReps++ 
                                if (fatigueModeEnabled) {
                                    if (firstRepDuration == 0L) {
                                        firstRepDuration = duration
                                    } else if (duration >= (firstRepDuration / 0.7f)) {
                                        vibrate(400)
                                        repCountState = RCS.IDLE
                                        sendWorkoutDoneToPhone(currentWeight, currentReps)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            else -> {}
        }
    }

    /**
     * Direction-aware phase machine. Fires [onRep] with cycle duration when one full
     * oscillation completes: UP→DOWN→UP  or  DOWN→UP→DOWN.
     * Works for any exercise regardless of which direction the arm starts.
     */
    private fun runPhase(v: Float, threshold: Float, now: Long, onRep: (Long) -> Unit) {
        when (phase) {
            Phase.IDLE -> {
                when {
                    v >  threshold -> { phase = Phase.UP;   cycleStart = now }
                    v < -threshold -> { phase = Phase.DOWN; cycleStart = now }
                }
            }
            Phase.UP -> if (v < -threshold) {
                phase = Phase.DOWN; halfReps++
                if (halfReps >= 2) { onRep(now - cycleStart); halfReps = 0; cycleStart = now }
            }
            Phase.DOWN -> if (v > threshold) {
                phase = Phase.UP; halfReps++
                if (halfReps >= 2) { onRep(now - cycleStart); halfReps = 0; cycleStart = now }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Warm-up flow
    // ─────────────────────────────────────────────────────────────────────────

    private fun startWarmup() {
        countdownJob?.cancel()
        repCountState   = RCS.WARMUP_COUNTDOWN
        warmupCountdown = 5
        countdownJob = lifecycleScope.launch {
            for (i in 5 downTo 1) { warmupCountdown = i; delay(1000L) }
            vibrate(150)
            // Reset warm-up accumulators
            wuSum.fill(0f); wuSumSq.fill(0f); wuN = 0
            wuFirstRepTime = 0L; wuLastRepTime = 0L
            warmupRepsDetected = 0
            resetPhase()
            repCountState = RCS.WARMUP_RECORDING
        }
    }

    /**
     * Called when 5 reps are auto-detected, or when user taps "Done 5 Reps".
     * Analyses the warm-up signal to calibrate axis, threshold, and speed range.
     */
    fun finishWarmup() {
        if (repCountState != RCS.WARMUP_RECORDING) return   // guard against double-call
        repCountState = RCS.IDLE                            // stop sensor writes first

        // ── 1. Dominant axis by variance ─────────────────────────────────
        if (wuN > 0) {
            val n = wuN.toFloat()
            val vars = FloatArray(3) { i ->
                val mean = wuSum[i] / n
                val variance = (wuSumSq[i] / n) - mean * mean
                if (variance > 0f) variance else 0f
            }
            calibAxis = vars.indices.maxByOrNull { vars[it] } ?: 1
            // Threshold = 35 % of std of that axis, floored at 0.15 m/s²
            calibThreshold = maxOf(0.35f * sqrt(vars[calibAxis]), 0.15f)
        }

        // ── 2. Speed range from detected rep timing ───────────────────────
        val totalMs  = wuLastRepTime - wuFirstRepTime
        val repCount = warmupRepsDetected
        if (totalMs > 0 && repCount > 1) {
            // avgPeriod = inter-rep interval; widen the acceptable margins significantly
            val avgPeriod = totalMs / (repCount - 1)
            calibMinRepMs = (avgPeriod / 3.0).toLong().coerceAtLeast(300L)
            calibMaxRepMs = (avgPeriod * 3.0).toLong().coerceAtMost(10_000L)
        } else {
            calibMinRepMs = 300L
            calibMaxRepMs = 8000L
        }

        // ── 3. Start counting ─────────────────────────────────────────────
        currentReps = 0
        lastRepTime = 0L
        resetPhase()
        isCalibrated = true
        vibrate(200)
        repCountState = RCS.COUNTING
    }

    private fun resetPhase() {
        phase = Phase.IDLE; halfReps = 0; cycleStart = 0L; smooth.fill(0f)
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Gesture
    // ─────────────────────────────────────────────────────────────────────────

    private fun triggerGestureAction() {
        vibrate(200)
        runOnUiThread {
            when {
                restSecondsLeft > 0 -> {
                    restSecondsLeft = 0
                    sendSkipRestToPhone()
                }
                repCountState == RCS.COUNTING -> {
                    // Flick = stop counting and submit
                    repCountState = RCS.IDLE
                    sendWorkoutDoneToPhone(currentWeight, currentReps)
                }
                else -> sendWorkoutDoneToPhone(currentWeight, currentReps)
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Vibration helper
    // ─────────────────────────────────────────────────────────────────────────

    private fun vibrate(ms: Long = 200) {
        val vib = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
            (getSystemService(VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        else
            @Suppress("DEPRECATION") getSystemService(VIBRATOR_SERVICE) as Vibrator

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            vib.vibrate(VibrationEffect.createOneShot(ms, VibrationEffect.DEFAULT_AMPLITUDE))
        else
            @Suppress("DEPRECATION") vib.vibrate(ms)
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Lifecycle
    // ─────────────────────────────────────────────────────────────────────────

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        dataClient    = Wearable.getDataClient(this)
        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        gyroscope     = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)

        val linAccel = sensorManager.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)
        if (linAccel != null) { accelerometer = linAccel; accelIsRaw = false }
        else                  { accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER); accelIsRaw = true }

        setContent {
            WearApp(
                exerciseName    = exerciseName,
                weight          = currentWeight,
                reps            = currentReps,
                restSecondsLeft = restSecondsLeft,
                gestureProgress = gestureProgress,
                repCountState   = repCountState,
                warmupCountdown = warmupCountdown,
                warmupReps      = warmupRepsDetected,
                isCalibrated    = isCalibrated,
                fatigueModeEnabled = fatigueModeEnabled,
                onFatigueToggle = { fatigueModeEnabled = it },
                onWeightChange  = { d -> currentWeight = (currentWeight + d).coerceAtLeast(0) },
                onRepsChange    = { d -> currentReps   = (currentReps   + d).coerceAtLeast(0) },
                onDone          = { repCountState = RCS.IDLE; sendWorkoutDoneToPhone(currentWeight, currentReps) },
                onSkip          = { restSecondsLeft = 0; sendSkipRestToPhone() },
                onStartCounting = {
                    firstRepDuration = 0L // Reset for this set
                    if (isCalibrated) {
                        // Calibration already done this workout — jump straight to counting
                        currentReps = 0; lastRepTime = 0L; resetPhase()
                        repCountState = RCS.COUNTING
                    } else {
                        startWarmup()
                    }
                },
                onStopCounting  = { 
                    repCountState = RCS.IDLE 
                    sendWorkoutDoneToPhone(currentWeight, currentReps)
                },
                onWarmupDone    = { finishWarmup() }
            )
        }
    }

    override fun onResume() {
        super.onResume()
        dataClient.addListener(this)
        gyroscope?.also    { sensorManager.registerListener(sensorListener, it, SensorManager.SENSOR_DELAY_GAME) }
        accelerometer?.also { sensorManager.registerListener(sensorListener, it, SensorManager.SENSOR_DELAY_GAME) }
    }

    override fun onPause() {
        super.onPause()
        dataClient.removeListener(this)
        sensorManager.unregisterListener(sensorListener)
        countdownJob?.cancel()
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        val dir = when (keyCode) {
            KeyEvent.KEYCODE_NAVIGATE_NEXT     ->  1
            KeyEvent.KEYCODE_NAVIGATE_PREVIOUS -> -1
            else -> return super.onKeyDown(keyCode, event)
        }
        recordFlick(dir)
        return true
    }

    private fun recordFlick(dir: Int) {
        val now = System.currentTimeMillis()
        if (now < flickCooldownUntil) return
        if (flickCount > 0 && now - lastFlickTime > GESTURE_WINDOW_MS) {
            flickCount = 0; lastFlickDir = 0; gestureProgress = 0
        }
        if (dir != lastFlickDir) {
            lastFlickDir = dir; lastFlickTime = now
            flickCount++; gestureProgress = flickCount
        }
        if (flickCount >= 4) {
            flickCount = 0; lastFlickDir = 0; gestureProgress = 0
            flickCooldownUntil = now + COOLDOWN_MS
            triggerGestureAction()
        }
    }

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        for (event in dataEvents) {
            if (event.type == DataEvent.TYPE_CHANGED && event.dataItem.uri.path == "/workout_sync") {
                val dm = DataMapItem.fromDataItem(event.dataItem).dataMap
                val newExerciseName = dm.getString("exerciseName", "Waiting...")
                if (exerciseName != newExerciseName) {
                    isCalibrated = false
                    repCountState = RCS.IDLE
                    countdownJob?.cancel()
                    exerciseName = newExerciseName
                }
                currentWeight   = dm.getInt("weight", 0)
                currentReps     = dm.getInt("reps", 0)
                restSecondsLeft = dm.getInt("restSecondsLeft", 0)
            }
        }
    }

    private fun sendWorkoutDoneToPhone(weight: Int, reps: Int) {
        val req = PutDataMapRequest.create("/workout_done_from_watch").apply {
            dataMap.putInt("weight", weight)
            dataMap.putInt("reps", reps)
            dataMap.putLong("timestamp", System.currentTimeMillis())
        }.asPutDataRequest()
        dataClient.putDataItem(req)
    }

    private fun sendSkipRestToPhone() {
        val req = PutDataMapRequest.create("/skip_rest_from_watch").apply {
            dataMap.putLong("timestamp", System.currentTimeMillis())
        }.asPutDataRequest()
        dataClient.putDataItem(req)
    }

    private var lastMessageSendTime = 0L
    private fun sendLiveDataToPhone(value: Float) {
        val now = System.currentTimeMillis()
        if (now - lastMessageSendTime < 50) return // Throttle to 20Hz
        lastMessageSendTime = now
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val nodes = Wearable.getNodeClient(this@MainActivity).connectedNodes.await()
                val payload = ByteBuffer.allocate(8).putFloat(value).putInt(if (phase == Phase.UP) 1 else if (phase == Phase.DOWN) -1 else 0).array()
                for (node in nodes) {
                    Wearable.getMessageClient(this@MainActivity).sendMessage(node.id, "/live_accel", payload).await()
                }
            } catch (e: Exception) {
                // Ignore
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Composables
// ─────────────────────────────────────────────────────────────────────────────

@Composable
fun WearApp(
    exerciseName: String,
    weight: Int,
    reps: Int,
    restSecondsLeft: Int,
    gestureProgress: Int,
    repCountState: MainActivity.RCS,
    warmupCountdown: Int,
    warmupReps: Int,
    isCalibrated: Boolean,
    fatigueModeEnabled: Boolean,
    onFatigueToggle: (Boolean) -> Unit,
    onWeightChange: (Int) -> Unit,
    onRepsChange: (Int) -> Unit,
    onDone: () -> Unit,
    onSkip: () -> Unit,
    onStartCounting: () -> Unit,
    onStopCounting: () -> Unit,
    onWarmupDone: () -> Unit
) {
    MaterialTheme {
        when {
            restSecondsLeft > 0 ->
                RestScreen(exerciseName, restSecondsLeft, gestureProgress, onSkip)
            repCountState == MainActivity.RCS.WARMUP_COUNTDOWN ->
                CountdownScreen(exerciseName, warmupCountdown)
            repCountState == MainActivity.RCS.WARMUP_RECORDING ->
                WarmupScreen(exerciseName, warmupReps, onWarmupDone)
            repCountState == MainActivity.RCS.COUNTING ->
                CountingScreen(exerciseName, reps, onStopCounting)
            else ->
                ActiveSetScreen(exerciseName, weight, reps, gestureProgress,
                    isCalibrated, fatigueModeEnabled, onFatigueToggle, onWeightChange, onRepsChange, onDone, onStartCounting)
        }
    }
}

@Composable
fun RestScreen(exerciseName: String, restSecondsLeft: Int, gestureProgress: Int, onSkip: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().background(Color.Black),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Resting", color = Color.Cyan, fontSize = 16.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        Text(
            text = String.format("%02d:%02d", restSecondsLeft / 60, restSecondsLeft % 60),
            color = Color.White, fontSize = 32.sp, fontWeight = FontWeight.Bold
        )
        Spacer(Modifier.height(4.dp))
        Text("Next: $exerciseName", color = Color.LightGray, fontSize = 12.sp, textAlign = TextAlign.Center)
        Spacer(Modifier.height(4.dp))
        GestureProgressDots(gestureProgress)
        Spacer(Modifier.height(4.dp))
        Button(onClick = onSkip,
            colors = ButtonDefaults.buttonColors(backgroundColor = Color.DarkGray),
            modifier = Modifier.height(32.dp)
        ) { Text("Skip", fontSize = 12.sp, color = Color.White) }
    }
}

@Composable
fun CountdownScreen(exerciseName: String, countdown: Int) {
    Column(
        modifier = Modifier.fillMaxSize().background(Color.Black),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Get Ready!", color = Color.Yellow, fontSize = 14.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(4.dp))
        Text(
            text = if (countdown > 0) "$countdown" else "Go!",
            color = if (countdown > 0) Color.White else Color(0xFF00DD00),
            fontSize = 52.sp, fontWeight = FontWeight.Bold
        )
        Spacer(Modifier.height(6.dp))
        Text(exerciseName, color = Color.Cyan, fontSize = 11.sp, textAlign = TextAlign.Center)
        Text("5 warm-up reps", color = Color.Gray, fontSize = 10.sp)
    }
}

@Composable
fun WarmupScreen(exerciseName: String, repsDetected: Int, onDone: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().background(Color.Black),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Warm-up", color = Color.Yellow, fontSize = 14.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(4.dp))
        Text(
            text = "$repsDetected / 5",
            color = Color.White, fontSize = 40.sp, fontWeight = FontWeight.Bold
        )
        Text("reps", color = Color.LightGray, fontSize = 13.sp)
        Spacer(Modifier.height(6.dp))
        Text(exerciseName, color = Color.Cyan, fontSize = 11.sp, textAlign = TextAlign.Center)
        Spacer(Modifier.height(8.dp))
        Button(onClick = onDone,
            colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF005500)),
            modifier = Modifier.height(28.dp).fillMaxWidth(0.6f)
        ) { 
            Text("Done 5 Reps", fontSize = 10.sp, color = Color.White, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth()) 
        }
    }
}

@Composable
fun CountingScreen(exerciseName: String, reps: Int, onStop: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().background(Color.Black),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(exerciseName, color = Color.Cyan, fontSize = 12.sp, textAlign = TextAlign.Center)
        Spacer(Modifier.height(2.dp))
        Text("$reps", color = Color.White, fontSize = 52.sp, fontWeight = FontWeight.Bold)
        Text("reps", color = Color.LightGray, fontSize = 14.sp)
        Spacer(Modifier.height(4.dp))
        Text("Flick wrist to stop", color = Color.Gray, fontSize = 10.sp)
        Spacer(Modifier.height(6.dp))
        Button(onClick = onStop,
            colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFFCC4400)),
            modifier = Modifier.height(28.dp)
        ) { Text("Stop", fontSize = 12.sp, color = Color.White) }
    }
}

@Composable
fun ActiveSetScreen(
    exerciseName: String,
    weight: Int,
    reps: Int,
    gestureProgress: Int,
    isCalibrated: Boolean,
    fatigueModeEnabled: Boolean,
    onFatigueToggle: (Boolean) -> Unit,
    onWeightChange: (Int) -> Unit,
    onRepsChange: (Int) -> Unit,
    onDone: () -> Unit,
    onStartCounting: () -> Unit
) {
    Column(
        modifier = Modifier.fillMaxSize().background(Color.Black),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        androidx.wear.compose.material.ToggleChip(
            checked = fatigueModeEnabled,
            onCheckedChange = onFatigueToggle,
            label = { 
                Text(
                    "Fatigue mode", 
                    fontSize = 11.sp, 
                    color = Color.White, 
                    modifier = Modifier.fillMaxWidth(), 
                    textAlign = TextAlign.Center 
                ) 
            },
            toggleControl = {
                androidx.wear.compose.material.Icon(
                    imageVector = androidx.wear.compose.material.ToggleChipDefaults.switchIcon(checked = fatigueModeEnabled),
                    contentDescription = null,
                    modifier = Modifier.size(16.dp),
                    tint = if (fatigueModeEnabled) Color.Green else Color.Gray
                )
            },
            modifier = Modifier.height(30.dp).fillMaxWidth(0.9f).padding(bottom = 2.dp)
        )

        Row(verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceEvenly,
            modifier = Modifier.fillMaxWidth().padding(vertical = 1.dp)
        ) {
            StepperButton("-") { onWeightChange(-5) }
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.width(60.dp)) {
                Text("$weight", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                Text("lbs", color = Color.LightGray, fontSize = 10.sp)
            }
            StepperButton("+") { onWeightChange(5) }
        }

        Row(verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceEvenly,
            modifier = Modifier.fillMaxWidth().padding(vertical = 1.dp)
        ) {
            StepperButton("-") { onRepsChange(-1) }
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.width(60.dp)) {
                Text("$reps", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                Text("reps", color = Color.LightGray, fontSize = 10.sp)
            }
            StepperButton("+") { onRepsChange(1) }
        }

        GestureProgressDots(gestureProgress)

        Button(onClick = onDone,
            modifier = Modifier.padding(top = 4.dp).height(30.dp),
            colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF00AA00))
        ) { Text("Done", fontSize = 12.sp, color = Color.White, fontWeight = FontWeight.Bold) }

        Button(
            onClick = onStartCounting,
            modifier = Modifier.padding(top = 4.dp).fillMaxWidth(0.72f),
            colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF0055CC))
        ) {
            Text(
                text = if (isCalibrated) "Count Reps" else "Calibrate & Count",
                fontSize = 13.sp,
                color = Color.White,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
fun GestureProgressDots(progress: Int) {
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
        repeat(4) { i ->
            Box(modifier = Modifier.size(6.dp).background(
                color = if (i < progress) Color(0xFF00CC00) else Color(0xFF444444),
                shape = CircleShape
            ))
        }
    }
}

@Composable
fun StepperButton(text: String, onClick: () -> Unit) {
    Button(onClick = onClick, modifier = Modifier.size(36.dp),
        colors = ButtonDefaults.secondaryButtonColors(), shape = CircleShape
    ) { Text(text, fontSize = 18.sp, color = Color.White) }
}
