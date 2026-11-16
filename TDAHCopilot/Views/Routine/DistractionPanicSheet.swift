import SwiftUI
import UIKit

/// Modal firme pero empático del "Niñero Digital" activado por el botón "Me distraje".
/// Ayuda a cortar el bucle de dopamina (TikTok / scroll infinito) con una cuenta de 5 segundos y retorno guiado.
struct DistractionPanicSheet: View {
    @Environment(\.dismiss) private var dismiss

    let activeBlockTitle: String

    @State private var secondsRemaining: Int = 5
    @State private var countdownSessionId: UUID = UUID()
    @State private var breathingExpanded: Bool = false

    private var countdownFinished: Bool {
        secondsRemaining == 0
    }

    var body: some View {
        ZStack {
            NocturnalGlassBackground(
                topOrbColor: CopilotTheme.actionRed,
                bottomOrbColor: CopilotTheme.mysticViolet
            )

            ScrollView {
                VStack(spacing: 22) {
                    // Cabecera empática
                    VStack(spacing: 8) {
                        Label("NIÑERO DIGITAL · RESCATE", systemImage: "hand.raised.fill")
                            .font(.caption.weight(.heavy))
                            .tracking(1.1)
                            .foregroundStyle(CopilotTheme.warningAmber)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(CopilotTheme.warningAmber.opacity(0.16), in: Capsule())

                        Text("Corta el piloto automático")
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text("Respira. Deja el teléfono boca abajo. Cuenta hasta 5 y levántate.")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.94))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    .padding(.top, 14)

                    // Círculo interactivo de cuenta regresiva de 5 segundos
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        (countdownFinished ? CopilotTheme.actionGreen : CopilotTheme.neonCyan).opacity(0.32),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 12,
                                    endRadius: 110
                                )
                            )
                            .frame(width: 210, height: 210)
                            .scaleEffect(breathingExpanded ? 1.12 : 0.92)
                            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: breathingExpanded)

                        Circle()
                            .stroke(Color.white.opacity(0.16), lineWidth: 8)
                            .frame(width: 158, height: 158)

                        Circle()
                            .trim(from: 0, to: CGFloat(5 - secondsRemaining) / 5.0)
                            .stroke(
                                countdownFinished ? CopilotTheme.actionGreen : CopilotTheme.neonCyan,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 158, height: 158)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.4), value: secondsRemaining)

                        VStack(spacing: 4) {
                            if countdownFinished {
                                Image(systemName: "figure.walk")
                                    .font(.system(size: 38, weight: .bold))
                                    .foregroundStyle(CopilotTheme.actionGreen)
                                Text("¡Levántate!")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)
                            } else {
                                Text("\(secondsRemaining)")
                                    .font(.system(size: 58, weight: .heavy, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                                Text("segundos")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    // 3 Instrucciones inmediatas en tarjetas Liquid Glass
                    VStack(spacing: 12) {
                        groundingStepRow(
                            number: "1",
                            title: "Deja el teléfono boca abajo",
                            detail: "Sin culpa ni regaños: solo bloquea la pantalla ahora mismo.",
                            color: CopilotTheme.actionRed
                        )
                        groundingStepRow(
                            number: "2",
                            title: "Inhala lento y ponte de pie",
                            detail: "Cambiar de postura física reinicia tu corteza prefrontal.",
                            color: CopilotTheme.neonCyan
                        )
                        groundingStepRow(
                            number: "3",
                            title: "Vuelve solo 2 minutos a: \(activeBlockTitle)",
                            detail: "No tienes que hacerlo perfecto; solo retoma el movimiento.",
                            color: CopilotTheme.actionGreen
                        )
                    }

                    // Acciones de salida
                    VStack(spacing: 12) {
                        Button {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            dismiss()
                        } label: {
                            Label("Ya dejé el teléfono · Volver a \(activeBlockTitle)", systemImage: "checkmark.circle.fill")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [CopilotTheme.actionGreen, CopilotTheme.neonCyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                                )
                                .shadow(color: CopilotTheme.actionGreen.opacity(0.38), radius: 14, y: 5)
                        }
                        .buttonStyle(.plain)

                        Button {
                            restartFiveSecondCountdown()
                        } label: {
                            Label("Repetir cuenta de 5 segundos", systemImage: "arrow.counterclockwise")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.86))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(.ultraThinMaterial)
                                .cornerRadius(18)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            breathingExpanded = true
        }
        .task(id: countdownSessionId) {
            secondsRemaining = 5
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            while secondsRemaining > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                if secondsRemaining > 1 {
                    secondsRemaining -= 1
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } else {
                    secondsRemaining = 0
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        }
    }

    private func groundingStepRow(number: String, title: String, detail: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Text(number)
                .font(.headline.weight(.heavy))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.18), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .liquidGlassCard(cornerRadius: 24, glowColor: color, isHighlighted: false)
    }

    private func restartFiveSecondCountdown() {
        countdownSessionId = UUID()
    }
}
