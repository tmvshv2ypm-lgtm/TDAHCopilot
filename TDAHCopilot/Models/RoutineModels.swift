import SwiftUI

/// Fase actual del día mostrada en la cabecera de estado de José.
enum DayPhase: String, Codable, CaseIterable, Identifiable {
    case morning = "Modo Mañana"
    case university = "Modo Universidad"
    case study = "Modo Estudio"
    case rest = "Hora de Descanso"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .university: return "graduationcap.fill"
        case .study: return "brain.head.profile"
        case .rest: return "moon.stars.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .morning: return CopilotTheme.warningAmber
        case .university: return CopilotTheme.electricBlue
        case .study: return CopilotTheme.mysticViolet
        case .rest: return CopilotTheme.neonCyan
        }
    }

    var shortTip: String {
        switch self {
        case .morning: return "Piloto automático matutino · Sin pantallas innecesarias"
        case .university: return "Enfoque en clases y traslados a tiempo"
        case .study: return "Un solo micro-paso a la vez"
        case .rest: return "Baja revoluciones · Protege tu descanso"
        }
    }
}

/// Estado temporal de un bloque dentro de la línea de tiempo diaria.
enum RoutineBlockState: Equatable {
    case past
    case active
    case upcoming
}

/// Bloque individual en el horario visual diario (Despertar, Cocinar, Clase ULA, Clase UNEFA, Tarea, etc.).
struct RoutineBlock: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var subtitle: String
    /// Frase de transición mostrada en la cuenta regresiva (ej. "salir de casa", "llegar a la ULA").
    var transitionTarget: String
    var iconName: String
    var startMinutesFromMidnight: Int
    var endMinutesFromMidnight: Int
    var phase: DayPhase
    var accentHex: String
    var completedDateKey: String?

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        transitionTarget: String,
        iconName: String,
        startMinutesFromMidnight: Int,
        endMinutesFromMidnight: Int,
        phase: DayPhase,
        accentHex: String,
        completedDateKey: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.transitionTarget = transitionTarget
        self.iconName = iconName
        self.startMinutesFromMidnight = startMinutesFromMidnight
        self.endMinutesFromMidnight = endMinutesFromMidnight
        self.phase = phase
        self.accentHex = accentHex
        self.completedDateKey = completedDateKey
    }

    var accentColor: Color {
        Color(hex: accentHex)
    }

    var durationMinutes: Int {
        max(5, endMinutesFromMidnight - startMinutesFromMidnight)
    }

    var timeRangeLabel: String {
        "\(TimeFormatters.hourMinuteString(fromMinutesFromMidnight: startMinutesFromMidnight)) – \(TimeFormatters.hourMinuteString(fromMinutesFromMidnight: endMinutesFromMidnight))"
    }

    func startDate(on referenceDate: Date, calendar: Calendar = .current) -> Date {
        let dayStart = calendar.startOfDay(for: referenceDate)
        return calendar.date(byAdding: .minute, value: startMinutesFromMidnight, to: dayStart) ?? referenceDate
    }

    func endDate(on referenceDate: Date, calendar: Calendar = .current) -> Date {
        let dayStart = calendar.startOfDay(for: referenceDate)
        return calendar.date(byAdding: .minute, value: endMinutesFromMidnight, to: dayStart) ?? referenceDate
    }

    func isCompleted(on dateKey: String) -> Bool {
        completedDateKey == dateKey
    }

    /// Rutina base personalizada para José (ULA / UNEFA / Estudio / Descanso).
    static let defaultSchedule: [RoutineBlock] = [
        RoutineBlock(
            title: "Despertar",
            subtitle: "Toma agua, abre cortinas y evita redes sociales",
            transitionTarget: "empezar a cocinar",
            iconName: "alarm.fill",
            startMinutesFromMidnight: 6 * 60 + 15,   // 06:15 AM
            endMinutesFromMidnight: 6 * 60 + 45,     // 06:45 AM
            phase: .morning,
            accentHex: "#F59E0B"
        ),
        RoutineBlock(
            title: "Cocinar",
            subtitle: "Desayuno y vianda antes de salir sin apuros",
            transitionTarget: "salir de casa",
            iconName: "fork.knife",
            startMinutesFromMidnight: 6 * 60 + 45,   // 06:45 AM
            endMinutesFromMidnight: 7 * 60 + 30,     // 07:30 AM
            phase: .morning,
            accentHex: "#FB923C"
        ),
        RoutineBlock(
            title: "Clase ULA",
            subtitle: "Bloque académico matutino · Mantén modo enfoque",
            transitionTarget: "cerrar bloque ULA",
            iconName: "building.columns.fill",
            startMinutesFromMidnight: 8 * 60,        // 08:00 AM
            endMinutesFromMidnight: 12 * 60,         // 12:00 PM
            phase: .university,
            accentHex: "#38BDF8"
        ),
        RoutineBlock(
            title: "Clase UNEFA",
            subtitle: "Jornada vespertina · Cuaderno y carnet listos",
            transitionTarget: "terminar jornada UNEFA",
            iconName: "graduationcap.fill",
            startMinutesFromMidnight: 13 * 60 + 30,  // 01:30 PM
            endMinutesFromMidnight: 17 * 60,         // 05:00 PM
            phase: .university,
            accentHex: "#6366F1"
        ),
        RoutineBlock(
            title: "Tarea",
            subtitle: "Micro-pasos de estudio sin distraerse con TikTok",
            transitionTarget: "pasar a descanso",
            iconName: "book.closed.fill",
            startMinutesFromMidnight: 17 * 60 + 30,  // 05:30 PM
            endMinutesFromMidnight: 20 * 60,         // 08:00 PM
            phase: .study,
            accentHex: "#A855F7"
        ),
        RoutineBlock(
            title: "Hora de Descanso",
            subtitle: "Desconexión sensorial y preparación para dormir",
            transitionTarget: "dormir a tiempo",
            iconName: "moon.stars.fill",
            startMinutesFromMidnight: 20 * 60 + 30,  // 08:30 PM
            endMinutesFromMidnight: 22 * 60 + 30,    // 10:30 PM
            phase: .rest,
            accentHex: "#22D3EE"
        )
    ]
}
