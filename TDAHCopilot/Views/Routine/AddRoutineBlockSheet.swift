import SwiftUI

/// Hoja rápida para añadir un nuevo bloque visual al horario diario de José.
struct AddRoutineBlockSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (RoutineBlock) -> Void

    @State private var title: String = ""
    @State private var subtitle: String = ""
    @State private var transitionTarget: String = ""
    @State private var selectedPhase: DayPhase = .study
    @State private var startDate: Date = Date()
    @State private var durationMinutes: Int = 45

    private let durationChoices = [15, 30, 45, 60, 90, 120]

    var body: some View {
        NavigationStack {
            ZStack {
                NocturnalGlassBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Nombre del bloque")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.75))

                            TextField("Ej. Repaso Anatomía, Almuerzo...", text: $title)
                                .textFieldStyle(.plain)
                                .padding(14)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)

                            Text("Recordatorio de acción (opcional)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.75))

                            TextField("Ej. Salir de casa 10 min antes", text: $subtitle)
                                .textFieldStyle(.plain)
                                .padding(14)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)

                            Text("Meta de cuenta regresiva")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.75))

                            TextField("Ej. salir de casa / terminar tarea", text: $transitionTarget)
                                .textFieldStyle(.plain)
                                .padding(14)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)
                        }
                        .padding(16)
                        .liquidGlassCard(cornerRadius: 24)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Fase del día")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.75))

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(DayPhase.allCases) { phase in
                                    Button {
                                        selectedPhase = phase
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: phase.iconName)
                                            Text(phase.rawValue)
                                                .font(.caption.weight(.semibold))
                                                .lineLimit(1)
                                        }
                                        .foregroundStyle(selectedPhase == phase ? .white : .white.opacity(0.7))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .padding(.horizontal, 10)
                                        .background(
                                            selectedPhase == phase
                                                ? phase.accentColor.opacity(0.32)
                                                : Color.white.opacity(0.06),
                                            in: RoundedRectangle(cornerRadius: 14)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(
                                                    selectedPhase == phase ? phase.accentColor : Color.clear,
                                                    lineWidth: 1.2
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(16)
                        .liquidGlassCard(cornerRadius: 24)

                        VStack(alignment: .leading, spacing: 12) {
                            DatePicker("Hora de inicio", selection: $startDate, displayedComponents: .hourAndMinute)
                                .foregroundStyle(.white)
                                .tint(CopilotTheme.neonCyan)

                            Text("Duración visual")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.75))

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(durationChoices, id: \.self) { mins in
                                        Button {
                                            durationMinutes = mins
                                        } label: {
                                            Text("\(mins) min")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(
                                                    durationMinutes == mins
                                                        ? CopilotTheme.neonCyan.opacity(0.35)
                                                        : Color.white.opacity(0.08),
                                                    in: Capsule()
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .liquidGlassCard(cornerRadius: 24)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Nuevo Bloque")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveBlock()
                    }
                    .fontWeight(.bold)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func saveBlock() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: startDate)
        let startMins = (comps.hour ?? 9) * 60 + (comps.minute ?? 0)
        let endMins = min(23 * 60 + 55, startMins + durationMinutes)
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTarget = transitionTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex: String
        switch selectedPhase {
        case .morning: hex = "#F59E0B"
        case .university: hex = "#38BDF8"
        case .study: hex = "#A855F7"
        case .rest: hex = "#22D3EE"
        }

        let newBlock = RoutineBlock(
            title: cleanTitle,
            subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Bloque visual enfocado sin distracciones"
                : subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
            transitionTarget: cleanTarget.isEmpty ? "cerrar \(cleanTitle)" : cleanTarget,
            iconName: selectedPhase.iconName,
            startMinutesFromMidnight: startMins,
            endMinutesFromMidnight: max(startMins + 5, endMins),
            phase: selectedPhase,
            accentHex: hex
        )
        onSave(newBlock)
        dismiss()
    }
}
