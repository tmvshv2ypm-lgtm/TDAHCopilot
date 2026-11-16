import SwiftUI
import UIKit

/// Tarjeta de Alerta a Pantalla Completa ("Alarma de Tarea" / Full-Screen Takeover).
/// Bloquea el cierre por deslizamiento (`.interactiveDismissDisabled()`), reproduce alarma persistente con `AVFoundation`
/// y exige una de 3 decisiones estrictas: Hacerlo ahora (Verde), Desglosar (Azul) o Posponer 10 min (Rojo).
struct ActiveReminderSheet: View {
    let reminder: PersistentReminder
    @ObservedObject var viewModel: RemindersViewModel

    private enum TakeoverMode {
        case ringing
        case pomodoro
        case breakdown
        case snoozedConfirmation
    }

    @State private var mode: TakeoverMode = .ringing
    @State private var pulseActive: Bool = false

    // Estado del Temporizador Visual Pomodoro (Botón Verde)
    @State private var pomodoroTotalSeconds: Int = 25 * 60
    @State private var pomodoroRemainingSeconds: Int = 25 * 60
    @State private var isPomodoroRunning: Bool = false
    @State private var pomodoroRunToken: UUID = UUID()

    // Estado de Micro-Pasos (Botón Azul)
    @State private var microSteps: [MicroStep] = []

    // Mensaje estricto al posponer 10 min (Botón Rojo)
    @State private var snoozedReturnDate: Date = Date().addingTimeInterval(10 * 60)
    @State private var snoozeWarningMessage: String = "Ok, 10 minutos, pero no abras TikTok."

    private var liveReminder: PersistentReminder {
        viewModel.reminders.first(where: { $0.id == reminder.id }) ?? reminder
    }

    private var frictionColor: Color {
        liveReminder.friction.badgeColor
    }

