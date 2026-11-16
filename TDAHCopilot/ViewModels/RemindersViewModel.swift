import Foundation
import SwiftUI
import Combine
import UIKit

/// ViewModel del Módulo 2: Bandeja de entrada de Recordatorios Persistentes y disparo automático
/// de la Alarma de Pantalla Completa (`ActiveReminderSheet`).
@MainActor
final class RemindersViewModel: ObservableObject {
    @Published var reminders: [PersistentReminder] = []
    @Published var activeTriggerReminder: PersistentReminder?

    private let storageKey = "tdah_copilot_reminders_v1"
    private let seededKey = "tdah_copilot_reminders_seeded_v1"
    private var triggeredCycles = Set<String>()

    init() {
        loadReminders()
        NotificationService.shared.onReminderNotificationTapped = { [weak self] reminderId in
            self?.triggerAlertById(reminderId)
        }
    }

    // MARK: - Persistencia

    private func loadReminders() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([PersistentReminder].self, from: data) {
            reminders = sortReminders(decoded)
            return
        }

        if !UserDefaults.standard.bool(forKey: seededKey) {
            reminders = sortReminders(PersistentReminder.sampleDefaults())
            UserDefaults.standard.set(true, forKey: seededKey)
            saveReminders()
        }
    }

    private func saveReminders() {
        if let data = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func sortReminders(_ list: [PersistentReminder]) -> [PersistentReminder] {
        list.sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted {
                return !lhs.isCompleted
            }
            return lhs.effectiveTriggerDate < rhs.effectiveTriggerDate
        }
    }

    // MARK: - Gestión de Recordatorios

    func addReminder(title: String, notes: String = "", dueDate: Date, friction: FrictionLevel) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        let reminder = PersistentReminder(
            title: cleanTitle,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: dueDate,
            friction: friction
        )
        reminders.append(reminder)
        reminders = sortReminders(reminders)
        saveReminders()
        NotificationService.shared.scheduleNotification(for: reminder)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func deleteReminder(id: UUID) {
        NotificationService.shared.cancelNotification(for: id)
        reminders.removeAll { $0.id == id }
        if activeTriggerReminder?.id == id {
            activeTriggerReminder = nil
        }
        saveReminders()
    }

    func completeReminder(id: UUID) {
        guard let idx = reminders.firstIndex(where: { $0.id == id }) else { return }
        reminders[idx].isCompleted = true
        reminders[idx].snoozedUntil = nil
        NotificationService.shared.cancelNotification(for: id)
        reminders = sortReminders(reminders)
        saveReminders()
        if activeTriggerReminder?.id == id {
            activeTriggerReminder = nil
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func reopenReminder(id: UUID) {
        guard let idx = reminders.firstIndex(where: { $0.id == id }) else { return }
        reminders[idx].isCompleted = false
        reminders[idx].dueDate = max(Date().addingTimeInterval(30 * 60), reminders[idx].dueDate)
        reminders[idx].snoozedUntil = nil
        let updated = reminders[idx]
        reminders = sortReminders(reminders)
        saveReminders()
        NotificationService.shared.scheduleNotification(for: updated)
    }

    /// Posposición estricta de 10 minutos (única duración permitida por el Botón Rojo).
    @discardableResult
    func snoozeStrictly10Minutes(id: UUID) -> PersistentReminder? {
        guard let idx = reminders.firstIndex(where: { $0.id == id }) else { return nil }
        let snoozeTarget = Date().addingTimeInterval(10 * 60)
        reminders[idx].snoozedUntil = snoozeTarget
        reminders[idx].snoozeCount += 1
        let updated = reminders[idx]
        reminders = sortReminders(reminders)
        saveReminders()
        NotificationService.shared.scheduleNotification(for: updated)
        return updated
    }

    /// Genera y guarda 3 micro-pasos fáciles usando `TaskBreakdownService`.
    func generateMicroStepsIfNeeded(for reminderId: UUID) -> [MicroStep] {
        guard let idx = reminders.firstIndex(where: { $0.id == reminderId }) else { return [] }
        if reminders[idx].microSteps.isEmpty {
            reminders[idx].microSteps = TaskBreakdownService.generateThreeMicroSteps(for: reminders[idx].title)
            saveReminders()
        }
        if activeTriggerReminder?.id == reminderId {
            activeTriggerReminder = reminders[idx]
        }
        return reminders[idx].microSteps
    }

    func toggleMicroStep(reminderId: UUID, stepId: UUID) {
        guard let rIdx = reminders.firstIndex(where: { $0.id == reminderId }),
              let sIdx = reminders[rIdx].microSteps.firstIndex(where: { $0.id == stepId }) else {
            return
        }
        reminders[rIdx].microSteps[sIdx].isDone.toggle()
        if activeTriggerReminder?.id == reminderId {
            activeTriggerReminder = reminders[rIdx]
        }
        saveReminders()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Monitor de Alarma en Primer Plano

    func triggerAlertImmediately(for reminder: PersistentReminder) {
        let cycleKey = cycleIdentifier(for: reminder)
        triggeredCycles.insert(cycleKey)
        activeTriggerReminder = reminder
    }

    func triggerAlertById(_ id: UUID) {
        guard let reminder = reminders.first(where: { $0.id == id && !$0.isCompleted }) else { return }
        triggerAlertImmediately(for: reminder)
    }

    func dismissActiveAlert() {
        activeTriggerReminder = nil
    }

    func checkDueReminders(now: Date = Date()) {
        guard activeTriggerReminder == nil else { return }

        let due = reminders.first { reminder in
            guard !reminder.isCompleted else { return false }
            let triggerDate = reminder.effectiveTriggerDate
            guard triggerDate <= now else { return false }
            // Evitar auto-disparar recordatorios vencidos hace más de 12 horas sin interacción nueva
            guard now.timeIntervalSince(triggerDate) < 12 * 3600 else { return false }
            let key = cycleIdentifier(for: reminder)
            return !triggeredCycles.contains(key)
        }

        if let due {
            triggerAlertImmediately(for: due)
        }
    }

    private func cycleIdentifier(for reminder: PersistentReminder) -> String {
        let epoch = Int(reminder.effectiveTriggerDate.timeIntervalSince1970)
        return "\(reminder.id.uuidString)-\(epoch)"
    }

    // MARK: - Agrupación para Bandeja de Entrada

    var pendingToday: [PersistentReminder] {
        let endOfToday = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: Date()) ?? Date()
        return reminders.filter { !$0.isCompleted && $0.effectiveTriggerDate <= endOfToday }
    }

    var pendingThisWeek: [PersistentReminder] {
        let endOfToday = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: Date()) ?? Date()
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return reminders.filter {
            !$0.isCompleted && $0.effectiveTriggerDate > endOfToday && $0.effectiveTriggerDate <= endOfWeek
        }
    }

    var pendingLater: [PersistentReminder] {
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return reminders.filter { !$0.isCompleted && $0.effectiveTriggerDate > endOfWeek }
    }

    var completedReminders: [PersistentReminder] {
        reminders.filter(\.isCompleted)
    }
}
