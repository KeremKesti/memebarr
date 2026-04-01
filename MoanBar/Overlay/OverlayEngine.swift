import AppKit
import SwiftUI

// MARK: - Overlay engine

/// Manages the floating image overlay. Must be called from the main thread.
final class OverlayEngine {

    private var window: OverlayWindow?
    private var allImages: [URL] = []
    private var lastShownURL: URL?
    private var hideTask: DispatchWorkItem?

    // MARK: - Setup

    /// Scans `folder` for supported image files. Safe to call when folder is empty.
    func loadImages(from folder: URL) {
        let supported = Set(["png", "jpg", "jpeg", "gif", "webp", "heic"])
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.isRegularFileKey]
        ) else {
            debugLog("OverlayEngine: images folder not found at \(folder.path)", category: "overlay")
            return
        }
        allImages = entries.filter { supported.contains($0.pathExtension.lowercased()) }
        debugLog("OverlayEngine: loaded \(allImages.count) image(s)", category: "overlay")
    }

    // MARK: - Showing

    /// Displays a random image overlay for `duration` seconds with fade-in/out.
    /// Duration should match the audio clip length so the image disappears when
    /// the sound ends. Calling show() while an overlay is visible resets the timer.
    func show(for duration: TimeInterval = 2.0) {
        assert(Thread.isMainThread)
        guard !allImages.isEmpty else {
            debugLog("OverlayEngine: no images loaded — skipping overlay", category: "overlay")
            return
        }

        let chosen = pickImage()
        lastShownURL = chosen

        // Cancel any pending hide
        hideTask?.cancel()

        // Create (or reuse) the panel
        if window == nil {
            window = OverlayWindow()
        }
        guard let panel = window else { return }

        // Swap content view with fresh SwiftUI host so animation re-triggers
        let host = NSHostingView(rootView: OverlayImageView(imageURL: chosen, duration: duration))
        host.frame = panel.contentRect(forFrameRect: panel.frame)
        panel.contentView = host

        // Cover the entire main screen
        if let screen = NSScreen.main {
            panel.setFrame(screen.frame, display: false)
        }
        panel.orderFront(nil)

        debugLog("OverlayEngine: showing \(chosen.lastPathComponent) for \(String(format:"%.2f", duration))s", category: "overlay")

        // Schedule hide after the clip duration
        let task = DispatchWorkItem { [weak self] in
            self?.window?.orderOut(nil)
        }
        hideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: task)
    }

    var imageCount: Int { allImages.count }

    // MARK: - Private

    private func pickImage() -> URL {
        var candidates = allImages
        if let last = lastShownURL, candidates.count > 1 {
            candidates.removeAll { $0 == last }
        }
        return candidates.randomElement() ?? allImages[0]
    }
}

// MARK: - SwiftUI content

private struct OverlayImageView: View {
    let imageURL: URL
    let duration: TimeInterval
    @State private var opacity: Double = 0

    private let fadeIn:  TimeInterval = 0.25
    private let fadeOut: TimeInterval = 0.35

    var body: some View {
        ZStack {
            Color.clear
            if let nsImage = NSImage(contentsOf: imageURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 320, maxHeight: 320)
                    .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 4)
                    .opacity(opacity)
                    .onAppear { startAnimation() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    private func startAnimation() {
        withAnimation(.easeIn(duration: fadeIn)) {
            opacity = 1
        }
        // Start fade-out early enough so it finishes exactly when the clip ends
        let fadeOutStart = max(fadeIn, duration - fadeOut)
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutStart) {
            withAnimation(.easeOut(duration: fadeOut)) {
                opacity = 0
            }
        }
    }
}
