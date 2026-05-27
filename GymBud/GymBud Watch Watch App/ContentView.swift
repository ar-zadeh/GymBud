import SwiftUI

// MARK: - Root

struct ContentView: View {
    @StateObject private var engine = WatchWorkoutEngine.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if engine.isShowingLogSet {
                LogSetView(engine: engine)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                MainView(engine: engine)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: engine.isShowingLogSet)
        .onAppear { engine.startSensors() }
        .onDisappear { engine.stopSensors() }
    }
}

// MARK: - Main

private struct MainView: View {
    @ObservedObject var engine: WatchWorkoutEngine

    var body: some View {
        VStack(spacing: 0) {
            exerciseHeader
            Spacer(minLength: 0)
            contentArea
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var exerciseHeader: some View {
        Text(engine.exerciseName)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.55))
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    @ViewBuilder
    private var contentArea: some View {
        if engine.restSecondsLeft > 0 {
            RestTimerView(engine: engine)
        } else {
            WorkoutStateView(engine: engine)
        }
    }
}

// MARK: - Rest Timer

private struct RestTimerView: View {
    @ObservedObject var engine: WatchWorkoutEngine

    private var progress: Double {
        guard engine.restMaxSeconds > 0 else { return 0 }
        return Double(engine.restSecondsLeft) / Double(engine.restMaxSeconds)
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.15), lineWidth: 7)
                    .frame(width: 86, height: 86)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .frame(width: 86, height: 86)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                VStack(spacing: 1) {
                    Text(formatWatchTime(engine.restSecondsLeft))
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                    Text("REST")
                        .font(.system(size: 7, weight: .heavy))
                        .foregroundStyle(.orange.opacity(0.65))
                        .kerning(2)
                }
            }

            GestureProgressBar(progress: engine.gestureProgress)

            PillButton(label: "Skip Rest", color: .red) {
                engine.skipRest()
            }
        }
    }
}

// MARK: - Workout State

private struct WorkoutStateView: View {
    @ObservedObject var engine: WatchWorkoutEngine

    var body: some View {
        switch engine.repCountState {
        case .idle:       IdleView(engine: engine)
        case .warmupCountdown: WarmupCountdownView(engine: engine)
        case .warmupRecording: WarmupRecordingView(engine: engine)
        case .counting:   CountingView(engine: engine)
        }
    }
}

// MARK: - Idle

private struct IdleView: View {
    @ObservedObject var engine: WatchWorkoutEngine

    var body: some View {
        VStack(spacing: 7) {
            // Weight pill
            HStack(spacing: 4) {
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.4))
                Text("\(engine.currentWeight) lbs")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.white.opacity(0.07))
            .clipShape(Capsule())

            // Fatigue mode toggle
            Button(action: { engine.fatigueModeEnabled.toggle() }) {
                HStack(spacing: 5) {
                    Image(systemName: engine.fatigueModeEnabled ? "bolt.fill" : "bolt.slash")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(engine.fatigueModeEnabled ? .orange : .white.opacity(0.35))
                    Text("Fatigue Mode")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(engine.fatigueModeEnabled ? .orange : .white.opacity(0.35))
                    Spacer()
                    Capsule()
                        .fill(engine.fatigueModeEnabled ? Color.orange : Color.white.opacity(0.15))
                        .frame(width: 26, height: 14)
                        .overlay(
                            Circle()
                                .fill(.white)
                                .frame(width: 10, height: 10)
                                .offset(x: engine.fatigueModeEnabled ? 6 : -6)
                                .animation(.spring(response: 0.2), value: engine.fatigueModeEnabled)
                        )
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(engine.fatigueModeEnabled ? Color.orange.opacity(0.12) : Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(engine.fatigueModeEnabled ? Color.orange.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 0.5))
            }
            .buttonStyle(.plain)

            // Warmup / Count buttons
            HStack(spacing: 5) {
                IconActionButton(label: "Warmup", icon: "figure.strengthtraining.traditional", color: .blue) {
                    engine.startWarmup()
                }
                if engine.isCalibrated {
                    IconActionButton(label: "Count", icon: "play.fill", color: .purple) {
                        engine.startCounting()
                    }
                }
            }

            GestureProgressBar(progress: engine.gestureProgress)

            // Log Set button — full width
            Button(action: { engine.showLogSet() }) {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.square.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Log Set")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.1, green: 0.75, blue: 0.4), Color(red: 0.0, green: 0.6, blue: 0.35)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Warmup Countdown

private struct WarmupCountdownView: View {
    @ObservedObject var engine: WatchWorkoutEngine

    private var ringProgress: Double { Double(engine.warmupCountdown) / 5.0 }

    var body: some View {
        VStack(spacing: 5) {
            Text("GET READY")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.blue.opacity(0.7))
                .kerning(2)

            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.15), lineWidth: 6)
                    .frame(width: 76, height: 76)

                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 76, height: 76)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: ringProgress)

