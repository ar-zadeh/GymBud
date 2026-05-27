import SwiftUI
import Combine
import AVFoundation
import Vision
import ImagePlayground
import Charts

struct ContentView: View {
    @State private var isLoggedIn = false
    @EnvironmentObject var gymViewModel: GymViewModel

    var body: some View {
        if isLoggedIn {
            DashboardView()
        } else {
            LoginView(isLoggedIn: $isLoggedIn)
        }
    }
}

// MARK: - Login Screen
struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.run.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)

            Text("GymBud")
                .font(.largeTitle)
                .fontWeight(.bold)

            VStack(spacing: 15) {
                TextField("Username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
            }

            Button(action: {
                withAnimation {
                    isLoggedIn = true
                }
            }) {
                Text("Login")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 50)
    }
}

// MARK: - Dashboard
struct DashboardView: View {
    var body: some View {
        TabView {
            PlansOverviewView()
                .tabItem {
                    Label("Plans", systemImage: "list.clipboard")
                }

            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.xyaxis.line")
                }

            TrainerView()
                .tabItem {
                    Label("Trainer", systemImage: "camera.viewfinder")
                }

            AccountView()
                .tabItem {
                    Label("Account", systemImage: "person.circle.fill")
                }
        }
    }
}

// MARK: - Plans Overview
struct PlansOverviewView: View {
    @EnvironmentObject var gymViewModel: GymViewModel
    @EnvironmentObject var connector: PhoneWatchConnector
    @State private var showingAddPlan = false
    @State private var newPlanName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: {
                        gymViewModel.generateWorkoutPlan()
                    }) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Generate Workout Plan")
                        }
                        .fontWeight(.bold)
                    }

                    if gymViewModel.isGeneratingPlan {
                        HStack {
                            ProgressView()
                            Text("Generating plan...")
                        }
                    }
                }

                Section {
                    Button(action: {
                        connector.sendStartWorkoutInfo(exerciseName: "Bench Press", startingWeight: 135)
                    }) {
                        HStack {
                            Image(systemName: "applewatch.radiowaves.left.and.right")
                            Text("Ping Apple Watch")
                        }
                        .foregroundColor(.blue)
                        .fontWeight(.bold)
                    }
                }

                Section {
                    ForEach($gymViewModel.workoutPlans) { $plan in
                        NavigationLink(destination: PlanDetailView(plan: $plan)) {
                            HStack {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .foregroundColor(.blue)
                                    .padding(.trailing, 8)
                                VStack(alignment: .leading) {
                                    Text(plan.name).font(.headline)
                                    Text("\(plan.days.count) Days / Week").font(.subheadline).foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .navigationTitle("Your Plans")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddPlan = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Plan", isPresented: $showingAddPlan) {
                TextField("Plan Name", text: $newPlanName)
                Button("Add") {
                    if !newPlanName.isEmpty {
                        _ = gymViewModel.createWorkoutPlan(name: newPlanName)
                        newPlanName = ""
                    }
                }
                Button("Cancel", role: .cancel) {
                    newPlanName = ""
                }
            }
        }
    }
}

struct PlanDetailView: View {
    @Binding var plan: WorkoutPlan
    @EnvironmentObject var gymViewModel: GymViewModel
    @State private var showingAddDay = false
    @State private var newDayName = ""

    var body: some View {
        List {
            ForEach($plan.days) { $day in
                NavigationLink(destination: DayWorkoutView(day: $day, planId: plan.id)) {
                    HStack(spacing: 12) {
                        dayThumbnail(day: day)
                            .frame(width: 64, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading) {
                            Text(day.title)
                                .font(.headline)
                            Text("\(day.exercises.count) exercises")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .onDelete { indexSet in
                plan.days.remove(atOffsets: indexSet)
            }
        }
        .navigationTitle(plan.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddDay = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("New Day", isPresented: $showingAddDay) {
            TextField("Day Title", text: $newDayName)
            Button("Add") {
                let dayTitle = newDayName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !dayTitle.isEmpty {
                    Task {
                        await gymViewModel.addWorkoutToPlan(planId: plan.id, dayTitle: dayTitle, exerciseInputs: [])
                    }
                    newDayName = ""
                }
            }
            Button("Cancel", role: .cancel) {
                newDayName = ""
            }
        }
    }

    @ViewBuilder
    private func dayThumbnail(day: WorkoutDay) -> some View {
        if !day.localHeroImagePath.isEmpty,
           let uiImage = UIImage(contentsOfFile: day.localHeroImagePath) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if let url = URL(string: day.heroImageUrl), !day.heroImageUrl.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Color.gray.opacity(0.2)
                }
            }
        } else {
            Color.gray.opacity(0.2)
        }
    }
}

struct DayWorkoutView: View {
    @Binding var day: WorkoutDay
    let planId: String

    @EnvironmentObject var gymViewModel: GymViewModel
    @State private var showingAddExercise = false
    @State private var newExerciseName = ""
    @State private var newExerciseSets = "3"
    @State private var newExerciseReps = "10"

    var body: some View {
        VStack(spacing: 0) {
            dayHeroBanner
                .frame(height: 180)
                .clipped()

            List {
                ForEach(day.exercises) { exercise in
                    ExerciseItemView(exercise: exercise)
                }
                .onDelete { indexSet in
                    day.exercises.remove(atOffsets: indexSet)
                }
                .onMove { source, destination in
                    day.exercises.move(fromOffsets: source, toOffset: destination)
                }
            }

            NavigationLink(destination: WorkoutSessionView(dayTitle: day.title, exercises: day.exercises)) {
                Text("Start Workout")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                    .padding()
            }
        }
        .navigationTitle(day.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    EditButton()
                    Button(action: { showingAddExercise = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .alert("New Exercise", isPresented: $showingAddExercise) {
            TextField("Exercise Name", text: $newExerciseName)
            TextField("Sets", text: $newExerciseSets)
            TextField("Reps", text: $newExerciseReps)
            Button("Add") {
                let name = newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
                let sets = Int(newExerciseSets) ?? 3
                let reps = Int(newExerciseReps) ?? 10
                if !name.isEmpty {
                    Task {
                        await gymViewModel.addExerciseToPlanDay(
                            planId: planId,
                            dayId: day.id,
                            exerciseInput: ExerciseInput(name: name, sets: sets, reps: reps)
                        )
                    }
                    newExerciseName = ""
                    newExerciseSets = "3"
                    newExerciseReps = "10"
                }
            }
            Button("Cancel", role: .cancel) {
                newExerciseName = ""
            }
        }
    }

    @ViewBuilder
    private var dayHeroBanner: some View {
        if !day.localHeroImagePath.isEmpty,
           let uiImage = UIImage(contentsOfFile: day.localHeroImagePath) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if let url = URL(string: day.heroImageUrl), !day.heroImageUrl.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Color.gray.opacity(0.2)
                }
            }
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                        .font(.largeTitle)
                )
        }
    }
}

struct ExerciseItemView: View {
    let exercise: WorkoutExercise

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name).font(.headline)
                Text("\(exercise.sets) sets x \(exercise.targetReps) reps")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "play.circle.fill")
                .foregroundColor(.blue)
                .font(.title2)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Workout Session

struct WorkoutSessionView: View {
    let dayTitle: String
    let exercises: [WorkoutExercise]

    // UI-only state stays local
    @State private var weightInput = ""
    @State private var repsInput = ""
    @State private var showExerciseDone = false
    @State private var exerciseDoneNextName = ""
    @State private var finishedScale = 0.5
    @State private var showRepCounter = false
    @State private var showImagePlayground = false
    @State private var showWatchLive = false

    @Environment(\.dismiss) var dismiss
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @EnvironmentObject var connector: PhoneWatchConnector
    @EnvironmentObject var gymViewModel: GymViewModel
    @EnvironmentObject var session: WorkoutSessionManager

    private var currentExercise: WorkoutExercise {
        session.currentExercise
            ?? WorkoutExercise(exerciseId: "empty", name: "—", sets: 0, targetReps: 0, imageUrl: "", videoUrl: "", description: "")
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Exercise \(session.currentExerciseIndex + 1)/\(exercises.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(currentExercise.name)
                        .font(.title)
                        .fontWeight(.bold)

                    exerciseImage

                    VStack(spacing: 16) {
                        HStack {
                            Text("Set \(session.currentSet) / \(currentExercise.sets)")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("Goal: \(currentExercise.targetReps) reps")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        if let last = gymViewModel.lastPerformance[currentExercise.exerciseId] {
                            Text("Last: \(last.weightKg) kg × \(last.reps) reps")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Last: none")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Text(currentExercise.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        // Inline rest timer — never blocks the UI
                        if session.restSecondsLeft > 0 || session.restJustFinished {
                            RestTimerCard(session: session) {
                                session.skipRest()
                                connector.sendRestUpdate(seconds: 0, sessionId: session.restSessionId)
                                prefillInputs()
                                updateWatchStartInfo()
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        if let videoUrl = URL(string: currentExercise.videoUrl), !currentExercise.videoUrl.isEmpty {
                            Link(destination: videoUrl) {
                                HStack {
                                    Image(systemName: "video.fill")
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.blue)
                                        .clipShape(Circle())
                                    Text("Watch Tutorial Video")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }

                        Button(action: { connector.sendStartWarmup() }) {
                            HStack {
                                Image(systemName: "figure.walk.motion")
                                Text("Start Warmup on Watch").fontWeight(.semibold)
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(12)
                        }

                        Button(action: { showRepCounter = true }) {
                            HStack {
                                Image(systemName: "camera.viewfinder")
                                Text("Open Live Rep Counter").fontWeight(.semibold)
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading) {
                                Text("Weight (kg)").font(.caption)
                                TextField("Weight", text: $weightInput)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.numberPad)
                                    .onChange(of: weightInput) { oldValue, newValue in
                                        let f = newValue.filter { $0.isNumber }
                                        if f != newValue { weightInput = f }
                                    }
                            }
                            VStack(alignment: .leading) {
                                Text("Reps").font(.caption)
                                TextField("Reps", text: $repsInput)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.numberPad)
                                    .onChange(of: repsInput) { oldValue, newValue in
                                        let f = newValue.filter { $0.isNumber }
                                        if f != newValue { repsInput = f }
                                    }
                            }
                        }

                        Button(action: {
                            let weight = Int(weightInput) ?? 0
                            let reps = Int(repsInput) ?? 0
                            if weight > 0 && reps > 0 { submitSet(weight: weight, reps: reps) }
                        }) {
                            Text(session.hasMoreSets ? "Log Set" : (session.hasNextExercise ? "Next Exercise" : "Finish Workout"))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(session.hasMoreSets ? Color.blue : Color.green)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                }
                .padding()
                .opacity((showExerciseDone || session.isFinished) ? 0.3 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: session.restSecondsLeft > 0)
            }
            .sheet(isPresented: $showRepCounter) { LivePoseCameraView() }
        .sheet(isPresented: $showWatchLive) {
            WatchLiveView(connector: connector)
        }
        .onChange(of: connector.watchState) { oldState, newState in
            if newState != "idle" {
                showWatchLive = true
            } else {
                showWatchLive = false
            }
        }

            if showExerciseDone {
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                        .padding(.bottom, 8)
                    Text("Exercise Complete!")
                        .font(.title2).fontWeight(.bold)
                    Text("Next up: \(exerciseDoneNextName)")
                        .foregroundColor(.secondary)
                }
                .padding(30)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(20)
                .shadow(radius: 20)
                .transition(.scale.combined(with: .opacity))
            }

            if session.isFinished {
                ZStack {
                    Color.black.opacity(0.85).edgesIgnoringSafeArea(.all)
                    VStack(spacing: 24) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 100))
                            .foregroundColor(.yellow)
                            .scaleEffect(finishedScale)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: finishedScale)
                            .onAppear { finishedScale = 1.15 }

                        Text("Workout Complete!")
                            .font(.largeTitle).fontWeight(.heavy).foregroundColor(.white)

                        Text("Great job finishing \(session.dayTitle).")
                            .foregroundColor(.gray)

                        Button(action: { dismiss() }) {
                            Text("Return to Dashboard")
                                .fontWeight(.bold).foregroundColor(.white)
                                .padding().frame(maxWidth: 250)
                                .background(Color.blue).cornerRadius(12)
                        }
                        .padding(.top, 40)
                    }
                }
                .transition(.opacity)
            }
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Start a new session only if this is a different workout or none is running
            let sameWorkout = session.dayTitle == dayTitle
                && session.exercises.map(\.exerciseId) == exercises.map(\.exerciseId)
            if !sameWorkout || session.exercises.isEmpty {
                session.startSession(dayTitle: dayTitle, exercises: exercises)
            }
            prefillInputs()
            updateWatchStartInfo()
            // Re-sync watch if rest was still ticking while away
            if session.restSecondsLeft > 0 {
                connector.sendRestUpdate(seconds: session.restSecondsLeft, sessionId: session.restSessionId)
            }
        }
        .onDisappear {
            session.finishSession()
        }
        .onChange(of: session.currentExerciseIndex) {
            prefillInputs()
            updateWatchStartInfo()
        }
        .onChange(of: session.currentSet) { prefillInputs() }
        .onChange(of: session.restSecondsLeft) { oldValue, newValue in
            // Keep watch in sync while view is visible
            connector.sendRestUpdate(seconds: newValue, sessionId: session.restSessionId)
        }
        .onChange(of: session.restJustFinished) { oldValue, finished in
            if finished {
                prefillInputs()
                updateWatchStartInfo()
            }
        }
        .onChange(of: showExerciseDone) { oldValue, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    withAnimation(.easeOut) { showExerciseDone = false }
                }
            }
        }
        .onChange(of: connector.workoutDoneToggle) {
            let reps: Int
            let weight: Int
            if connector.isFlick {
                let fallbackWeight = gymViewModel.lastPerformance[currentExercise.exerciseId]?.weightKg ?? 20
                let fallbackReps = gymViewModel.lastPerformance[currentExercise.exerciseId]?.reps ?? currentExercise.targetReps
                weight = Int(weightInput) ?? fallbackWeight
                reps = Int(repsInput) ?? fallbackReps
            } else {
                reps = connector.currentReps
                weight = connector.currentWeight
            }
            guard reps > 0, session.restSecondsLeft == 0 else { return }
            repsInput = "\(reps)"
            weightInput = "\(weight)"
            submitSet(weight: weight, reps: reps)
        }
        .onChange(of: connector.skipRestTriggerToggle) {
            session.skipRest()
            connector.sendRestUpdate(seconds: 0, sessionId: session.restSessionId)
            prefillInputs()
            updateWatchStartInfo()
        }
    }

    @ViewBuilder
    private var exerciseImage: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if !currentExercise.localImagePath.isEmpty,
                   let uiImage = UIImage(contentsOfFile: currentExercise.localImagePath) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else if let url = URL(string: currentExercise.imageUrl), !currentExercise.imageUrl.isEmpty {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        default: Color.gray.opacity(0.3)
                        }
                    }
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(Image(systemName: "photo").foregroundColor(.gray).font(.largeTitle))
                }
            }
            .frame(height: 210)
            .cornerRadius(16)

            if supportsImagePlayground {
                Button(action: { showImagePlayground = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("Reimagine")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .background(Color.blue.opacity(0.5))
                    .cornerRadius(8)
                }
                .padding(8)
            }
        }
        .imagePlaygroundSheet(
            isPresented: $showImagePlayground,
            concepts: [
                .text("\(currentExercise.name) exercise, fitness, gym, athletic, dynamic illustration")
            ]
        ) { url in
            if let savedURL = gymViewModel.imageService.saveSheetImage(url: url, exerciseName: currentExercise.name) {
                // Update the exercise model with the new local path
                if let plan = findCurrentPlan(), let day = findCurrentDay(in: plan) {
                    gymViewModel.updateExerciseLocalImage(
                        planId: plan.id,
                        dayId: day.id,
                        exerciseId: currentExercise.exerciseId,
                        localPath: savedURL.path
                    )
                }
                // Also update session exercise so the UI refreshes immediately
                if var exercises = Optional(session.exercises),
                   let idx = exercises.firstIndex(where: { $0.exerciseId == currentExercise.exerciseId }) {
                    exercises[idx].localImagePath = savedURL.path
                    session.updateExercises(exercises)
                }
            }
        }
    }

    /// Find which plan contains the current session exercises.
    private func findCurrentPlan() -> WorkoutPlan? {
        gymViewModel.workoutPlans.first { plan in
            plan.days.contains { day in
                day.exercises.contains { $0.exerciseId == currentExercise.exerciseId }
            }
        }
    }

    /// Find which day contains the current exercise in a given plan.
    private func findCurrentDay(in plan: WorkoutPlan) -> WorkoutDay? {
        plan.days.first { day in
            day.exercises.contains { $0.exerciseId == currentExercise.exerciseId }
        }
    }

    private func prefillInputs() {
        guard !session.exercises.isEmpty else { return }
        if let last = gymViewModel.lastPerformance[currentExercise.exerciseId] {
            weightInput = "\(last.weightKg)"
            repsInput = "\(last.reps)"
        } else {
            weightInput = "20"
            repsInput = "\(currentExercise.targetReps)"
        }
    }

    private func submitSet(weight: Int, reps: Int) {
        guard let ex = session.currentExercise, ex.sets > 0 else { return }
        gymViewModel.recordSet(exerciseId: ex.exerciseId, weightKg: weight, reps: reps)

        if session.hasMoreSets {
            let pending = PendingProgress(
                nextExerciseIndex: session.currentExerciseIndex,
                nextSet: session.currentSet + 1,
                label: "Next: \(ex.name) — set \(session.currentSet + 1)"
            )
            session.startRest(pending: pending)
            connector.sendRestUpdate(seconds: session.maxRestSeconds, sessionId: session.restSessionId)
        } else if session.hasNextExercise {
            let nextEx = session.exercises[session.currentExerciseIndex + 1]
            exerciseDoneNextName = nextEx.name
            withAnimation(.spring()) { showExerciseDone = true }
            let pending = PendingProgress(
                nextExerciseIndex: session.currentExerciseIndex + 1,
                nextSet: 1,
                label: "Next: \(nextEx.name)"
            )
            session.startRest(pending: pending)
            connector.sendRestUpdate(seconds: session.maxRestSeconds, sessionId: session.restSessionId)
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                session.finishSession()
                finishedScale = 1.0
            }
        }
    }

    private func updateWatchStartInfo() {
        let weight = Int(weightInput) ?? 0
        connector.sendStartWorkoutInfo(exerciseName: currentExercise.name, startingWeight: weight)
    }
}

