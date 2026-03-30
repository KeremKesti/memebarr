import Foundation
import os.log

private let subsystem = "io.moanbar.MoanBar"

let logger = Logger(subsystem: subsystem, category: "app")

/// Debug-only logging. Compiles to nothing in release builds.
@inline(__always)
func debugLog(_ message: String, category: String = "app") {
    #if DEBUG
    print("[MoanBar:\(category)] \(message)")
    #endif
}
