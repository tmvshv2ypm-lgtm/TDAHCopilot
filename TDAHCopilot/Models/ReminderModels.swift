import SwiftUI

/// Nivel de insistencia del "Niñero Digital" para cada recordatorio persistente.
enum FrictionLevel: String, Codable, CaseIterable, Identifiable {
    case low = "Baja"
    case medium = "Media"
    case high = "Alta"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .low: return "Suave · Aviso gentil"
        case .medium: return "Firme · Insistencia moderada"
        case .high: return "Crítica · Alarma de vida"
        }
    }

    var badgeColor: Color {
        switch self {
        case .low: return CopilotTheme.neonCyan
        case .medium: return CopilotTheme.warningAmber
        case .high: return CopilotTheme.actionRed
        }
    }

    var iconName: String {
        switch self {
        case .low: return "bell.fill"
        case .medium: return "bell.badge.fill"
        case .high: return "exclamationmark.triangle.fill"
        }
    }
}

/// Atajos rápidos de horizonte temporal para capturar recordatorios sin fricción.
enum ReminderHorizon: String, CaseIterable, Identifiable {
    case inThirtyMinutes = "En 30 min"
    case tonight = "Hoy noche"
    case nextWeek = "En 1 semana"
    case nextMonth = "En 1 mes"
    case custom = "Elegir fecha"

    var id: String { rawValue }

    func targetDate(from now: Date = Date(), calendar: Calendar = .current) -> Date {
        switch self {
        case .inThirtyMinutes:
            return now.addingTimeInterval(30 * 60)
        case .tonight:
            var comps = calendar.dateComponents([.year, .month, .day], from: now)
            comps.hour = 20
            comps.minute = 0
            let candidate = calendar.date(from: comps) ?? now.addingTimeInterval(3600)
            return candidate > now ? candidate : (calendar.date(byAdding: .day, value: 1, to: candidate) ?? now.addingTimeInterval(3600))
        case .nextWeek:
            return calendar.date(byAdding: .day, value: 7, to: now) ?? now.addingTimeInterval(7 * 86400)
        case .nextMonth:
            return calendar.date(byAdding: .month, value: 1, to: now) ?? now.addingTimeInterval(30 * 86400)
        case .custom:
            return now.addingTimeInterval(3600)
        }
    }
}

/// Micro-paso generado por el botón azul "Desglosar" (estilo Goblin.tools) contra la parálisis por análisis.
struct MicroStep: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var estimatedMinutes: Int
    var isDone: Bool

    init(
        id: UUID = UUID(),
        title: String,
        estimatedMinutes: Int,
        isDone: Bool = false
    ) {
        self.id = id
        self.title = title
        self.estimatedMinutes = estimatedMinutes
        self.isDone = isDone
    }
}

/// Recordatorio persistente de la bandeja de entrada (Módulo 2).
struct PersistentReminder: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var notes: String
    var dueDate: Date
    var friction: FrictionLevel
    var isCompleted: Bool
    var snoozedUntil: Date?
    var snoozeCount: Int
    var microSteps: [MicroStep]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        dueDate: Date,
        friction: FrictionLevel = .medium,
        isCompleted: Bool = false,
        snoozedUntil: Date? = nil,
        snoozeCount: Int = 0,
        microSteps: [MicroStep] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.friction = friction
        self.isCompleted = isCompleted
        self.snoozedUntil = snoozedUntil
        self.snoozeCount = snoozeCount
        self.microSteps = microSteps
        self.createdAt = createdAt
    }

    /// Fecha efectiva que dispara la alarma en pantalla completa (toma en cuenta posposición estricta de 10 min).
    var effectiveTriggerDate: Date {
        snoozedUntil ?? dueDate
    }

    var completedMicroStepsCount: Int {
        microSteps.filter(\.isDone).count
    }

    static func sampleDefaults(reference: Date = Date(), calendar: Calendar = .current) -> [PersistentReminder] {
        let todayStudy = reference.addingTimeInterval(2 * 3600)
        let weekTask = calendar.date(byAdding: .day, value: 7, to: reference) ?? reference.addingTimeInterval(7 * 86400)
        let monthTask = calendar.date(byAdding: .month, value: 1, to: reference) ?? reference.addingTimeInterval(30 * 86400)

        return [
            PersistentReminder(
                title: "Estudiar para el examen de Odontología",
                notes: "Tema de anatomía dental y casos clínicos. No dejarlo para última hora.",
                dueDate: todayStudy,
                friction: .high
            ),
            PersistentReminder(
                title: "Entregar informe de práctica UNEFA",
                notes: "Revisar portada, exportar PDF y subir al aula virtual.",
                dueDate: weekTask,
                friction: .medium
            ),
            PersistentReminder(
                title: "Ordenar escritorio y lavar ropa",
                notes: "Solo 15 minutos con temporizador visual.",
                dueDate: monthTask,
                friction: .low
            )
        ]
    }
}
