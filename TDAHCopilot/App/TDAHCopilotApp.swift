import SwiftUI

/// Punto de entrada de "TDAH Copilot" compatible con iOS 17+ y automatización mediante Atajos (`tdahcopilot://`).
@main
struct TDAHCopilotApp: App {
    @StateObject private var routineViewModel = RoutineViewModel()
    @StateObject private var remindersViewModel = RemindersViewModel()

    @State private var selectedTab: ContentView.CopilotTab = .routine
    @State private var isShowingPanicSheet: Bool = false

    var body: some Scene {
        WindowGroup {
            ContentView(
                routineViewModel: routineViewModel,
                remindersViewModel: remindersViewModel,
                selectedTab: $selectedTab,
                isShowingPanicSheet: $isShowingPanicSheet
            )
            .onOpenURL { url in
                handleIncomingShortcutURL(url)
            }
        }
    }

    /// Permite abrir el modo "Niñero Digital" automáticamente desde la app Atajos de iOS (ej. al abrir TikTok).
    private func handleIncomingShortcutURL(_ url: URL) {
        guard url.scheme?.lowercased() == "tdahcopilot" else { return }
        let target = (url.host ?? url.path).lowercased()

        if target.contains("distracted") || target.contains("panic") || target.contains("nanny") {
            selectedTab = .routine
            isShowingPanicSheet = true
        } else if target.contains("reminder") {
            selectedTab = .reminders
        }
    }
}
