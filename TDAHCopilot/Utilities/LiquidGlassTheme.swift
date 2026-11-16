import SwiftUI

extension Color {
    /// Inicializa un `Color` desde un código hexadecimal (`#RRGGBB` o `#AARRGGBB`).
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 56, 189, 248)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
}

/// Sistema de diseño nocturno "Liquid Glass" optimizado para reducir sobrecarga visual en TDAH Inatento.
enum CopilotTheme {
    // Gradiente nocturno profundo (azules/morados)
    static let midnightTop = Color(hex: "#060919")
    static let sapphireMid = Color(hex: "#0D1536")
    static let cosmicVioletBottom = Color(hex: "#1C113A")

    // Acentos semánticos luminosos
    static let neonCyan = Color(hex: "#22D3EE")
    static let electricBlue = Color(hex: "#38BDF8")
    static let royalIndigo = Color(hex: "#818CF8")
    static let mysticViolet = Color(hex: "#A855F7")

    // Acciones estrictas e indicadores
    static let actionGreen = Color(hex: "#10B981")
    static let actionBlue = Color(hex: "#38BDF8")
    static let actionRed = Color(hex: "#F43F5E")
    static let warningAmber = Color(hex: "#F59E0B")

    static let backgroundGradient = LinearGradient(
        colors: [midnightTop, sapphireMid, cosmicVioletBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// Fondo ambiental oscuro con orbes difuminados para potenciar el efecto translúcido `.ultraThinMaterial`.
struct NocturnalGlassBackground: View {
    var topOrbColor: Color = CopilotTheme.electricBlue
    var bottomOrbColor: Color = CopilotTheme.mysticViolet

    var body: some View {
        ZStack {
            CopilotTheme.backgroundGradient
                .ignoresSafeArea()

            GeometryReader { geo in
                Circle()
                    .fill(topOrbColor.opacity(0.22))
                    .frame(width: geo.size.width * 0.85, height: geo.size.width * 0.85)
                    .blur(radius: 90)
                    .offset(x: -geo.size.width * 0.25, y: -geo.size.height * 0.12)

                Circle()
                    .fill(bottomOrbColor.opacity(0.24))
                    .frame(width: geo.size.width * 0.9, height: geo.size.width * 0.9)
                    .blur(radius: 100)
                    .offset(x: geo.size.width * 0.30, y: geo.size.height * 0.55)

                Circle()
                    .fill(CopilotTheme.royalIndigo.opacity(0.14))
                    .frame(width: geo.size.width * 0.65, height: geo.size.width * 0.65)
                    .blur(radius: 80)
                    .offset(x: geo.size.width * 0.10, y: geo.size.height * 0.25)
            }
            .ignoresSafeArea()
        }
    }
}

/// Modificador reutilizable de tarjeta Liquid Glass (`.ultraThinMaterial` + `.cornerRadius(24)` + borde y resplandor opcional).
struct LiquidGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 24
    var glowColor: Color = CopilotTheme.neonCyan
    var isHighlighted: Bool = false
    var dimOpacity: Double = 1.0

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: isHighlighted
                                ? [glowColor.opacity(0.92), Color.white.opacity(0.45), glowColor.opacity(0.55)]
                                : [Color.white.opacity(0.22), Color.white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHighlighted ? 1.6 : 0.9
                    )
            )
            .shadow(
                color: isHighlighted ? glowColor.opacity(0.42) : Color.black.opacity(0.28),
                radius: isHighlighted ? 22 : 10,
                x: 0,
                y: isHighlighted ? 6 : 4
            )
            .opacity(dimOpacity)
    }
}

extension View {
    func liquidGlassCard(
        cornerRadius: CGFloat = 24,
        glowColor: Color = CopilotTheme.neonCyan,
        isHighlighted: Bool = false,
        dimOpacity: Double = 1.0
    ) -> some View {
        modifier(
            LiquidGlassCardModifier(
                cornerRadius: cornerRadius,
                glowColor: glowColor,
                isHighlighted: isHighlighted,
                dimOpacity: dimOpacity
            )
        )
    }
}

/// Utilidades de formateo temporal claras para combatir la ceguera del tiempo.
enum TimeFormatters {
    static func countdownString(seconds: TimeInterval) -> String {
        let clamped = max(0, Int(seconds.rounded(.down)))
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let secs = clamped % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    static func hourMinuteString(fromMinutesFromMidnight totalMinutes: Int) -> String {
        let safe = ((totalMinutes % 1440) + 1440) % 1440
        let hour24 = safe / 60
        let minute = safe % 60
        let period = hour24 >= 12 ? "PM" : "AM"
        let hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24)
        return String(format: "%d:%02d %@", hour12, minute, period)
    }

    static func relativeDueDescription(for date: Date, reference: Date = Date()) -> String {
        let diff = date.timeIntervalSince(reference)
        if diff <= 0 {
            let agoMins = max(1, Int(abs(diff) / 60))
            if agoMins < 60 {
                return "Vencido hace \(agoMins) min"
            }
            let agoHours = agoMins / 60
            return "Vencido hace \(agoHours) h"
        }
        let mins = Int(ceil(diff / 60))
        if mins < 60 {
            return "En \(mins) min"
        }
        let hours = mins / 60
        if hours < 24 {
            let remMins = mins % 60
            return remMins > 0 ? "En \(hours)h \(remMins)m" : "En \(hours) h"
        }
        let days = Int(ceil(diff / 86400))
        if days == 1 {
            return "Mañana"
        }
        return "En \(days) días"
    }
}
