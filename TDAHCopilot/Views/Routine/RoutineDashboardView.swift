import SwiftUI
import UIKit

/// Pantalla Principal (Módulo 1): Dashboard de Rutina Visual para José.
/// Incluye cabecera de estado, línea de tiempo vertical con cuenta regresiva gigante en el bloque activo,
/// bloques pasados atenuados y botón flotante "Me distraje" del Niñero Digital.
struct RoutineDashboardView: View {
    @ObservedObject var viewModel: RoutineViewModel
    @Binding var isShowingPanicSheet: Bool

    @State private var isShowingAddBlockSheet: Bool = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let now = context.date
            let activeBlock = viewModel.activeBlock(at: now)
            let nextBlock = viewModel.nextUpcomingBlock(at: now)
            let currentPhase = viewModel.currentPhase(at: now)

            ZStack(alignment: .bottom) {
                NocturnalGlassBackground(
                    topOrbColor: currentPhase.accentColor,
                    bottomOrbColor: CopilotTheme.mysticViolet
                )

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        // 1. Cabecera de Estado ("Hola, José" + fase del día)
                        statusHeaderSection(phase: currentPhase, now: now, activeBlock: activeBlock)

                        // 2. Tarjeta puente si estamos entre bloques o tras finalizar el día
                        if activeBlock == nil {
                            transitionBridgeCard(nextBlock: nextBlock, now: now)
                        }

                        // 3. Encabezado de la Línea de Tiempo + botones rápidos
                        timelineSectionHeader

                        // 4. Línea de Tiempo Vertical
                        LazyVStack(spacing: 14) {
                            ForEach(viewModel.blocks) { block in
                                let blockState = viewModel.state(for: block, at: now)
                                let metrics = viewModel.remainingAndProgress(for: block, at: now)
                                let phrase = viewModel.countdownPhrase(for: block, remainingSeconds: metrics.remaining)

                                RoutineBlockCard(
                                    block: block,
                                    state: blockState,
                                    remainingSeconds: metrics.remaining,
                                    progress: metrics.progress,
                                    countdownPhrase: phrase,
                                    isManuallyFocused: viewModel.pinnedBlockId == block.id,
                                    isLast: block.id == viewModel.blocks.last?.id,
                                    onToggleComplete: {
                                        viewModel.markCompletedToday(blockId: block.id, at: now)
                                    },
                                    onFocusNow: {
                                        viewModel.startManualFocus(for: block, minutes: 15, at: now)
                                    },
                                    onDelete: {
                                        viewModel.deleteBlock(id: block.id)
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 165)
                }

                // 5. Botón de Pánico / Niñero flotante ("Me distraje")
                panicFloatingBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 84)
            }
        }
        .sheet(isPresented: $isShowingPanicSheet) {
            DistractionPanicSheet(
                activeBlockTitle: viewModel.activeBlock(at: Date())?.title
                    ?? viewModel.nextUpcomingBlock(at: Date())?.title
                    ?? "tu rutina"
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingAddBlockSheet) {
            AddRoutineBlockSheet { newBlock in
                viewModel.addBlock(newBlock)
            }
        }
    }

    // MARK: - 1. Cabecera de Estado

    private func statusHeaderSection(phase: DayPhase, now: Date, activeBlock: RoutineBlock?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hola, José")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(formattedSpanishDate(now))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.68))
                }

                Spacer()

                // Indicador de la fase actual del día
                HStack(spacing: 6) {
                    Image(systemName: phase.iconName)
                        .font(.caption.weight(.bold))
                    Text(phase.rawValue)
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(phase.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(phase.accentColor.opacity(0.55), lineWidth: 1)
                )
            }

            HStack(spacing: 10) {
                Image(systemName: activeBlock != nil ? "sparkles" : "clock.badge.checkmark")
                    .foregroundStyle(phase.accentColor)
                Text(phase.shortTip)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.84))

                Spacer()

                if viewModel.pinnedBlockId != nil {
                    Button("Horario real") {
                        viewModel.clearPinnedBlock()
                    }
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(CopilotTheme.neonCyan)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(CopilotTheme.neonCyan.opacity(0.16), in: Capsule())
                }
            }
        }
        .padding(18)
        .liquidGlassCard(cornerRadius: 24, glowColor: phase.accentColor, isHighlighted: false)
    }

    // MARK: - 2. Tarjeta Puente cuando no hay bloque activo en este minuto

    private func transitionBridgeCard(nextBlock: RoutineBlock?, now: Date) -> some View {
        Group {
            if let next = nextBlock {
                let untilStart = max(0, next.startDate(on: now).timeIntervalSince(now))
                let mins = max(1, Int(ceil(untilStart / 60)))

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("TRANSICIÓN ACTIVA", systemImage: "arrow.forward.circle.fill")
                            .font(.caption2.weight(.heavy))
                            .tracking(0.8)
                            .foregroundStyle(CopilotTheme.neonCyan)

                        Spacer()

                        Button {
                            viewModel.startManualFocus(for: next, minutes: 15, at: now)
                        } label: {
                            Label("Iniciar ya (15 min)", systemImage: "play.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(next.accentColor.opacity(0.32), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Text(TimeFormatters.countdownString(seconds: untilStart))
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    Text("Faltan \(mins) minutos para empezar \(next.title). Prepara lo mínimo sin abrir redes.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.88))
                }
                .padding(18)
                .liquidGlassCard(cornerRadius: 24, glowColor: next.accentColor, isHighlighted: true)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Label("JORNADA COMPLETADA", systemImage: "moon.stars.fill")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(CopilotTheme.neonCyan)

                    Text("Ya cerraste tus bloques de hoy, José.")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)

                    Text("Toca ▶ en cualquier bloque de abajo si quieres activar una cuenta regresiva visual de prueba.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .liquidGlassCard(cornerRadius: 24, glowColor: CopilotTheme.neonCyan, isHighlighted: false)
            }
        }
    }

    // MARK: - 3. Encabezado de Timeline

    private var timelineSectionHeader: some View {
        HStack {
            Text("Línea de Tiempo de Hoy")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Spacer()

            Menu {
                Button {
                    isShowingAddBlockSheet = true
                } label: {
                    Label("Agregar bloque", systemImage: "plus")
                }

                Button {
                    viewModel.resetDefaultSchedule()
                } label: {
                    Label("Restaurar horario ULA / UNEFA", systemImage: "arrow.counterclockwise")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    Text("Bloque")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(CopilotTheme.electricBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
            }
        }
        .padding(.horizontal, 2)
    }

    // MARK: - 5. Botón Flotante "Me distraje"

    private var panicFloatingBar: some View {
        Button {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            isShowingPanicSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.18), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Me distraje")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                    Text("Pausa de emergencia · Niñero Digital")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.84))
                }

                Spacer()

                Image(systemName: "chevron.up.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [
                        CopilotTheme.actionRed.opacity(0.88),
                        CopilotTheme.mysticViolet.opacity(0.88)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.32), lineWidth: 1.2)
            )
            .shadow(color: CopilotTheme.actionRed.opacity(0.45), radius: 18, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func formattedSpanishDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "EEEE d 'de' MMMM · h:mm a"
        let raw = formatter.string(from: date)
        return raw.prefix(1).uppercased() + String(raw.dropFirst())
    }
}