                Text("\(engine.warmupCountdown)")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(.blue)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.3), value: engine.warmupCountdown)
            }
        }
    }
}

// MARK: - Warmup Recording

private struct WarmupRecordingView: View {
    @ObservedObject var engine: WatchWorkoutEngine

    var body: some View {
        VStack(spacing: 8) {
            Text("CALIBRATING")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.cyan.opacity(0.7))
                .kerning(2)

            // Rep dots
            HStack(spacing: 8) {
                ForEach(0..<5) { i in
                    Circle()
                        .fill(i < engine.warmupRepsDetected ? Color.cyan : Color.white.opacity(0.15))
                        .frame(width: 10, height: 10)
                        .scaleEffect(i < engine.warmupRepsDetected ? 1.15 : 1.0)
                        .animation(.spring(response: 0.25), value: engine.warmupRepsDetected)
                }
            }

            Text("\(engine.warmupRepsDetected)")
                .font(.system(size: 50, weight: .black, design: .rounded))
                .foregroundStyle(.cyan)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.2), value: engine.warmupRepsDetected)

            Text("of 5 reps")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))

            PillButton(label: "Done 5 Reps", color: .cyan.opacity(0.75)) {
                engine.finishWarmup()
            }
            .padding(.top, 2)
        }
    }
}

// MARK: - Counting

private struct CountingView: View {
    @ObservedObject var engine: WatchWorkoutEngine

    var body: some View {
        VStack(spacing: 4) {
            Text("REPS")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.green.opacity(0.65))
                .kerning(2)

            Text("\(engine.currentReps)")
                .font(.system(size: 62, weight: .black, design: .rounded))
                .foregroundStyle(.green)
                .shadow(color: .green.opacity(0.35), radius: 10)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.2), value: engine.currentReps)

            GestureProgressBar(progress: engine.gestureProgress)
                .padding(.top, 2)

            Text("flick wrist × 4 to stop")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.25))

            PillButton(label: "Log Set", color: .green.opacity(0.85)) {
                engine.showLogSet()
            }
            .padding(.top, 2)
        }
    }
}

// MARK: - Log Set

enum LogSetField: Hashable {
    case weight
    case reps
}

struct LogSetView: View {
    @ObservedObject var engine: WatchWorkoutEngine
    @State private var selectedField: LogSetField = .weight
    @State private var crownValue: Double = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 8) {
                Text("LOG SET")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.45))
                    .kerning(2)

                AdjusterRow(
                    label: "lbs",
                    value: $engine.logSetWeight,
                    step: 5,
                    color: .blue,
                    isFocused: selectedField == .weight,
                    onSelect: {
                        selectedField = .weight
                        crownValue = Double(engine.logSetWeight)
                    }
                )

                AdjusterRow(
                    label: "reps",
                    value: $engine.logSetReps,
                    step: 1,
                    color: .green,
                    isFocused: selectedField == .reps,
                    onSelect: {
                        selectedField = .reps
                        crownValue = Double(engine.logSetReps)
                    }
                )

                Button(action: { engine.submitLogSet() }) {
                    Text("Submit")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [.blue, Color(red: 0.1, green: 0.4, blue: 1.0)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button("Cancel") { engine.dismissLogSet() }
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.75))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
        }
        .focusable()
        .digitalCrownRotation(
            $crownValue,
            from: 0.0,
            through: 1000.0,
            by: 1.0,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { oldValue, newValue in
            switch selectedField {
            case .weight:
                engine.logSetWeight = max(0, min(1000, Int(round(newValue / 5.0)) * 5))
            case .reps:
                engine.logSetReps = max(0, min(100, Int(round(newValue))))
            }
        }
        .onAppear {
            selectedField = .weight
            crownValue = Double(engine.logSetWeight)
        }
    }
}

// MARK: - Shared Components

private struct AdjusterRow: View {
    let label: String
    @Binding var value: Int
    let step: Int
    let color: Color
    let isFocused: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button {
                onSelect()
                value = max(0, value - step)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 30, height: 30)
                    .background(color.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    if isFocused {
                        Image(systemName: "digitalcrown.arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundStyle(color)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Text("\(value)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.15), value: value)
                }
                Text(label)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
                    .kerning(0.5)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect()
            }

            Button {
                onSelect()
                value += step
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 30, height: 30)
                    .background(color.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 4)
        .background(isFocused ? color.opacity(0.1) : Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? color.opacity(0.85) : color.opacity(0.18), lineWidth: isFocused ? 1.5 : 0.5)
        )
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

private struct IconActionButton: View {
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.25), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

private struct PillButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(color)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct GestureProgressBar: View {
    let progress: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<4) { i in
                Capsule()
                    .fill(i < progress ? Color.green : Color.white.opacity(0.12))
                    .frame(width: i < progress ? 12 : 7, height: 4)
                    .animation(.spring(response: 0.2), value: progress)
            }
        }
    }
}

// MARK: - Helpers

private func formatWatchTime(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%d:%02d", m, s)
}

#Preview {
    ContentView()
}
