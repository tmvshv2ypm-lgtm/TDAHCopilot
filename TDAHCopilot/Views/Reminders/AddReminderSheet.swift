import SwiftUI

/// Hoja de creación rápida para capturar recordatorios de hoy, una semana o un mes con nivel de fricción.
struct AddReminderSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onCreate: (String, String, Date, FrictionLevel) -> Void

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var selectedHorizon: ReminderHorizon = .inThirtyMinutes
    @State private var customDate: Date = Date().addingTimeInterval(3600)
    @State private var friction: FrictionLevel = .high

    private let quickTemplates: [(label: String, title: String, friction: FrictionLevel)] = [
        ("Examen", "Estudiar para el examen de ", .high),
        ("Tarea ULA/UNEFA", "Entregar tarea / práctica de ", .medium),
        ("Casa", "Limpiar y ordenar ", .low)
    ]

    private var effectiveDate: Date {
        selectedHorizon == .custom ? customDate : selectedHorizon.targetDate()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NocturnalGlassBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Plantillas rápidas
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Atajos rápidos")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.75))

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(quickTemplates, id: \.label) { item in
                                        Button {
                                            title = item.title
                                            friction = item.friction
                                        } label: {
                                            Text(item.label)
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(.ultraThinMaterial)
                                                .cornerRadius(16)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                        .strokeBorder(item.friction.badgeColor.opacity(0.55), lineWidth: 1)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        // Título y notas
                        VStack(alignment: .leading, spacing: 10) {
                            Text("¿Qué debes recordar sin falta?")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.75))

                            TextField("Ej. Examen de Odontología, pagar servicio...", text: $title)
                                .textFieldStyle(.plain)
                                .padding(14)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)

                            Text("Detalles o contexto (opcional)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.75))

                            TextField("Ej. Revisar capítulos 4 y 5", text: $notes, axis: .vertical)
                                .lineLimit(2...4)
                                .textFieldStyle(.plain)
                                .padding(14)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)
                        }
                        .padding(16)
                        .liquidGlassCard(cornerRadius: 24)

                        // Cuándo debe sonar (Hoy, 1 semana, 1 mes, fecha exacta)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("¿Para cuándo es?")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.75))

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(ReminderHorizon.allCases) { horizon in
                                    Button {
                                        selectedHorizon = horizon
                                        if horizon != .custom {
                                            customDate = horizon.targetDate()
                                        }
                                    } label: {
                                        Text(horizon.rawValue)
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(
                                                selectedHorizon == horizon
                                                    ? CopilotTheme.electricBlue.opacity(0.35)
                                                    : Color.white.opacity(0.07),
                                                in: RoundedRectangle(cornerRadius: 14)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .strokeBorder(
                                                        selectedHorizon == horizon ? CopilotTheme.electricBlue : Color.clear,
                                                        lineWidth: 1.2
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            DatePicker(
                                "Fecha y hora exacta",
                                selection: $customDate,
                                in: Date()...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .foregroundStyle(.white)
                            .tint(CopilotTheme.neonCyan)
                            .onChange(of: customDate) { _, _ in
                                selectedHorizon = .custom
                            }
                        }
                        .padding(16)
                        .liquidGlassCard(cornerRadius: 24)

                        // Nivel de Fricción (qué tan duro debe insistir la app)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Nivel de Fricción (Alarma de Vida)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.75))

                            ForEach(FrictionLevel.allCases) { level in
                                Button {
                                    friction = level
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: level.iconName)
                                            .foregroundStyle(level.badgeColor)
                                            .frame(width: 32, height: 32)
                                            .background(level.badgeColor.opacity(0.18), in: Circle())

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Fricción \(level.rawValue)")
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(.white)
                                            Text(level.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.7))
                                        }

                                        Spacer()

                                        if friction == level {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(level.badgeColor)
                                        }
                                    }
                                    .padding(12)
                                    .background(
                                        friction == level ? level.badgeColor.opacity(0.16) : Color.white.opacity(0.05),
                                        in: RoundedRectangle(cornerRadius: 16)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .strokeBorder(
                                                friction == level ? level.badgeColor.opacity(0.75) : Color.clear,
                                                lineWidth: 1.2
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                        .liquidGlassCard(cornerRadius: 24)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Nuevo Recordatorio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        onCreate(title, notes, effectiveDate, friction)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