// MARK: - Watch Live View (shown as sheet when watch is in warmup/counting)

struct WatchLiveView: View {
    @ObservedObject var connector: PhoneWatchConnector
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                switch connector.watchState {
                case "warmupCountdown":
                    WatchWarmupCountdownPage()
                case "warmupRecording":
                    WatchWarmupRecordingPage(repsDetected: connector.watchWarmupReps)
                case "counting":
                    WatchCountingPage(reps: connector.watchLiveReps, speedHistory: connector.speedHistory, fastWarningSpeed: connector.fastWarningSpeed)
                default:
                    WatchCountingPage(reps: connector.watchLiveReps, speedHistory: connector.speedHistory, fastWarningSpeed: connector.fastWarningSpeed)
                }
                Button("Dismiss") { dismiss() }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 24)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

private struct WatchWarmupCountdownPage: View {
    var body: some View {
        Spacer()
        VStack(spacing: 16) {
            Image(systemName: "applewatch.radiowaves.left.and.right")
                .font(.system(size: 44))
                .foregroundStyle(.blue.opacity(0.8))
            Text("GET READY")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.blue)
                .kerning(3)
            Text("Do 5 warm-up reps on your watch")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        Spacer()
    }
}

private struct WatchWarmupRecordingPage: View {
    let repsDetected: Int

