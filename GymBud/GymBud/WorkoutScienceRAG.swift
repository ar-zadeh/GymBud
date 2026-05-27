import Foundation
import Accelerate
import CoreML

// MARK: - Science Section Model

struct ScienceSection: Sendable {
    let title: String
    let content: String
    let keywords: Set<String>
}

// MARK: - Workout Science RAG
//
// Two-tier retrieval over the "Workout Science LLM Prompt Generation 2020-2025" synthesis:
//
//   Tier 1 — Semantic search (primary):
//     At startup, each section is embedded on-device using the bundled CoreML model
//     (all-MiniLM-L6-v2, 384-dim L2-normalised vectors, BertTokenizer WordPiece).
//     Query embeddings are computed locally; cosine similarity = dot product (vDSP_dotpr).
//
//   Tier 2 — Keyword search (fallback):
//     Used when the CoreML model fails to load (e.g. missing bundle file).
//     Scores sections by keyword overlap against query + user profile.
//
// Source document: GymBud/Workout Science LLM Prompt Generation.md

@MainActor
final class WorkoutScienceRAG {
    static let shared = WorkoutScienceRAG()
    private init() {}

    // Cached per-section embeddings (set once by precomputeSectionEmbeddings).
    private var sectionEmbeddings: [[Float]]? = nil
    private var mlModel: MiniLMEmbedder?

    // MARK: - Public API

    /// Call once at app startup (from a background Task) to warm up section embeddings.
    /// Safe to call multiple times — skips if embeddings are already cached.
    func precomputeSectionEmbeddings() async {
        guard sectionEmbeddings == nil else { return }

        if mlModel == nil {
            do {
                let config = MLModelConfiguration()
                config.computeUnits = .cpuAndNeuralEngine
                mlModel = try MiniLMEmbedder(configuration: config)
            } catch {
                print("WorkoutScienceRAG: CoreML model load failed: \(error) — keyword fallback active")
                return
            }
        }

        var embeddings: [[Float]] = []
        embeddings.reserveCapacity(scienceSections.count)

        for section in scienceSections {
            let text = section.title + ". " + section.content
            guard let emb = embedLocally(text) else {
                print("WorkoutScienceRAG: failed to embed '\(section.title)' — aborting precomputation")
                return
            }
            embeddings.append(emb)
        }

        sectionEmbeddings = embeddings
        print("WorkoutScienceRAG: pre-computed \(embeddings.count) section embeddings on-device ✓")
    }

    /// Returns up to maxSections most relevant sections for query + profile.
    /// Returns empty array when no section clears the relevance threshold
    /// (e.g. user provides their own complete exercise spec — science context is skipped).
    func relevantSections(
        query: String,
        profile: AccountInfo,
        maxSections: Int = 3
    ) async -> [ScienceSection] {
        let enrichedQuery = buildEnrichedQuery(query: query, profile: profile)

        if let sectionEmbs = sectionEmbeddings,
           let queryEmb = embedLocally(enrichedQuery) {
            return semanticSearch(
                queryEmbedding: queryEmb,
                sectionEmbeddings: sectionEmbs,
                maxSections: maxSections
            )
        }

        // Keyword fallback
        return keywordSearch(query: query, profile: profile, maxSections: maxSections)
    }

    /// Formats selected sections into a <science_context> block ready for prompt injection.
    func formatForPrompt(_ sections: [ScienceSection]) -> String {
        guard !sections.isEmpty else { return "" }
        var out = "<science_context source=\"2020-2025 Exercise Science Synthesis\">\n"
        for section in sections {
            out += "\n[\(section.title)]\n\(section.content)\n"
        }
        out += "</science_context>\n"
        return out
    }

    // MARK: - Semantic search

    private func semanticSearch(
        queryEmbedding: [Float],
        sectionEmbeddings: [[Float]],
        maxSections: Int
    ) -> [ScienceSection] {
        let scored: [(ScienceSection, Float)] = zip(scienceSections, sectionEmbeddings).map { section, sEmb in
            (section, cosineSimilarity(queryEmbedding, sEmb))
        }

        // Threshold: 0.25 filters genuinely unrelated sections while keeping borderline ones
        return scored
            .filter { $0.1 > 0.25 }
            .sorted { $0.1 > $1.1 }
            .prefix(maxSections)
            .map { $0.0 }
    }

