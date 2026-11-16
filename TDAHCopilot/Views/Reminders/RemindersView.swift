import SwiftUI

/// Vista del Módulo 2: Bandeja de entrada de Recordatorios Persistentes ("Alarmas de Vida").
/// Permite capturar rápidamente tareas para hoy, 1 semana o 1 mes con nivel de Fricción (Baja, Media, Alta)
/// y lanzar inmediatamente la Alarma de Pantalla Completa (`ActiveReminderSheet`).
struct RemindersView: View {
    @ObservedObject var viewModel: RemindersViewModel

    @State private var quickTitle: String = ""
    @State private var quickHorizon: ReminderHorizon = .inThirtyMinutes
    @State private var quickFriction: FrictionLevel = .high
    @State private var isShowingAddSheet: Bool = false
    @State private var selectedFilter: ReminderInboxFilter = .pending

    @FocusState private var isQuickFieldFocused: Bool

    private enum ReminderInboxFilter: String, CaseIterable, Identifiable {
        case pending = "Pendientes"
        case completed = "Completados"
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            NocturnalGlassBackground(
                topOrbColor: CopilotTheme.royalIndigo,
                bottomOrbColor: CopilotTheme.actionRed.opacity(0.65)
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    // 1. Cabecera del Módulo 2
                    headerSection

                    // 2. Captura rápida inline (Hoy / 1 Semana / 1 Mes + Fricción)
                    quickInboxCaptureCard

                    // 3. Selector Pendientes / Completados
                    filterSegmentedBar

                    // 4. Listado agrupado
                    if selectedFilter == .pending {
                        pendingSectionsView
                    } else {
                        completedSectionView
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 110)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .sheet(isPresented: $isShowingAddSheet) {
            AddReminderSheet { title, notes, dueDate, friction in
                viewModel.addReminder(title: title, notes: notes, dueDate: dueDate, friction: friction)
            }
        }
    }

