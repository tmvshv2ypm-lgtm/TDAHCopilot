import SwiftUI

/// Tarjeta individual de la Línea de Tiempo Visual.
/// Muestra un resplandor intenso + cuenta regresiva gigante en el bloque activo,
/// opacidad reducida en bloques pasados y estilo Liquid Glass limpio en bloques próximos.
struct RoutineBlockCard: View {
    let block: RoutineBlock
    let state: RoutineBlockState
    let remainingSeconds: TimeInterval
    let progress: Double
    let countdownPhrase: String
    let isManuallyFocused: Bool
    let isLast: Bool
    let onToggleComplete: () -> Void
    let onFocusNow: () -> Void
    let onDelete: () -> Void

    @State private var pulseGlow: Bool = false

    private var isWarningWindow: Bool {
        state == .active && remainingSeconds <= 10 * 60
    }

    private var cardAccent: Color {
        isWarningWindow ? CopilotTheme.warningAmber : block.accentColor
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            timelineNode
                .padding(.top, 8)

            cardContent
                .padding(state == .active ? 18 : 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .liquidGlassCard(
                    cornerRadius: 24,
                    glowColor: cardAccent,
                    isHighlighted: state == .active,
                    dimOpacity: state == .past ? 0.38 : 1.0
                )
                .scaleEffect(state == .active && pulseGlow ? 1.008 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseGlow)
                .onAppear {
                    if state == .active {
                        pulseGlow = true
                    }
                }
                .onChange(of: state) { _, newState in
                    pulseGlow = (newState == .active)
                }
        }
        .background(alignment: .topLeading) {
            if !isLast {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                (state == .active ? cardAccent : Color.white).opacity(state == .past ? 0.14 : 0.32),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 2)
                    .padding(.leading, 16)
                    .padding(.top, 42)
                    .padding(.bottom, -14)
            }
        }
        .contextMenu {
            Button {
                onFocusNow()
            } label: {
                Label("Enfocar este bloque ahora (15 min)", systemImage: "play.circle.fill")
            }

            Button {
                onToggleComplete()
            } label: {
                Label(
                    state == .past ? "Desmarcar completado" : "Marcar bloque como listo",
                    systemImage: "checkmark.circle"
                )
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Eliminar bloque", systemImage: "trash")
            }
        }
    }

    // MARK: - Nodo de la Línea de Tiempo

    private var timelineNode: some View {
        ZStack {
            if state == .active {
                Circle()
                    .fill(cardAccent.opacity(0.32))
                    .frame(width: 34, height: 34)
                    .blur(radius: 4)
            }

            Circle()
                .fill(
                    state == .active
                        ? cardAccent
                        : (state == .past ? Color.white.opacity(0.18) : Color.white.opacity(0.28))
                )
                .frame(width: state == .active ? 18 : 12, height: state == .active ? 18 : 12)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(state == .active ? 0.85 : 0.35), lineWidth: 1.5)
                )
        }
        .frame(width: 34, height: 34)
    }

    // MARK: - Contenido de la Tarjeta

    @ViewBuilder
    private var cardContent: some View {
        switch state {
        case .active:
            activeCardBody
        case .past:
            standardCardBody(isPast: true)
        case .upcoming:
            standardCardBody(isPast: false)
        }
    }

    private var activeCardBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: block.iconName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(cardAccent)
                    .frame(width: 38, height: 38)
                    .background(cardAccent.opacity(0.18), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(isManuallyFocused ? "ENFOQUE MANUAL" : "BLOQUE ACTUAL")
                            .font(.caption2.weight(.heavy))
                            .tracking(0.8)
                            .foregroundStyle(cardAccent)

                        Text("· \(block.phase.rawValue)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    Text(block.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 4)

                Button(action: onToggleComplete) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(CopilotTheme.actionGreen)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Marcar \(block.title) como completado")
            }

            // Cuenta regresiva visual gigante contra la ceguera del tiempo
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(TimeFormatters.countdownString(seconds: remainingSeconds))
                        .font(.system(size: 50, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(
                            LinearGradient(
                                colors: isWarningWindow
                                    ? [Color.white, CopilotTheme.warningAmber]
                                    : [Color.white, cardAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    Spacer()

                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.14), lineWidth: 5)
                        Circle()
                            .trim(from: 0, to: CGFloat(1.0 - progress))
                            .stroke(
                                cardAccent,
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                        Text("\(Int((1.0 - progress) * 100))%")
                            .font(.caption2.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .frame(width: 48, height: 48)
                }

                Text(countdownPhrase)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isWarningWindow ? CopilotTheme.warningAmber : .white.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)

                // Barra de progreso lineal visual
                GeometryReader { barGeo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [cardAccent, CopilotTheme.mysticViolet],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, barGeo.size.width * CGFloat(progress)))
                    }
                }
                .frame(height: 7)
            }

            HStack {
                Label(block.timeRangeLabel, systemImage: "clock")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.68))

                Spacer()

                Text(block.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }
        }
    }

    private func standardCardBody(isPast: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isPast ? "checkmark.circle.fill" : block.iconName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(isPast ? CopilotTheme.actionGreen.opacity(0.85) : block.accentColor)
                .frame(width: 38, height: 38)
                .background(
                    (isPast ? CopilotTheme.actionGreen : block.accentColor).opacity(0.14),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(block.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .strikethrough(isPast, color: .white.opacity(0.45))

                    Text("· \(block.durationMinutes) min")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Text(block.timeRangeLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(block.accentColor.opacity(0.92))

                if !isPast {
                    Text(block.subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 6)

            if !isPast {
                Button(action: onFocusNow) {
                    Image(systemName: "play.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(block.accentColor.opacity(0.28), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Activar \(block.title) ahora")
            }
        }
    }
}
