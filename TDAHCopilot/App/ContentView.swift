import SwiftUI

/// Contenedor raíz de TDAH Copilot que integra Módulo 1 (Rutina Visual) y Módulo 2 (Recordatorios Persistentes),
/// con barra flotante Liquid Glass y cobertura de alarma a pantalla completa sobre cualquier pestaña.
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @ObservedObject var routineViewModel: RoutineViewModel
    @ObservedObject var remindersViewModel: RemindersViewModel
    @Binding var selectedTab: CopilotTab
    @Binding var isShowingPanicSheet: Bool

    enum CopilotTab: String, CaseIterable, Identifiable {
        case routine = "Rutina"
        case reminders = "Recordatorios"

        var id: String { rawValue }

        var iconName: String {
            switch self {
            case .routine: return "clock.arrow.circlepath"
            case .reminders: return "bell.badge.fill"
            }
        }
    }

    private var pendingCount: Int {
        remindersViewModel.reminders.filter { !$0.isCompleted }.count
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .routine:
                    RoutineDashboardView(
                        viewModel: routineViewModel,
                        isShowingPanicSheet: $isShowingPanicSheet
                    )
                case .reminders:
                    RemindersView(viewModel: remindersViewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Barra de navegación flotante Liquid Glass
            floatingGlassTabBar
                .padding(.horizontal, 28)
                .padding(.bottom, 10)
        }
        .preferredColorScheme(.dark)
        .task {
            await NotificationService.shared.requestPermissionIfNeeded()
            remindersViewModel.checkDueReminders()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                remindersViewModel.checkDueReminders()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                remindersViewModel.checkDueReminders()
            }
        }
        // Alarma de Tarea (Full-Screen Takeover) disponible encima de cualquier pestaña
        .fullScreenCover(item: $remindersViewModel.activeTriggerReminder) { reminder in
            ActiveReminderSheet(reminder: reminder, viewModel: remindersViewModel)
        }
    }

    private var floatingGlassTabBar: some View {
        HStack(spacing: 8) {
            ForEach(CopilotTab.allCases) { tab in
                let isSelected = (selectedTab == tab)
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.iconName)
                            .font(.subheadline.weight(.bold))

                        Text(tab.rawValue)
                            .font(.subheadline.weight(.bold))

                        if tab == .reminders && pendingCount > 0 {
                            Text("\(pendingCount)")
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(CopilotTheme.actionRed, in: Capsule())
                        }
                    }
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.65))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        isSelected
                            ? LinearGradient(
                                colors: [CopilotTheme.electricBlue.opacity(0.45), CopilotTheme.mysticViolet.opacity(0.45)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(colors: [Color.clear, Color.clear], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 18, y: 8)
    }
}