    // MARK: - 1. Cabecera

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Recordatorios")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Alarmas de vida imposibles de ignorar")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            Button {
                isQuickFieldFocused = false
                isShowingAddSheet = true
            } label: {
                Label("Detallado", systemImage: "plus")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(CopilotTheme.electricBlue.opacity(0.32))
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(CopilotTheme.electricBlue.opacity(0.65), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    // MARK: - 2. Bandeja de Entrada Rápida

    private var quickInboxCaptureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.badge.clock.fill")
                    .foregroundStyle(quickFriction.badgeColor)

                TextField("Anota algo que no puedes olvidar...", text: $quickTitle)
                    .focused($isQuickFieldFocused)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .submitLabel(.done)
                    .onSubmit(submitQuickReminder)

                if !quickTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: submitQuickReminder) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(CopilotTheme.actionGreen)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))

            // Horizonte temporal rápido: Hoy, 1 Semana, 1 Mes
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([ReminderHorizon.inThirtyMinutes, .tonight, .nextWeek, .nextMonth]) { horizon in
                        Button {
                            quickHorizon = horizon
                        } label: {
                            Text(horizon.rawValue)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(
                                    quickHorizon == horizon
                                        ? CopilotTheme.electricBlue.opacity(0.38)
                                        : Color.white.opacity(0.07),
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            quickHorizon == horizon ? CopilotTheme.electricBlue : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Selector rápido de Nivel de Fricción
            HStack(spacing: 8) {
                Text("Fricción:")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))

                ForEach(FrictionLevel.allCases) { level in
                    Button {
                        quickFriction = level
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(level.badgeColor)
                                .frame(width: 7, height: 7)
                            Text(level.rawValue)
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            quickFriction == level
                                ? level.badgeColor.opacity(0.28)
                                : Color.white.opacity(0.06),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    quickFriction == level ? level.badgeColor : Color.clear,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .liquidGlassCard(cornerRadius: 24, glowColor: quickFriction.badgeColor, isHighlighted: false)
    }

    // MARK: - 3. Filtro Pendientes / Completados

    private var filterSegmentedBar: some View {
        HStack(spacing: 8) {
            ForEach(ReminderInboxFilter.allCases) { filter in
                let isSelected = (selectedFilter == filter)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = filter
                    }
                } label: {
                    Text(filter.rawValue)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.65))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            isSelected ? CopilotTheme.royalIndigo.opacity(0.38) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }

    // MARK: - 4. Listados Agrupados

    @ViewBuilder
    private var pendingSectionsView: some View {
        let today = viewModel.pendingToday
        let week = viewModel.pendingThisWeek
        let later = viewModel.pendingLater

        if today.isEmpty && week.isEmpty && later.isEmpty {
            emptyStateCard(
                icon: "checkmark.seal.fill",
                title: "Bandeja despejada",
                subtitle: "No tienes alarmas pendientes. Anota exámenes, tareas o recados arriba cuando aparezcan."
            )
        } else {
            if !today.isEmpty {
                reminderSection(title: "Para Hoy", items: today)
            }
            if !week.isEmpty {
                reminderSection(title: "Esta Semana", items: week)
            }
            if !later.isEmpty {
                reminderSection(title: "Este Mes / Próximos", items: later)
            }
        }
    }

    @ViewBuilder
    private var completedSectionView: some View {
        let completed = viewModel.completedReminders
        if completed.isEmpty {
            emptyStateCard(
                icon: "tray",
                title: "Aún sin completados",
                subtitle: "Cada tarea que completes te dará un impulso real. ¡Empieza con una hoy!"
            )
        } else {
            reminderSection(title: "Completados", items: completed)
        }
    }

    private func reminderSection(title: String, items: [PersistentReminder]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white.opacity(0.82))
                .padding(.horizontal, 4)

            ForEach(items) { item in
                reminderCard(item)
            }
        }
    }

    private func reminderCard(_ reminder: PersistentReminder) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    if reminder.isCompleted {
                        viewModel.reopenReminder(id: reminder.id)
                    } else {
                        viewModel.completeReminder(id: reminder.id)
                    }
                } label: {
                    Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(reminder.isCompleted ? CopilotTheme.actionGreen : reminder.friction.badgeColor)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Label("Fricción \(reminder.friction.rawValue)", systemImage: reminder.friction.iconName)
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(reminder.friction.badgeColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(reminder.friction.badgeColor.opacity(0.16), in: Capsule())

                        if reminder.snoozedUntil != nil && !reminder.isCompleted {
                            Text("Pospuesto 10m")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(CopilotTheme.warningAmber)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(CopilotTheme.warningAmber.opacity(0.16), in: Capsule())
                        }
                    }

                    Text(reminder.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .strikethrough(reminder.isCompleted, color: .white.opacity(0.45))

                    if !reminder.notes.isEmpty {
                        Text(reminder.notes)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 4)

                if !reminder.isCompleted {
                    Button {
                        isQuickFieldFocused = false
                        viewModel.triggerAlertImmediately(for: reminder)
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "bell.and.waves.left.and.right.fill")
                                .font(.body.weight(.bold))
                            Text("Alarma")
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(reminder.friction.badgeColor.opacity(0.28), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(reminder.friction.badgeColor.opacity(0.65), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Probar alarma de \(reminder.title)")
                }
            }

            // Pie de tarjeta con fecha relativa y progreso de micro-pasos si existe
            HStack {
                Label(
                    TimeFormatters.relativeDueDescription(for: reminder.effectiveTriggerDate),
                    systemImage: "calendar.badge.clock"
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.68))

                Text("· \(formattedShortDate(reminder.effectiveTriggerDate))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))

                Spacer()

                if !reminder.microSteps.isEmpty {
                    Label(
                        "\(reminder.completedMicroStepsCount)/\(reminder.microSteps.count) pasos",
                        systemImage: "checklist"
                    )
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(CopilotTheme.actionBlue)
                }
            }
        }
        .padding(16)
        .liquidGlassCard(
            cornerRadius: 24,
            glowColor: reminder.friction.badgeColor,
            isHighlighted: !reminder.isCompleted && reminder.friction == .high,
            dimOpacity: reminder.isCompleted ? 0.55 : 1.0
        )
        .contextMenu {
            if !reminder.isCompleted {
                Button {
                    viewModel.triggerAlertImmediately(for: reminder)
                } label: {
                    Label("Activar Alarma de Pantalla Completa", systemImage: "bell.badge.fill")
                }
            }

            Button(role: .destructive) {
                viewModel.deleteReminder(id: reminder.id)
            } label: {
                Label("Eliminar recordatorio", systemImage: "trash")
            }
        }
    }

    private func emptyStateCard(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(CopilotTheme.neonCyan)
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
        }
        .padding(26)
        .frame(maxWidth: .infinity)
        .liquidGlassCard(cornerRadius: 24)
    }

    private func submitQuickReminder() {
        let clean = quickTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        viewModel.addReminder(
            title: clean,
            dueDate: quickHorizon.targetDate(),
            friction: quickFriction
        )
        quickTitle = ""
        isQuickFieldFocused = false
    }

    private func formattedShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d MMM, h:mm a"
        return formatter.string(from: date)
    }
}
