import SwiftUI
import SightglassUI

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
                    appState.presentFilePicker()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}
