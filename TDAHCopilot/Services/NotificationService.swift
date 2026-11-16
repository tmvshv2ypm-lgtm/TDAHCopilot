import Foundation
@preconcurrency import UserNotifications

/// Gestiona permisos y notificaciones locales "Time-Sensitive" para despertar al usuario fuera de la app
/// y enlazar directamente con la Alarma de Pantalla Completa (`ActiveReminderSheet`) al abrirla.
@MainActor
final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Callback invocado cuando José toca una notificación de recordatorio.
    var onReminderNotificationTapped: ((UUID) -> Void)?

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Task {
            await refreshAuthorizationStatus()
        }
    }

    func requestPermissionIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus

        guard settings.authorizationStatus == .notDetermined else { return }
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
        } catch {
            // Ignorar errores en simulador o permisos denegados
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Programa la notificación del recordatorio (incluye respaldo Time-Sensitive sin requerir entitlements restringidos).
    func scheduleNotification(for reminder: PersistentReminder) {
        let center = UNUserNotificationCenter.current()
        let identifier = reminder.id.uuidString
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard !reminder.isCompleted else { return }
        let triggerDate = reminder.effectiveTriggerDate
        let secondsUntilFire = triggerDate.timeIntervalSinceNow
        guard secondsUntilFire > 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = "TDAH Copilot · Fricción \(reminder.friction.rawValue)"
        content.body = reminder.title
        content.subtitle = reminder.notes.isEmpty ? "Toca para abrir tu alarma de tarea" : reminder.notes
        content.sound = .default
        content.userInfo = ["reminderId": identifier]
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: secondsUntilFire, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    func cancelNotification(for reminderId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderId.uuidString])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [reminderId.uuidString])
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let idString = notification.request.content.userInfo["reminderId"] as? String
        if let idString, let uuid = UUID(uuidString: idString) {
            await MainActor.run {
                self.onReminderNotificationTapped?(uuid)
            }
        }
        return [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let idString = response.notification.request.content.userInfo["reminderId"] as? String
        if let idString, let uuid = UUID(uuidString: idString) {
            await MainActor.run {
                self.onReminderNotificationTapped?(uuid)
            }
        }
    }
}