    var body: some View {
        Spacer()
        VStack(spacing: 24) {
            Image(systemName: "applewatch.radiowaves.left.and.right")
                .font(.system(size: 44))
                .foregroundStyle(.cyan.opacity(0.8))

            Text("CALIBRATING")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.cyan)
                .kerning(3)

            // Dot progress
            HStack(spacing: 14) {
                ForEach(0..<5) { i in
                    Circle()
                        .fill(i < repsDetected ? Color.cyan : Color.white.opacity(0.15))
                        .frame(width: 14, height: 14)
                        .scaleEffect(i < repsDetected ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3), value: repsDetected)
                }
            }

            Text("\(repsDetected) / 5")
                .font(.system(size: 72, weight: .black, design: .rounded))
                .foregroundStyle(.cyan)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.2), value: repsDetected)

            Text("warm-up reps detected")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, 32)
        Spacer()
    }
}

private struct WatchCountingPage: View {
    let reps: Int
    let speedHistory: [Float]
    let fastWarningSpeed: Float

    private var isTooFast: Bool {
        fastWarningSpeed > 0 && (speedHistory.last ?? 0) > fastWarningSpeed
    }

    var body: some View {
        Spacer()
        VStack(spacing: 16) {
            Image(systemName: "applewatch.radiowaves.left.and.right")
                .font(.system(size: 44))
                .foregroundStyle(.green.opacity(0.8))

            if isTooFast {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("SLOW DOWN")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.orange)
                        .kerning(3)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            } else {
                Text("COUNTING REPS")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.green)
                    .kerning(3)
                    .transition(.opacity)
            }

