import Foundation
import SwiftUI
import Combine
import ImagePlayground

/// Service that wraps Apple's Image Playground framework for generating
/// workout-themed images on-device. Images are cached to disk so each
/// unique exercise or day title is only generated once.
final class ImagePlaygroundService: ObservableObject {

    /// Whether Image Playground is available on this device.
    @Published private(set) var isAvailable = false

    /// Tracks which keys are currently being generated.
    @Published var generatingKeys: Set<String> = []

    private let cacheDirectory: URL
    private var imageCreator: ImageCreator?

    nonisolated init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("ImagePlayground", isDirectory: true)
        cacheDirectory = dir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    /// Call once at startup to probe device capabilities and create the ImageCreator.
    func configure() async {
        do {
            let creator = try await ImageCreator()
            imageCreator = creator
            isAvailable = true
        } catch {
            print("[ImagePlaygroundService] ImageCreator not available: \(error)")
            isAvailable = false
        }
    }

    // MARK: - Public API

    /// Generate an illustration for an exercise.
    /// Returns a local file URL on success, or `nil` if unavailable/failed.
    func generateExerciseImage(name: String, description: String) async -> URL? {
        let cacheKey = "exercise_\(sanitize(name))"
        if let cached = cachedImageURL(for: cacheKey) { return cached }

        let prompt = "A person performing \(name) exercise in a modern gym, fitness illustration, dynamic pose, vibrant lighting"
        return await generateAndCache(prompt: prompt, key: cacheKey)
    }

    /// Generate a hero image for a workout day card.
    /// Returns a local file URL on success, or `nil` if unavailable/failed.
    func generateDayHeroImage(dayTitle: String) async -> URL? {
        let cacheKey = "day_\(sanitize(dayTitle))"
        if let cached = cachedImageURL(for: cacheKey) { return cached }

        let prompt = "\(dayTitle) workout training session, athletic gym environment, energetic fitness illustration"
        return await generateAndCache(prompt: prompt, key: cacheKey)
    }

    /// Force-regenerate an exercise image (ignoring cache).
    func regenerateExerciseImage(name: String, description: String) async -> URL? {
        let cacheKey = "exercise_\(sanitize(name))"
        // Delete existing cached file
        let fileURL = cacheDirectory.appendingPathComponent("\(cacheKey).png")
        try? FileManager.default.removeItem(at: fileURL)

        let prompt = "A person performing \(name) exercise in a modern gym, fitness illustration, dynamic pose, vibrant lighting"
        return await generateAndCache(prompt: prompt, key: cacheKey)
    }

    /// Save an image from an Image Playground sheet URL to our cache.
    func saveSheetImage(url: URL, exerciseName: String) -> URL? {
        let cacheKey = "exercise_\(sanitize(exerciseName))"
        let destURL = cacheDirectory.appendingPathComponent("\(cacheKey).png")
        do {
            let data = try Data(contentsOf: url)
            try data.write(to: destURL, options: [.atomic])
            return destURL
        } catch {
            print("[ImagePlaygroundService] Failed to save sheet image: \(error)")
            return nil
        }
    }

    /// Save an image from an Image Playground sheet URL for a day hero.
    func saveSheetDayImage(url: URL, dayTitle: String) -> URL? {
        let cacheKey = "day_\(sanitize(dayTitle))"
        let destURL = cacheDirectory.appendingPathComponent("\(cacheKey).png")
        do {
            let data = try Data(contentsOf: url)
            try data.write(to: destURL, options: [.atomic])
            return destURL
        } catch {
            print("[ImagePlaygroundService] Failed to save sheet day image: \(error)")
            return nil
        }
    }

    /// Check if a cached image already exists for an exercise.
    func cachedExerciseImageURL(name: String) -> URL? {
        cachedImageURL(for: "exercise_\(sanitize(name))")
    }

    /// Check if a cached image already exists for a day.
    func cachedDayImageURL(dayTitle: String) -> URL? {
        cachedImageURL(for: "day_\(sanitize(dayTitle))")
    }

    // MARK: - Private Helpers

    private func generateAndCache(prompt: String, key: String) async -> URL? {
        guard let creator = imageCreator else { return nil }

        generatingKeys.insert(key)
        defer { generatingKeys.remove(key) }

        do {
            let concepts: [ImagePlaygroundConcept] = [.text(prompt)]
            let images = creator.images(for: concepts, style: .animation, limit: 1)

            for try await createdImage in images {
                let uiImage = UIImage(cgImage: createdImage.cgImage)
                guard let data = uiImage.pngData() else { continue }

                let fileURL = cacheDirectory.appendingPathComponent("\(key).png")
                try data.write(to: fileURL, options: [.atomic])
                return fileURL
            }
        } catch {
            print("[ImagePlaygroundService] Generation failed for '\(key)': \(error)")
        }

        return nil
    }

    private func cachedImageURL(for key: String) -> URL? {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).png")
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    private func sanitize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}