    var body: some View {
        ZStack {
            NocturnalGlassBackground(
                topOrbColor: mode == .pomodoro ? CopilotTheme.actionGreen : frictionColor,
                bottomOrbColor: mode == .breakdown ? CopilotTheme.actionBlue : CopilotTheme.mysticViolet
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    switch mode {
                    case .ringing:
                        ringingAlertSection
                    case .pomodoro:
                        pomodoroFocusSection
                    case .breakdown:
                        microStepsBreakdownSection
                    case .snoozedConfirmation:
                        strictSnoozeConfirmationSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 26)
                .padding(.bottom, 36)
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(true)
        .onAppear {
            microSteps = liveReminder.microSteps
            pulseActive = true
            AlarmAudioService.shared.startAlarm(friction: liveReminder.friction)
        }
        .onDisappear {
            AlarmAudioService.shared.stopAlarm()
            stopPomodoroTimer()
        }
        .task(id: pomodoroRunToken) {
            guard mode == .pomodoro, isPomodoroRunning else { return }
            while isPomodoroRunning && pomodoroRemainingSeconds > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, mode == .pomodoro, isPomodoroRunning else { return }
                if pomodoroRemainingSeconds > 1 {
                    pomodoroRemainingSeconds -= 1
                } else {
                    pomodoroRemainingSeconds = 0
                    isPomodoroRunning = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        }
    }

    // MARK: - 1. Modo Alarma Activa (3 Opciones Estrictas)

    private var ringingAlertSection: some View {
        VStack(spacing: 22) {
            // Indicador pulsante de fricción
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(frictionColor.opacity(0.28))
                        .frame(width: 118, height: 118)
                        .scaleEffect(pulseActive ? 1.24 : 0.9)
                        .opacity(pulseActive ? 0.45 : 0.9)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulseActive)

                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 84, height: 84)
                        .overlay(
                            Circle()
                                .strokeBorder(frictionColor, lineWidth: 2)
                        )

                    Image(systemName: liveReminder.friction.iconName)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(frictionColor)
                }

                Text("ALARMA DE TAREA · FRICCIÓN \(liveReminder.friction.rawValue.uppercased())")
                    .font(.caption.weight(.heavy))
                    .tracking(1.0)
                    .foregroundStyle(frictionColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(frictionColor.opacity(0.16), in: Capsule())
            }

            // Tarjeta Liquid Glass con la tarea pendiente
            VStack(spacing: 12) {
                Text("Es momento de actuar, José")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))

                Text(liveReminder.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if !liveReminder.notes.isEmpty {
                    Text(liveReminder.notes)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }

                Label("Audio persistente activo hasta que elijas una acción", systemImage: "speaker.wave.3.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(frictionColor)
                    .padding(.top, 4)
            }
            .padding(22)
            .frame(maxWidth: .infinity)
            .liquidGlassCard(cornerRadius: 24, glowColor: frictionColor, isHighlighted: true)

            // 3 Opciones Estrictas de Acción
            VStack(spacing: 14) {
                // BOTÓN VERDE: Hacerlo ahora (Inicia Pomodoro Visual)
                Button {
                    triggerActionDoNow(minutes: 25)
                } label: {
                    strictActionLabel(
                        icon: "play.circle.fill",
                        title: "Hacerlo ahora",
                        subtitle: "Silencia la alarma e inicia Pomodoro visual de 25 min",
                        gradientColors: [CopilotTheme.actionGreen, Color(hex: "#059669")]
                    )
                }
                .buttonStyle(.plain)

                // BOTÓN AZUL: Desglosar en 3 micro-pasos
                Button {
                    triggerActionBreakdown()
                } label: {
                    strictActionLabel(
                        icon: "list.bullet.indent",
                        title: "Desglosar",
                        subtitle: "¿Te paraliza? Dividir en 3 micro-pasos fáciles",
                        gradientColors: [CopilotTheme.actionBlue, Color(hex: "#2563EB")]
                    )
                }
                .buttonStyle(.plain)

                // BOTÓN ROJO: Posponer estrictamente 10 min
                Button {
                    triggerActionStrictSnooze()
                } label: {
                    strictActionLabel(
                        icon: "clock.badge.exclamationmark.fill",
                        title: "Posponer 10 min",
                        subtitle: "Último margen corto y estricto · Sin distracciones",
                        gradientColors: [CopilotTheme.actionRed, Color(hex: "#BE123C")]
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func strictActionLabel(
        icon: String,
        title: String,
        subtitle: String,
        gradientColors: [Color]
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.20), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing)
        )
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: (gradientColors.first ?? .white).opacity(0.35), radius: 14, y: 6)
    }

    // MARK: - 2. Temporizador Visual Pomodoro (Botón Verde)

    private var pomodoroFocusSection: some View {
        let progress = 1.0 - (Double(pomodoroRemainingSeconds) / Double(max(1, pomodoroTotalSeconds)))

        return VStack(spacing: 22) {
            Label("MODO ENFOQUE · POMODORO VISUAL", systemImage: "flame.fill")
                .font(.caption.weight(.heavy))
                .tracking(1.0)
                .foregroundStyle(CopilotTheme.actionGreen)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(CopilotTheme.actionGreen.opacity(0.18), in: Capsule())

            Text(liveReminder.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            // Anillo gigante visual de Pomodoro
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 14)
                    .frame(width: 230, height: 230)

                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(1, progress))))
                    .stroke(
                        LinearGradient(
                            colors: [CopilotTheme.actionGreen, CopilotTheme.neonCyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .frame(width: 230, height: 230)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.4), value: pomodoroRemainingSeconds)

                VStack(spacing: 6) {
                    Text(TimeFormatters.countdownString(seconds: TimeInterval(pomodoroRemainingSeconds)))
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    Text(
                        pomodoroRemainingSeconds == 0
                            ? "¡Bloque completado!"
                            : (isPomodoroRunning ? "Solo enfócate en empezar" : "Temporizador en pausa")
                    )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CopilotTheme.actionGreen)
                }
            }
            .padding(.vertical, 6)

            // Selector rápido de duración para vencer la parálisis
            HStack(spacing: 10) {
                ForEach([5, 15, 25], id: \.self) { mins in
                    Button {
                        startPomodoro(minutes: mins)
                    } label: {
                        Text("\(mins) min")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                pomodoroTotalSeconds == mins * 60
                                    ? CopilotTheme.actionGreen.opacity(0.4)
                                    : Color.white.opacity(0.1),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Controles de Pomodoro
            VStack(spacing: 12) {
                Button {
                    stopPomodoroTimer()
                    viewModel.completeReminder(id: liveReminder.id)
                } label: {
                    Label("¡Listo! Terminé esta tarea", systemImage: "checkmark.circle.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(CopilotTheme.actionGreen, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: CopilotTheme.actionGreen.opacity(0.4), radius: 14, y: 5)
                }
                .buttonStyle(.plain)

                HStack(spacing: 12) {
                    Button {
                        if isPomodoroRunning {
                            pausePomodoro()
                        } else {
                            resumePomodoro()
                        }
                    } label: {
                        Label(isPomodoroRunning ? "Pausar" : "Reanudar", systemImage: isPomodoroRunning ? "pause.fill" : "play.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)

                    Button {
                        stopPomodoroTimer()
                        triggerActionBreakdown()
                    } label: {
                        Label("Desglosar", systemImage: "list.bullet.indent")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(CopilotTheme.actionBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }

                Button("Posponer 10 min mejor") {
                    stopPomodoroTimer()
                    triggerActionStrictSnooze()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(CopilotTheme.actionRed.opacity(0.9))
                .padding(.top, 4)
            }
        }
        .padding(20)
        .liquidGlassCard(cornerRadius: 24, glowColor: CopilotTheme.actionGreen, isHighlighted: true)
    }

    // MARK: - 3. Desglose Automático en 3 Micro-Pasos (Botón Azul)

    private var microStepsBreakdownSection: some View {
        let currentSteps = liveReminder.microSteps.isEmpty ? microSteps : liveReminder.microSteps
        let doneCount = currentSteps.filter(\.isDone).count

        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("DESGLOSE ANTI-PARÁLISIS", systemImage: "sparkles")
                    .font(.caption.weight(.heavy))
                    .tracking(0.8)
                    .foregroundStyle(CopilotTheme.actionBlue)

                Spacer()

                Text("\(doneCount)/\(currentSteps.count) pasos")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(CopilotTheme.actionBlue.opacity(0.25), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(liveReminder.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                Text("No pienses en toda la tarea. Solo toca el Paso 1 y gana dopamina al tacharlo:")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.76))
            }

            VStack(spacing: 12) {
                ForEach(Array(currentSteps.enumerated()), id: \.element.id) { index, step in
                    Button {
                        viewModel.toggleMicroStep(reminderId: liveReminder.id, stepId: step.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: step.isDone ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(step.isDone ? CopilotTheme.actionGreen : CopilotTheme.actionBlue)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Paso \(index + 1) · \(step.estimatedMinutes) min")
                                    .font(.caption2.weight(.heavy))
                                    .foregroundStyle(step.isDone ? CopilotTheme.actionGreen : CopilotTheme.actionBlue)

                                Text(step.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .strikethrough(step.isDone, color: .white.opacity(0.5))
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .background(
                            step.isDone ? CopilotTheme.actionGreen.opacity(0.16) : Color.white.opacity(0.07),
                            in: RoundedRectangle(cornerRadius: 18)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(
                                    step.isDone ? CopilotTheme.actionGreen.opacity(0.55) : Color.white.opacity(0.14),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(spacing: 10) {
                Button {
                    triggerActionDoNow(minutes: 5)
                } label: {
                    Label("Arrancar Paso 1 con timer de 5 min", systemImage: "play.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(
                                colors: [CopilotTheme.actionBlue, CopilotTheme.actionGreen],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 20)
                        )
                }
                .buttonStyle(.plain)

                if doneCount == currentSteps.count && !currentSteps.isEmpty {
                    Button {
                        viewModel.completeReminder(id: liveReminder.id)
                    } label: {
                        Label("¡Completé todos los pasos! Cerrar tarea", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(CopilotTheme.actionGreen, in: RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button("Guardar pasos y volver luego") {
                        viewModel.dismissActiveAlert()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 4)
                }
            }
        }
        .padding(20)
        .liquidGlassCard(cornerRadius: 24, glowColor: CopilotTheme.actionBlue, isHighlighted: true)
    }

    // MARK: - 4. Confirmación Estricta de Posposición (Botón Rojo)

    private var strictSnoozeConfirmationSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "hourglass.badge.plus")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(CopilotTheme.actionRed)

            Text("Pospuesto 10 minutos exactos")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(snoozeWarningMessage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(CopilotTheme.warningAmber)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Text("Volveré a insistir a las \(formattedHour(snoozedReturnDate))")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.75))

            Button {
                viewModel.dismissActiveAlert()
            } label: {
                Text("Entendido, vuelvo en 10 min")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(CopilotTheme.actionRed, in: RoundedRectangle(cornerRadius: 22))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .liquidGlassCard(cornerRadius: 24, glowColor: CopilotTheme.actionRed, isHighlighted: true)
    }

    // MARK: - Lógica de Acciones

    private func triggerActionDoNow(minutes: Int) {
        AlarmAudioService.shared.stopAlarm()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        startPomodoro(minutes: minutes)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
            mode = .pomodoro
        }
    }

    private func triggerActionBreakdown() {
        AlarmAudioService.shared.stopAlarm()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        microSteps = viewModel.generateMicroStepsIfNeeded(for: liveReminder.id)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
            mode = .breakdown
        }
    }

    private func triggerActionStrictSnooze() {
        AlarmAudioService.shared.stopAlarm()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        let updated = viewModel.snoozeStrictly10Minutes(id: liveReminder.id)
        let count = updated?.snoozeCount ?? (liveReminder.snoozeCount + 1)
        snoozedReturnDate = updated?.snoozedUntil ?? Date().addingTimeInterval(10 * 60)

        if count <= 1 {
            snoozeWarningMessage = "Ok, 10 minutos, pero no abras TikTok."
        } else if count == 2 {
            snoozeWarningMessage = "Ya van \(count) avisos, José. 10 minutos para cerrar distracciones y arrancar."
        } else {
            snoozeWarningMessage = "Última tregua de 10 minutos. Deja el teléfono quieto y prepárate."
        }

        withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
            mode = .snoozedConfirmation
        }
    }

    // MARK: - Temporizador Pomodoro

    private func startPomodoro(minutes: Int) {
        stopPomodoroTimer()
        pomodoroTotalSeconds = minutes * 60
        pomodoroRemainingSeconds = minutes * 60
        resumePomodoro()
    }

    private func resumePomodoro() {
        isPomodoroRunning = true
        pomodoroRunToken = UUID()
    }

    private func pausePomodoro() {
        isPomodoroRunning = false
        pomodoroRunToken = UUID()
    }

    private func stopPomodoroTimer() {
        isPomodoroRunning = false
        pomodoroRunToken = UUID()
    }

    private func formattedHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
