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

    /// Displays a random image overlay for ~2 s with fade-in/out.
    /// Calling show() while an overlay is visible resets the timer.
    func show() {
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
        let host = NSHostingView(rootView: OverlayImageView(imageURL: chosen))
        host.frame = panel.contentRect(forFrameRect: panel.frame)
        panel.contentView = host

        // Cover the entire main screen
        if let screen = NSScreen.main {
            panel.setFrame(screen.frame, display: false)
        }
        panel.orderFront(nil)

        debugLog("OverlayEngine: showing \(chosen.lastPathComponent)", category: "overlay")

        // Schedule hide after 2 s
        let task = DispatchWorkItem { [weak self] in
            self?.window?.orderOut(nil)
        }
        hideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: task)
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
    @State private var opacity: Double = 0

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
        withAnimation(.easeIn(duration: 0.25)) {
            opacity = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.35)) {
                opacity = 0
            }
        }
    }
}