            Text("\(reps)")
                .font(.system(size: 100, weight: .black, design: .rounded))
                .foregroundStyle(isTooFast ? .orange : .green)
                .shadow(color: (isTooFast ? Color.orange : Color.green).opacity(0.4), radius: 20)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.2), value: reps)

            Text("REPS")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle((isTooFast ? Color.orange : Color.green).opacity(0.6))
                .kerning(4)

            SpeedChart(speedHistory: speedHistory, fastWarningSpeed: fastWarningSpeed)

            Text("Flick wrist × 4 or tap Log Set on watch to finish")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .animation(.easeInOut(duration: 0.25), value: isTooFast)
        Spacer()
    }
}

private struct SpeedChart: View {
    let speedHistory: [Float]
    let fastWarningSpeed: Float

    private var currentSpeed: Float { speedHistory.last ?? 0 }
    private var isTooFast: Bool { fastWarningSpeed > 0 && currentSpeed > fastWarningSpeed }
    private var chartMax: Double {
        let dataMax = Double(speedHistory.max() ?? 0)
        let warnLine = Double(fastWarningSpeed)
        return max(dataMax, warnLine, 0.1) * 1.15
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("MOVEMENT SPEED")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isTooFast ? .orange.opacity(0.8) : .green.opacity(0.5))
                    .kerning(2)
                Spacer()
                if isTooFast {
                    Label("Too fast", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.orange)
                        .transition(.opacity)
                }
            }

            if speedHistory.count > 1 {
                Chart {
                    ForEach(Array(speedHistory.enumerated()), id: \.offset) { idx, speed in
                        AreaMark(
                            x: .value("Sample", idx),
                            y: .value("Speed", Double(speed))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: isTooFast
                                    ? [.orange.opacity(0.3), .clear]
                                    : [.green.opacity(0.25), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Sample", idx),
                            y: .value("Speed", Double(speed))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(isTooFast ? Color.orange : Color.green)
                    }

                    // Warning threshold line
                    if fastWarningSpeed > 0 {
                        RuleMark(y: .value("Limit", Double(fastWarningSpeed)))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .foregroundStyle(.orange.opacity(0.6))
                            .annotation(position: .trailing, alignment: .leading) {
                                Text("limit")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.orange.opacity(0.5))
                            }
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: 0...chartMax)
                .frame(height: 72)
                .animation(.easeInOut(duration: 0.2), value: isTooFast)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.green.opacity(0.05))
                    .frame(height: 72)
                    .overlay(
                        Text("Start moving to see speed")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.2))
                    )
            }

            HStack {
                Text("0")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.2))
                Spacer()
                if fastWarningSpeed > 0 {
                    Text(String(format: "limit %.2f m/s", fastWarningSpeed))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.orange.opacity(0.4))
                } else {
                    Text(String(format: "%.2f m/s peak", Double(speedHistory.max() ?? 0)))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Rest Timer Card

private struct RestTimerCard: View {
    @ObservedObject var session: WorkoutSessionManager
    let onSkip: () -> Void

    var body: some View {
        Group {
            if session.restJustFinished {
                restCompleteView
            } else {
                activeRestView
            }
        }
        .animation(.easeInOut(duration: 0.3), value: session.restJustFinished)
    }

    private var activeRestView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.15), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: session.restProgress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: session.restProgress)
                }
                .frame(width: 44, height: 44)
                .overlay(
                    Text(formatSeconds(session.restSecondsLeft))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Resting")
                        .font(.subheadline).fontWeight(.semibold)
                    if let pending = session.pendingProgress {
                        Text(pending.label)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(action: onSkip) {
                    Text("Skip")
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
            }

            ProgressView(value: session.restProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.blue.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.blue.opacity(0.25), lineWidth: 1))
        )
    }

    private var restCompleteView: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .foregroundColor(.green)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Rest over — next set ready!")
                    .font(.subheadline).fontWeight(.semibold).foregroundColor(.green)
            }
            Spacer()
            Button(action: { session.clearRestJustFinished() }) {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.green.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.3), lineWidth: 1))
        )
    }
}

