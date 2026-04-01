import Foundation
import AVFoundation

// MARK: - Audio engine

/// Manages a pool of preloaded AVAudioPlayers. Provides no-repeat-last-clip
/// selection and maps hit intensity to a bounded volume range.
final class AudioEngine {

    // MARK: - Config (updated from Settings)

    var minVolume: Float = 0.10
    var maxVolume: Float = 0.90

    // MARK: - Internal state

    private var players: [URL: AVAudioPlayer] = [:]
    private var allClips: [URL] = []
    private var recentlyPlayed: [URL] = []
    private let recentWindow = 3

    // MARK: - Setup

    /// Scans `folder` for mp3/wav/m4a files and preloads each one.
    /// Safe to call when no files exist; the engine simply stays silent.
    func loadClips(from folder: URL) {
        let supportedExtensions = Set(["mp3", "wav", "m4a", "aiff", "caf"])
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.isRegularFileKey]
        ) else {
            debugLog("AudioEngine: sounds folder not found at \(folder.path)", category: "audio")
            return
        }

        let clips = entries.filter { supportedExtensions.contains($0.pathExtension.lowercased()) }

        for url in clips {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                players[url] = player
            } catch {
                debugLog("AudioEngine: failed to load \(url.lastPathComponent) — \(error)", category: "audio")
            }
        }

        allClips = Array(players.keys)
        debugLog("AudioEngine: preloaded \(allClips.count) clip(s)", category: "audio")
    }

    // MARK: - Playback

    /// Selects a random clip (avoiding the last played), maps `intensity` to
    /// volume, and plays immediately. Returns the clip's duration in seconds
    /// so callers can synchronise the overlay lifetime to the audio.
    @discardableResult
    func play(intensity: Double) -> TimeInterval {
        guard !allClips.isEmpty else {
            debugLog("AudioEngine: no clips loaded — skipping playback", category: "audio")
            return 2.0
        }

        let chosen = pickClip()
        guard let player = players[chosen] else { return 2.0 }

        player.volume = volumeFor(intensity: intensity)
        player.currentTime = 0
        player.play()
        recentlyPlayed.append(chosen)
        if recentlyPlayed.count > recentWindow { recentlyPlayed.removeFirst() }

        debugLog(
            "AudioEngine: playing \(chosen.lastPathComponent) vol=\(String(format:"%.2f", player.volume)) dur=\(String(format:"%.2f", player.duration))s",
            category: "audio"
        )
        return player.duration
    }

    var clipCount: Int { allClips.count }

    // MARK: - Private helpers

    private func pickClip() -> URL {
        // Exclude the last `recentWindow` clips so the same sound doesn't
        // repeat within a 3-slap window. Falls back gracefully when the pool
        // is smaller than the window.
        var candidates = allClips
        if candidates.count > recentWindow {
            candidates.removeAll { recentlyPlayed.contains($0) }
        }
        return candidates.randomElement() ?? allClips[0]
    }

    private func volumeFor(intensity: Double) -> Float {
        let clamped = Float(max(0.0, min(1.0, intensity)))
        // Linear ramp between minVolume and maxVolume.
        // A soft-knee curve can be substituted here later without API changes.
        return minVolume + clamped * (maxVolume - minVolume)
    }
}
