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
    /// Per-clip gain multiplier so all clips play at roughly the same loudness.
    private var normGain: [URL: Float] = [:]

    // MARK: - Setup

    /// Scans `folder` for mp3/wav/m4a files and preloads each one.
    /// Clears any previously loaded clips first.
    /// Safe to call when no files exist; the engine simply stays silent.
    func loadClips(from folder: URL) {
        players.removeAll()
        allClips.removeAll()
        recentlyPlayed.removeAll()
        normGain.removeAll()
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
        computeNormGains()
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

        let gain = normGain[chosen] ?? 1.0
        player.volume = min(volumeFor(intensity: intensity) * gain, 1.0)
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
        return minVolume + clamped * (maxVolume - minVolume)
    }

    // MARK: - Loudness normalisation

    /// Measures the RMS amplitude of every loaded clip, finds the median RMS,
    /// then stores a per-clip gain so all clips land near that median level.
    /// Gain is capped at 4× to avoid over-amplifying very quiet clips.
    private func computeNormGains() {
        var rmsMap: [URL: Float] = [:]
        for url in allClips {
            if let rms = measureRMS(url: url), rms > 0 {
                rmsMap[url] = rms
            }
        }
        guard !rmsMap.isEmpty else { return }

        let sorted = rmsMap.values.sorted()
        let medianRMS = sorted[sorted.count / 2]

        for (url, rms) in rmsMap {
            let gain = (medianRMS / rms).clamped(to: 0.25...4.0)
            normGain[url] = gain
            debugLog(
                "AudioEngine: \(url.lastPathComponent) rms=\(String(format:"%.4f", rms)) gain=\(String(format:"%.2f", gain))×",
                category: "audio"
            )
        }
    }

    /// Reads the PCM samples of `url` via AVAudioFile and returns the RMS level.
    private func measureRMS(url: URL) -> Float? {
        guard let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
              ),
              (try? file.read(into: buffer)) != nil,
              let channelData = buffer.floatChannelData
        else { return nil }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(file.processingFormat.channelCount)
        guard frameCount > 0, channelCount > 0 else { return nil }

        var sumOfSquares: Float = 0
        for ch in 0..<channelCount {
            let data = channelData[ch]
            for i in 0..<frameCount {
                sumOfSquares += data[i] * data[i]
            }
        }
        return sqrt(sumOfSquares / Float(frameCount * channelCount))
    }
}

// MARK: - Comparable clamping helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