// MARK: - Stats View
struct StatsView: View {
    @EnvironmentObject var gymViewModel: GymViewModel
    @State private var selectedExerciseId: String = ""

    private var sortedExercises: [String] {
        gymViewModel.exerciseHistory.keys.sorted()
    }

    private var selectedStats: [SessionStat] {
        gymViewModel.exerciseHistory[selectedExerciseId] ?? []
    }

    private func exerciseName(for id: String) -> String {
        for plan in gymViewModel.workoutPlans {
            for day in plan.days {
                if let ex = day.exercises.first(where: { $0.exerciseId == id }) {
                    return ex.name
                }
            }
        }
        return id.replacingOccurrences(of: "local_", with: "").replacingOccurrences(of: "_", with: " ").capitalized
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if gymViewModel.exerciseHistory.isEmpty {
                        noStatsView
                    } else {
                        statsDashboard
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Analytics")
            .onAppear {
                if selectedExerciseId.isEmpty, let first = sortedExercises.first {
                    selectedExerciseId = first
                }
            }
            .onChange(of: sortedExercises) { oldValue, newValue in
                if (selectedExerciseId.isEmpty || !newValue.contains(selectedExerciseId)), let first = newValue.first {
                    selectedExerciseId = first
                }
            }
        }
    }

    private var noStatsView: some View {
        VStack(spacing: 30) {
            Spacer()
                .frame(height: 40)
            
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "chart.xyaxis.line")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 12) {
                Text("No Analytics Available")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("To see your lifting statistics and charts, start a workout session and log completed sets.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }

    private var statsDashboard: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Summary Cards Grid
            VStack(alignment: .leading, spacing: 10) {
                Text("Overview")
                    .font(.headline)
                    .padding(.horizontal)
                
                let totalVolume = gymViewModel.exerciseHistory.values.flatMap { $0 }.map { $0.totalVolume }.reduce(0, +)
                let totalReps = gymViewModel.exerciseHistory.values.flatMap { $0 }.map { $0.totalReps }.reduce(0, +)
                let totalSets = gymViewModel.exerciseHistory.values.flatMap { $0 }.map { $0.setCount }.reduce(0, +)
                let totalWorkouts = Set(gymViewModel.exerciseHistory.values.flatMap { $0 }.map { Calendar.current.startOfDay(for: $0.date) }).count

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    summaryCard(title: "Lifetime Volume", value: "\(totalVolume) kg", icon: "scalemass.fill", color: .blue)
                    summaryCard(title: "Workouts Done", value: "\(totalWorkouts)", icon: "figure.strengthtraining.traditional", color: .green)
                    summaryCard(title: "Total Sets Logged", value: "\(totalSets)", icon: "number.circle.fill", color: .purple)
                    summaryCard(title: "Total Reps Logged", value: "\(totalReps)", icon: "checkmark.circle.fill", color: .orange)
                }
                .padding(.horizontal)
            }
            
            // Exercise Selector
            VStack(alignment: .leading, spacing: 12) {
                Text("Select Exercise")
                    .font(.headline)
                    .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(sortedExercises, id: \.self) { exId in
                            let isSelected = exId == selectedExerciseId
                            let name = exerciseName(for: exId)
                            
                            Button(action: {
                                withAnimation {
                                    selectedExerciseId = exId
                                }
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(name)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(isSelected ? .white : .primary)
                                        .lineLimit(1)
                                    
                                    if let last = gymViewModel.lastPerformance[exId] {
                                        Text("\(last.weightKg) kg × \(last.reps) reps")
                                            .font(.caption)
                                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSelected ? Color.clear : Color.gray.opacity(0.15), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Selected Exercise Charts
            if !selectedExerciseId.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    let stats = selectedStats
                    
                    if stats.count > 1 {
                        // Average Weight Chart
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Weight Progression (Avg)")
                                .font(.headline)
                            Text("Your average lifted weight per set")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Chart {
                                ForEach(stats, id: \.date) { stat in
                                    LineMark(
                                        x: .value("Date", stat.date),
                                        y: .value("Avg Weight (kg)", stat.avgWeight)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(Color.blue)
                                    .lineStyle(StrokeStyle(lineWidth: 3))
                                    
                                    PointMark(
                                        x: .value("Date", stat.date),
                                        y: .value("Avg Weight (kg)", stat.avgWeight)
                                    )
                                    .foregroundStyle(Color.blue)
                                }
                            }
                            .frame(height: 180)
                            .padding(.vertical)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        // Volume Chart
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Volume Progression")
                                .font(.headline)
                            Text("Total weight × reps per session")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Chart {
                                ForEach(stats, id: \.date) { stat in
                                    AreaMark(
                                        x: .value("Date", stat.date),
                                        y: .value("Volume (kg)", stat.totalVolume)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.green.opacity(0.25), Color.green.opacity(0.0)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    
                                    LineMark(
                                        x: .value("Date", stat.date),
                                        y: .value("Volume (kg)", stat.totalVolume)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(Color.green)
                                    .lineStyle(StrokeStyle(lineWidth: 3))
                                }
                            }
                            .frame(height: 180)
                            .padding(.vertical)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    } else if stats.count == 1 {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.blue)
                            Text("More Data Needed")
                                .font(.headline)
                            Text("Log sets across multiple days to view progression graphs.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    
                    // Historical Log
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Session History")
                            .font(.headline)
                        
                        ForEach(stats.reversed(), id: \.date) { stat in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(stat.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                    
                                    Text("\(stat.setCount) sets logged")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(String(format: "%.1f kg avg", stat.avgWeight))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                    
                                    Text("\(stat.totalVolume) kg vol")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Account Screen
struct AccountView: View {
    @EnvironmentObject var gymViewModel: GymViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Profile Information")) {
                    HStack {
                        Text("Weight (kg)")
                        Spacer()
                        TextField("Weight", text: $gymViewModel.accountInfo.weightKg)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Height (cm)")
                        Spacer()
                        TextField("Height", text: $gymViewModel.accountInfo.heightCm)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Age")
                        Spacer()
                        TextField("Age", text: $gymViewModel.accountInfo.age)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Gender")
                        Spacer()
                        TextField("Gender", text: $gymViewModel.accountInfo.gender)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Activity")
                        Spacer()
                        TextField("Activity", text: $gymViewModel.accountInfo.activityLevel)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Goals")
                        Spacer()
                        TextField("Goals", text: $gymViewModel.accountInfo.goals)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    Button(action: {}) {
                        Text("Log Out")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Account")
        }
    }
}

// MARK: - Trainer Screen

struct TrainerView: View {
    @EnvironmentObject var gymViewModel: GymViewModel
    @EnvironmentObject var aiManager: AIManager
    @State private var messageInput = ""
    @State private var showCommandSuggestions = false
    @State private var showPlanPicker = false

    private var isCommandMode: Bool {
        gymViewModel.commandMode != .none
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status bar
                HStack(spacing: 6) {
                    Circle()
                        .fill(aiManager.isModelLoaded ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(aiManager.isModelLoaded ? "Trainer ready" : "Loading local model…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                // Chat scroll area
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(gymViewModel.chatMessages) { msg in
                                TrainerChatBubble(message: msg)
                                    .id(msg.id)
                            }
                            if gymViewModel.isTrainerResponding {
                                TrainerThinkingBubble()
                                    .id("thinking")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: gymViewModel.chatMessages.count) { _ in
                        withAnimation {
                            if let last = gymViewModel.chatMessages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: gymViewModel.isTrainerResponding) { responding in
                        if responding {
                            withAnimation { proxy.scrollTo("thinking", anchor: .bottom) }
                        }
                    }
                }

                Divider()

                // Slash-command suggestion strip
                if showCommandSuggestions {
                    TrainerCommandSuggestionsBar(
                        onSelectCreate: {
                            withAnimation {
                                gymViewModel.commandMode = .createWorkout
                                messageInput = ""
                                showCommandSuggestions = false
                            }
                        },
                        onSelectEdit: {
                            withAnimation {
                                messageInput = ""
                                showCommandSuggestions = false
                            }
                            showPlanPicker = true
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Mention tag (active command context)
                if isCommandMode {
                    TrainerCommandMentionTag(mode: gymViewModel.commandMode) {
                        withAnimation { gymViewModel.commandMode = .none }
                    }
                    .padding(.horizontal)
                    .padding(.top, 6)
                }

                // Input bar
                HStack(spacing: 8) {
                    TextField(inputPlaceholder, text: $messageInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: messageInput) { newValue in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showCommandSuggestions = (newValue == "/")
                            }
                        }

                    Button(action: performSend) {
                        Image(systemName: "paperplane.fill")
                            .font(.title2)
                            .foregroundColor(canSend ? .blue : .gray)
                    }
                    .disabled(!canSend)
                }
                .padding()
            }
            .navigationTitle("Trainer")
            .sheet(isPresented: $showPlanPicker) {
                TrainerPlanDayPickerSheet(
                    plans: gymViewModel.workoutPlans,
                    onSelect: { plan, scope in
                        gymViewModel.commandMode = .editWorkout(plan: plan, scope: scope)
                        showPlanPicker = false
                    },
                    onCancel: { showPlanPicker = false }
                )
            }
        }
    }

    private var inputPlaceholder: String {
        switch gymViewModel.commandMode {
        case .none: return "Ask your trainer or type / for commands…"
        case .createWorkout: return "What kind of plan? (e.g. 5-day hypertrophy split)"
        case .editWorkout: return "Describe the changes…"
        }
    }

    private var canSend: Bool {
        guard !gymViewModel.isTrainerResponding else { return false }
        switch gymViewModel.commandMode {
        case .none: return !messageInput.trimmingCharacters(in: .whitespaces).isEmpty
        case .createWorkout: return true  // empty intent uses a sensible default
        case .editWorkout: return !messageInput.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func performSend() {
        let text = messageInput.trimmingCharacters(in: .whitespacesAndNewlines)
        messageInput = ""
        showCommandSuggestions = false
        gymViewModel.sendCommandChat(userIntent: text)
    }
}

// MARK: - Chat Bubble Views

struct TrainerChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.byUser { Spacer(minLength: 48) }
            Text(message.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.byUser ? Color.blue : Color(.systemGray5))
                .foregroundColor(message.byUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            if !message.byUser { Spacer(minLength: 48) }
        }
    }
}

struct TrainerThinkingBubble: View {
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.75)
                Text("Trainer is thinking…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            Spacer(minLength: 48)
        }
    }
}

// MARK: - Command UI Components

struct TrainerCommandSuggestionsBar: View {
    let onSelectCreate: () -> Void
    let onSelectEdit: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                TrainerCommandChip(
                    icon: "sparkles",
                    title: "create workout",
                    subtitle: "Build a new plan from scratch",
                    tint: .blue,
                    action: onSelectCreate
                )
                TrainerCommandChip(
                    icon: "pencil.and.list.clipboard",
                    title: "edit workout",
                    subtitle: "Modify an existing plan",
                    tint: .orange,
                    action: onSelectEdit
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.06), radius: 4, y: -2)
    }
}

struct TrainerCommandChip: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(tint)
                    .font(.subheadline)
                VStack(alignment: .leading, spacing: 2) {
                    Text("/\(title)")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(tint.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(tint.opacity(0.25), lineWidth: 1)
            )
        }
    }
}

struct TrainerCommandMentionTag: View {
    let mode: TrainerCommandMode
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: modeIcon)
                .font(.caption)
                .foregroundColor(modeColor)
            Text(modeLabel)
                .font(.caption.bold())
                .foregroundColor(modeColor)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(modeColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var modeIcon: String {
        switch mode {
        case .none: return "questionmark"
        case .createWorkout: return "sparkles"
        case .editWorkout: return "pencil"
        }
    }

    private var modeLabel: String {
        switch mode {
        case .none: return ""
        case .createWorkout: return "/create workout"
        case .editWorkout(let plan, let scope): return "/edit \(plan.name) · \(scope.displayTitle)"
        }
    }

    private var modeColor: Color {
        switch mode {
        case .none: return .gray
        case .createWorkout: return .blue
        case .editWorkout: return .orange
        }
    }
}

// MARK: - Plan / Day Picker Sheet

struct TrainerPlanDayPickerSheet: View {
    let plans: [WorkoutPlan]
    let onSelect: (WorkoutPlan, EditScope) -> Void
    let onCancel: () -> Void

    @State private var selectedPlan: WorkoutPlan? = nil

    var body: some View {
        NavigationStack {
            if let plan = selectedPlan {
                dayPickerList(for: plan)
                    .navigationTitle("Select Scope")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Back") { selectedPlan = nil }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Cancel") { onCancel() }
                        }
                    }
            } else {
                planPickerList()
                    .navigationTitle("Edit Workout")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Cancel") { onCancel() }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func planPickerList() -> some View {
        if plans.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "tray")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text("No plans yet")
                    .font(.headline)
                Text("Use /create workout to build your first plan.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else {
            List(plans) { plan in
                Button {
                    selectedPlan = plan
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("\(plan.days.count) day\(plan.days.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func dayPickerList(for plan: WorkoutPlan) -> some View {
        List {
            Section {
                Button {
                    onSelect(plan, .allDays)
                } label: {
                    Label("All Days", systemImage: "calendar")
                        .foregroundColor(.primary)
                        .font(.body.bold())
                }
            }
            Section("Or pick a specific day") {
                ForEach(plan.days) { day in
                    Button {
                        onSelect(plan, .specificDay(day))
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(day.title)
                                .font(.body)
                                .foregroundColor(.primary)
                            Text("\(day.exercises.count) exercise\(day.exercises.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }
}

// MARK: - Live Camera (AVFoundation + Vision Framework Rep Counter)
struct LivePoseCameraView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var poseEstimator = PoseEstimator()

    private let poseConnections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.leftShoulder, .rightShoulder),
        (.leftHip, .rightHip),
        (.leftShoulder, .leftElbow),
        (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow),
        (.rightElbow, .rightWrist),
        (.leftShoulder, .leftHip),
        (.rightShoulder, .rightHip),
        (.leftHip, .leftKnee),
        (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee),
        (.rightKnee, .rightAnkle)
    ]

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            GeometryReader { geometry in
                ZStack {
                    CameraPreview(session: poseEstimator.captureSession)
                        .ignoresSafeArea()

                    Canvas { context, size in
                        let frameSize = poseEstimator.frameSize
                        guard frameSize.width > 0, frameSize.height > 0 else { return }

                        let scale = max(size.width / frameSize.width, size.height / frameSize.height)
                        let scaledWidth = frameSize.width * scale
                        let scaledHeight = frameSize.height * scale
                        let offsetX = (size.width - scaledWidth) / 2
                        let offsetY = (size.height - scaledHeight) / 2

                        func point(for joint: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
                            guard let overlayPoint = poseEstimator.overlayPoints.first(where: { $0.id == joint.rawValue.rawValue }) else { return nil }
                            let x = overlayPoint.location.x * frameSize.width * scale + offsetX
                            let y = (1 - overlayPoint.location.y) * frameSize.height * scale + offsetY
                            return CGPoint(x: x, y: y)
                        }

                        for (startJoint, endJoint) in poseConnections {
                            guard let start = point(for: startJoint), let end = point(for: endJoint) else { continue }
                            var path = Path()
                            path.move(to: start)
                            path.addLine(to: end)
                            context.stroke(path, with: .color(.green.opacity(0.9)), lineWidth: 5)
                        }

                        for joint in poseEstimator.overlayPoints {
                            let x = joint.location.x * frameSize.width * scale + offsetX
                            let y = (1 - joint.location.y) * frameSize.height * scale + offsetY
                            let pointRect = CGRect(x: x - 5, y: y - 5, width: 10, height: 10)
                            context.fill(Path(ellipseIn: pointRect), with: .color(.red))
                        }
                    }
                    .ignoresSafeArea()
                    .scaleEffect(x: -1, y: 1)

                    VStack {
                        HStack {
                            Button(action: {
                                poseEstimator.stopSession()
                                dismiss()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                        .padding()

                        Spacer()
                    }

                    VStack(spacing: 4) {
                        Text("\(poseEstimator.repCount)")
                            .font(.system(size: 72, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                        Text("reps")
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(20)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .onAppear {
            poseEstimator.startSession()
        }
        .onDisappear {
            poseEstimator.stopSession()
        }
    }
}

private func formatSeconds(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let remaining = seconds % 60
    return String(format: "%02d:%02d", minutes, remaining)
}