    // With L2-normalised embeddings, cosine similarity == dot product.
    // vDSP_dotpr operates on raw Float arrays — much faster than zip+map for 384 dims.
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var result: Float = 0
        vDSP_dotpr(a, 1, b, 1, &result, vDSP_Length(a.count))
        return result
    }

    // MARK: - Keyword fallback

    private func keywordSearch(
        query: String,
        profile: AccountInfo,
        maxSections: Int
    ) -> [ScienceSection] {
        let q = query.lowercased()
        let profileText = [profile.age, profile.gender, profile.goals, profile.activityLevel]
            .joined(separator: " ").lowercased()

        var scored: [(section: ScienceSection, score: Int)] = scienceSections.map { section in
            var score = 0
            for kw in section.keywords {
                if q.contains(kw) { score += 2 }
                if profileText.contains(kw) { score += 1 }
            }
            return (section, score)
        }

        // Age-range hard-boost for demographic-specific sections
        if let age = Int(profile.age.trimmingCharacters(in: .whitespacesAndNewlines)) {
            boost(sectionTitle: "Middle-Aged Adults (40\u{2013}60)", in: &scored, by: 6, when: age >= 40 && age < 65)
            boost(sectionTitle: "Older Adults (65+)", in: &scored, by: 6, when: age >= 65)
        }

        return scored
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .prefix(maxSections)
            .map { $0.section }
    }

    private func boost(sectionTitle: String, in scored: inout [(section: ScienceSection, score: Int)], by amount: Int, when condition: Bool) {
        guard condition else { return }
        if let idx = scored.firstIndex(where: { $0.section.title == sectionTitle }) {
            scored[idx].score += amount
        }
    }

    // MARK: - On-device embedding

    private func embedLocally(_ text: String) -> [Float]? {
        guard let model = mlModel else { return nil }
        let enc = BertTokenizer.shared.encode(text)
        let seqLen = BertTokenizer.maxLength
        do {
            let shape: [NSNumber] = [1, NSNumber(value: seqLen)]
            let idArray   = try MLMultiArray(shape: shape, dataType: .int32)
            let maskArray = try MLMultiArray(shape: shape, dataType: .int32)
            let typeArray = try MLMultiArray(shape: shape, dataType: .int32)
            for i in 0..<seqLen {
                idArray[i]   = NSNumber(value: enc.inputIds[i])
                maskArray[i] = NSNumber(value: enc.attentionMask[i])
                typeArray[i] = NSNumber(value: enc.tokenTypeIds[i])
            }
            let out = try model.prediction(input_ids: idArray, attention_mask: maskArray, token_type_ids: typeArray)
            return (0..<384).map { Float(truncating: out.embedding[$0]) }
        } catch {
            print("WorkoutScienceRAG: CoreML inference failed: \(error)")
            return nil
        }
    }

    // MARK: - Helpers

    // Enrich the query with profile context so the embedding better captures
    // demographic relevance (e.g. "age 65" nudges the query toward aging sections).
    private func buildEnrichedQuery(query: String, profile: AccountInfo) -> String {
        var parts = [query]
        if !profile.goals.trimmingCharacters(in: .whitespaces).isEmpty {
            parts.append("Goals: \(profile.goals)")
        }
        if !profile.age.trimmingCharacters(in: .whitespaces).isEmpty {
            parts.append("Age: \(profile.age)")
        }
        if !profile.activityLevel.trimmingCharacters(in: .whitespaces).isEmpty {
            parts.append("Activity level: \(profile.activityLevel)")
        }
        return parts.joined(separator: ". ")
    }

    // MARK: - Knowledge Base
    // Condensed, actionable distillation of the source document.
    // Full source: GymBud/Workout Science LLM Prompt Generation.md

    let scienceSections: [ScienceSection] = [

        ScienceSection(
            title: "Training Volume & Frequency",
            content: """
            Training volume (hard sets per muscle/week) is the primary hypertrophy driver. \
            Minimum effective dose: 4 sets/muscle/week (sufficient for beginners and health maintenance). \
            Optimal hypertrophy range: 10–20 sets/muscle/week using fractional counting (compound = 1.0 \
            for primary muscle, 0.5 for synergists). Per-session cap: 4–8 direct sets per muscle group; \
            beyond this mTORC1 saturates and junk volume accumulates. Distribute volume across ≥2 \
            sessions/week — training a muscle once/week is significantly inferior to twice/week at equated \
            volume. Split selection (PPL, Upper/Lower, Full-Body) should be driven by volume requirements \
            and scheduling, not inherent superiority. For maximal strength, higher frequency (3–4×/week) \
            accelerates motor learning and neural efficiency by up to 50%.
            """,
            keywords: ["volume", "sets", "frequency", "weekly", "hypertrophy", "muscle", "growth",
                       "mass", "split", "days", "ppl", "push pull", "upper lower", "full body"]
        ),

        ScienceSection(
            title: "Load, Intensity & Proximity to Failure",
            content: """
            Hypertrophy is largely load-independent: equivalent growth occurs from heavy (>80% 1RM, \
            1–5 reps) to light loads (<50% 1RM, 25–30 reps) when sets are taken near failure. Sets \
            should reach RPE 8–10 (0–2 reps in reserve) for maximal hypertrophic stimulus. Novices \
            achieve robust gains several reps shy of failure; advanced trainees must approach failure \
            to overcome anabolic resistance. Maximal strength is load-dependent: loads >80% 1RM are \
            required to optimise neural rate coding, motor unit synchronisation, and antagonist \
            co-contraction reduction. Do not prescribe loads <50% 1RM for older adults unless taken \
            to absolute failure (near-zero strength gains otherwise).
            """,
            keywords: ["load", "intensity", "rpe", "failure", "reps", "heavy", "light", "strength",
                       "1rm", "power", "beginner", "advanced", "novice", "near failure"]
        ),

        ScienceSection(
            title: "Rest Periods & Recovery Between Sets",
            content: """
            Resting >60 seconds is superior to short rest for both strength and hypertrophy \
            (phosphocreatine resynthesis, CNS recovery). Isolation exercises (curls, lateral raises): \
            90 seconds–2 minutes. Compound multi-joint exercises (squats, deadlifts, rows, bench \
            press): 2–4 minutes. Maximal strength peaking: 3–5 minutes. Females can tolerate shorter \
            rest periods due to superior fatigue resistance and faster inter-set recovery. Super-slow \
            reps (>10 s/rep) are counterproductive — they require lighter loads and reduce total \
            mechanical tension.
            """,
            keywords: ["rest", "recovery", "inter-set", "fatigue", "compound", "isolation",
                       "pause", "rest period", "rest time"]
        ),

        ScienceSection(
            title: "Sex-Specific Programming",
            content: """
            Relative hypertrophy potential is identical between males and females — percentage \
            gains from individual baselines are equivalent. Untrained females may show higher \
            initial relative upper-body strength gains than males due to rapid neural adaptations \
            in underutilised musculature. Females exhibit superior fatigue resistance (higher Type I \
            fibre proportion, greater capillary density) and faster inter-set recovery — can tolerate \
            shorter rest periods or slightly higher per-session volume. Endogenous estradiol provides \
            anabolic and anti-catabolic properties that partially offset lower testosterone. Volume \
            prescriptions are sex-agnostic; do not fundamentally alter programme architecture based \
            on sex.
            """,
            keywords: ["female", "male", "women", "men", "sex", "gender", "girl", "woman",
                       "testosterone", "estrogen"]
        ),

        ScienceSection(
            title: "Middle-Aged Adults (40\u{2013}60)",
            content: """
            Middle-aged adults face sarcopenia onset (muscle mass loss ~1.5%/year after 50) and \
            dynapenia (strength loss 1–2%/year). Prioritise Functional Resistance Training (FRT): \
            multiplanar, multi-joint movements — squats, lunges, hip hinges, gait training, dynamic \
            push/pull variations. FRT improves movement efficiency, coordination, and balance while \
            reducing perceived exertion by 27% vs. machine-only routines, yielding superior long-term \
            adherence. Accumulate 2.5–5 hours/week of moderate-to-vigorous resistance work. Heavy \
            compound movements remain important; pair with functional, multiplanar variations for \
            daily-life movement preservation.
            """,
            keywords: ["40", "41", "42", "43", "44", "45", "46", "47", "48", "49", "50", "51",
                       "52", "53", "54", "55", "56", "57", "58", "59", "60", "middle", "functional",
                       "sarcopenia", "aging", "age"]
        ),

        ScienceSection(
            title: "Older Adults (65+)",
            content: """
            For adults 65+, resistance training is a critical medical intervention to preserve \
            independence and mortality resistance. Prescribe heavy loads (70–85% 1RM), not light \
            weights — loads <50% 1RM produce near-zero strength improvement without absolute \
            failure. 2–3 sets per major muscle group, 2–3 sessions/week. Never exceed 3 sessions/ \
            week per muscle due to blunted recovery from anabolic resistance, inflammaging (elevated \
            IL-6, TNF-alpha), and mitochondrial dysfunction. Critically include explosive power \
            training at 40–60% 1RM with maximal concentric velocity — power declines faster than \
            strength in aging; rapid force development (RFD) prevents falls. Focus on multi-joint \
            functional movements that mirror daily activities.
            """,
            keywords: ["65", "66", "67", "68", "69", "70", "71", "72", "73", "74", "75", "76",
                       "77", "78", "79", "80", "older", "senior", "elderly", "sarcopenia",
                       "dynapenia", "fall", "independence"]
        ),

        ScienceSection(
            title: "Fat Loss & Body Recomposition",
            content: """
            During caloric restriction without resistance training, 20–30% of weight lost is lean \
            muscle mass (fatally depresses metabolic rate). Resistance training preserves fat-free \
            mass (FFM) during a deficit and enables true recomposition: simultaneous fat loss + \
            muscle retention. Resistance training does not meaningfully accelerate total weight loss \
            vs. dieting alone, but radically shifts tissue composition. Mechanism: upregulates AMPK, \
            SIRT1 (mitochondrial biogenesis, fatty acid oxidation), PGC-1α, and ATGL; downregulates \
            Perilipin 1. Train all major muscle groups ≥2×/week with progressive resistance. Keep \
            RPE 7–9; avoid absolute failure every set in a calorie deficit. Moderate volume; avoid \
            junk volume.
            """,
            keywords: ["fat", "weight loss", "cut", "cutting", "calorie", "deficit",
                       "recomposition", "lose", "lean", "diet", "shred", "burn", "slim",
                       "fat loss", "body recomposition", "bulk"]
        ),

        ScienceSection(
            title: "Cardiovascular Training & Zone 2",
            content: """
            Polarised cardiovascular model for longevity: 80% Zone 2 + 20% Zone 5 (HIIT). \
            Avoid moderate-intensity continuous training (MICT) as the primary approach. \
            Zone 2: 60–70% max HR, conversational pace, lactate 1–2 mmol/L. Benefits: \
            mitochondrial biogenesis, capillary density, fat oxidation, insulin sensitivity. \
            Target 150–300+ minutes/week. Zone 5 (HIIT) gold-standard protocol: 4×4 (4 min \
            near-max, 4 min recovery, ×4 rounds), 1–2×/week maximum — raises VO2 Max, the \
            single strongest predictor of longevity. Exceeding 20% Zone 5 causes mitochondrial \
            dysfunction and glycaemic deterioration (40% drop after 4 weeks of excessive HIIT).
            """,
            keywords: ["cardio", "cardiovascular", "zone 2", "zone 5", "hiit", "aerobic",
                       "running", "endurance", "vo2", "heart rate", "stamina", "conditioning",
                       "longevity", "fitness", "treadmill", "cycling", "bike", "row"]
        ),

        ScienceSection(
            title: "Periodisation & Progressive Overload",
            content: """
            Progressive overload is non-negotiable for ongoing adaptation at any training age. \
            The specific periodisation model matters far less than ensuring overload is \
            systematically applied and weekly volume is sufficient. For hypertrophy: linear vs. \
            undulating periodisation produces equivalent muscle mass gains — choose based on \
            preference and recovery capacity. For maximal strength in advanced athletes: undulating \
            (non-linear) periodisation is superior — waving intensity/volume prevents accommodation, \
            improves motor unit synchronisation, and reduces injury risk. Include structured deload \
            phases every 4–8 weeks of hard training (reduce volume 40–50%) to resensitise tissues \
            and allow CNS recovery. Performing every set to absolute failure on every session \
            destroys long-term adherence; leaving 1–2 RIR on most sets is optimal.
            """,
            keywords: ["advanced", "progressive", "periodisation", "periodization", "deload",
                       "progress", "plateau", "experienced", "overload", "program",
                       "intermediate", "beginner", "linear", "cycle", "undulating"]
        )
    ]
}
