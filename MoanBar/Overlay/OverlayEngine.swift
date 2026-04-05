import AppKit
import WebKit

// MARK: - Live2D overlay engine

/// Manages a floating WKWebView panel that renders the Live2D character.
/// Expressions are triggered on every slap event.
/// Must be called from the main thread.
final class Live2DEngine: NSObject, WKScriptMessageHandler {

    private var window: OverlayWindow?
    private var webView: WKWebView?
    private var isModelReady = false
    private var pendingExpression: String?
    private var hideTask: DispatchWorkItem?

    private let expressions = ["Amazed", "Angry", "Cry", "Love", "Nervous", "Sleepy"]
    private var recentExpressions: [String] = []
    private let recentWindow = 2

    // MARK: - Panel size / position

    private let panelWidth:  CGFloat = 400
    private let panelHeight: CGFloat = 700
    private let screenMargin: CGFloat = 20

    // MARK: - Setup

    /// Creates the WKWebView and starts loading the Live2D model.
    /// Call once at app startup so the model is pre-loaded before the first slap.
    func setup() {
        guard let modelDir = Bundle.main.resourceURL?.appendingPathComponent("Live2D"),
              let htmlURL  = modelDir.appendingPathComponent("live2d_overlay.html") as URL?
        else {
            debugLog("Live2DEngine: Live2D resource folder not found", category: "overlay")
            return
        }

        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "live2d")

        let wv = WKWebView(
            frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            configuration: config
        )
        wv.isOpaque = false
        wv.underPageBackgroundColor = .clear
        wv.allowsMagnification = false
        webView = wv

        wv.loadFileURL(htmlURL, allowingReadAccessTo: modelDir)
        debugLog("Live2DEngine: loading model from \(modelDir.path)", category: "overlay")
    }

    // MARK: - Showing

    /// Shows the Live2D panel and plays a random expression for `duration` seconds.
    func show(for duration: TimeInterval = 3.0) {
        assert(Thread.isMainThread)

        let expression = pickExpression()
        createPanelIfNeeded()

        guard let panel = window, let screen = NSScreen.main else { return }

        let x = screen.frame.maxX - panelWidth  - screenMargin
        let y = screen.frame.minY + screenMargin
        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: false)

        // Fade in
        panel.alphaValue = 0
        panel.orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.20
            panel.animator().alphaValue = 1.0
        }

        triggerExpression(expression)
        debugLog("Live2DEngine: showing expression '\(expression)' for \(String(format:"%.2f",duration))s", category: "overlay")

        // Schedule hide
        hideTask?.cancel()
        let task = DispatchWorkItem { [weak self] in self?.hide() }
        hideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: task)
    }

    var expressionCount: Int { expressions.count }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "live2d", (message.body as? String) == "ready" else { return }
        isModelReady = true
        debugLog("Live2DEngine: model ready", category: "overlay")
        if let expr = pendingExpression {
            pendingExpression = nil
            webView?.evaluateJavaScript("playExpression('\(expr)')") { _, _ in }
        }
    }

    // MARK: - Private

    private func createPanelIfNeeded() {
        guard window == nil else { return }
        let panel = OverlayWindow()
        if let wv = webView {
            wv.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
            panel.contentView = wv
        }
        window = panel
    }

    private func hide() {
        guard let panel = window else { return }
        webView?.evaluateJavaScript("resetExpression()") { _, _ in }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.30
            panel.animator().alphaValue = 0.0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    private func triggerExpression(_ name: String) {
        if isModelReady {
            webView?.evaluateJavaScript("playExpression('\(name)')") { _, _ in }
        } else {
            pendingExpression = name
        }
    }

    private func pickExpression() -> String {
        var candidates = expressions
        if candidates.count > recentWindow {
            candidates.removeAll { recentExpressions.contains($0) }
        }
        let chosen = candidates.randomElement() ?? expressions[0]
        recentExpressions.append(chosen)
        if recentExpressions.count > recentWindow { recentExpressions.removeFirst() }
        return chosen
    }
}
