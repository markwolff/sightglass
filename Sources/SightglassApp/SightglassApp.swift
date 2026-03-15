import SwiftUI
import SightglassUI

@main
struct SightglassApp: App {
    @StateObject private var appState: AppState

    init() {
        _appState = StateObject(
            wrappedValue: AppState(launchArguments: ProcessInfo.processInfo.arguments)
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Folder...") {
                    appState.presentFolderPicker()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Open Spec File...") {
                    appState.presentFilePicker()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}
