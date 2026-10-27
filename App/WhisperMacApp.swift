import SwiftUI
import WidgetKit

@main
struct WhisperMacApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup("Whisper Money") {
            RootView()
                .environment(model)
                .frame(minWidth: 820, minHeight: 520)
                .onOpenURL { model.open($0) }
        }
        .onChange(of: scenePhase) { _, phase in
            // Al volver a la app, el widget también pide datos nuevos a Whisper Money.
            if phase == .active { WidgetCenter.shared.reloadAllTimelines() }
        }
        .commands {
            CommandGroup(after: .sidebar) {
                ForEach(AppSection.allCases) { section in
                    Button(section.title) { model.section = section }
                        .keyboardShortcut(section.shortcut, modifiers: .command)
                }
            }
        }

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}
