import AppKit

// MARK: - Non-activating transparent floating panel

/// A borderless, click-through NSPanel that floats above all app windows
/// without stealing focus or appearing in Mission Control / Exposé.
final class OverlayWindow: NSPanel {

    init() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let frame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating                           // above normal windows
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true                  // truly click-through
        collectionBehavior = [.canJoinAllSpaces,   // visible across Spaces
                              .fullScreenAuxiliary, // shown over full-screen apps
                              .ignoresCycle]        // hidden from Cmd-Tab
        isReleasedWhenClosed = false               // reuse the instance
        animationBehavior = .none
    }

    // Prevent the panel from becoming key or main under any circumstance.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
