import SwiftUI
import GazeUI

@main
struct GazeLabPreviewerApp: App {
    var body: some Scene {
        WindowGroup {
            GazeDashboard()
        }
        #if os(macOS)
        .windowStyle(.automatic)
        #endif
    }
}
