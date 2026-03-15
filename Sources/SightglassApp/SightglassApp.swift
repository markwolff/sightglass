import SwiftUI

@main
struct SightglassApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Spec File...") {
                    appState.showFilePicker = true
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}
