import Foundation
import SwiftUI
import Combine
import UIKit

/// ViewModel del Módulo 1: Dashboard de Rutina Visual y Línea de Tiempo contra la ceguera del tiempo.
@MainActor
final class RoutineViewModel: ObservableObject {
    @Published var blocks: [RoutineBlock] = []
    @Published var pinnedBlockId: UUID?
    @Published var pinnedStartDate: Date?
    @Published var pinnedEndDate: Date?

    private let storageKey = "tdah_copilot_routine_blocks_v1"

    init() {
        loadBlocks()
    }

    // MARK: - Persistencia

    private func loadBlocks() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([RoutineBlock].self, from: data),
           !decoded.isEmpty {
            blocks = decoded.sorted { $0.startMinutesFromMidnight < $1.startMinutesFromMidnight }
        } else {
            blocks = RoutineBlock.defaultSchedule.sorted { $0.startMinutesFromMidnight < $1.startMinutesFromMidnight }
            saveBlocks()
        }
    }

    private func saveBlocks() {
        if let data = try? JSONEncoder().encode(blocks) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func resetDefaultSchedule() {
        clearPinnedBlock()
        blocks = RoutineBlock.defaultSchedule.sorted { $0.startMinutesFromMidnight < $1.startMinutesFromMidnight }
        saveBlocks()
    }

    func addBlock(_ block: RoutineBlock) {
        blocks.append(block)
        blocks.sort { $0.startMinutesFromMidnight < $1.startMinutesFromMidnight }
        saveBlocks()
    }

    func deleteBlock(id: UUID) {
        if pinnedBlockId == id {
            clearPinnedBlock()
        }
        blocks.removeAll { $0.id == id }
        saveBlocks()
    }

    // MARK: - Evaluación Temporal de Hoy

    func todayKey(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    func activeBlock(at now: Date) -> RoutineBlock? {
        if let pinnedId = pinnedBlockId,
           let end = pinnedEndDate,
           now < end,
           let found = blocks.first(where: { $0.id == pinnedId }) {
            return found
        }

        let key = todayKey(for: now)
        return blocks.first { block in
            guard !block.isCompleted(on: key) else { return false }
            let start = block.startDate(on: now)
            let end = block.endDate(on: now)
            return now >= start && now < end
        }
    }

    func nextUpcomingBlock(at now: Date) -> RoutineBlock? {
        let key = todayKey(for: now)
        let currentActiveId = activeBlock(at: now)?.id
        return blocks.first { block in
            guard block.id != currentActiveId, !block.isCompleted(on: key) else { return false }
            return block.startDate(on: now) > now
        }
    }

    func state(for block: RoutineBlock, at now: Date) -> RoutineBlockState {
        if let active = activeBlock(at: now), active.id == block.id {
            return .active
        }
        let key = todayKey(for: now)
        if block.isCompleted(on: key) {
            return .past
        }
        if block.endDate(on: now) <= now {
            return .past
        }
        return .upcoming
    }

    func currentPhase(at now: Date) -> DayPhase {
        if let active = activeBlock(at: now) {
            return active.phase
        }
        if let next = nextUpcomingBlock(at: now),
           next.startDate(on: now).timeIntervalSince(now) <= 3600 {
            return next.phase
        }

        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 5..<11:
            return .morning
        case 11..<17:
            return .university
        case 17..<21:
            return .study
        default:
            return .rest
        }
    }

    func remainingAndProgress(for active: RoutineBlock, at now: Date) -> (remaining: TimeInterval, progress: Double) {
        if pinnedBlockId == active.id, let start = pinnedStartDate, let end = pinnedEndDate {
            let total = max(1, end.timeIntervalSince(start))
            let remaining = max(0, end.timeIntervalSince(now))
            let elapsed = total - remaining
            return (remaining, min(1, max(0, elapsed / total)))
        }

        let start = active.startDate(on: now)
        let end = active.endDate(on: now)
        let total = max(1, end.timeIntervalSince(start))
        let remaining = max(0, end.timeIntervalSince(now))
        let elapsed = total - remaining
        return (remaining, min(1, max(0, elapsed / total)))
    }

    func countdownPhrase(for block: RoutineBlock, remainingSeconds: TimeInterval) -> String {
        let mins = max(1, Int(ceil(remainingSeconds / 60)))
        if mins <= 10 {
            if block.transitionTarget.lowercased().contains("salir") {
                return "Faltan \(mins) minutos para salir. Ve a ponerte los zapatos."
            }
            return "Faltan \(mins) min para \(block.transitionTarget). Prepárate ahora."
        }
        return "Te quedan \(mins) minutos para \(block.transitionTarget)"
    }

    // MARK: - Interacciones de Enfoque y Completado

    func markCompletedToday(blockId: UUID, at now: Date = Date()) {
        let key = todayKey(for: now)
        guard let idx = blocks.firstIndex(where: { $0.id == blockId }) else { return }
        blocks[idx].completedDateKey = (blocks[idx].completedDateKey == key) ? nil : key
        if pinnedBlockId == blockId && blocks[idx].completedDateKey == key {
            clearPinnedBlock()
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        saveBlocks()
    }

    /// Permite enfocar manualmente cualquier bloque con una cuenta regresiva activa inmediata (útil fuera de horario o en pruebas).
    func startManualFocus(for block: RoutineBlock, minutes: Int = 15, at now: Date = Date()) {
        let safeMinutes = max(5, minutes)
        pinnedBlockId = block.id
        pinnedStartDate = now
        pinnedEndDate = now.addingTimeInterval(TimeInterval(safeMinutes * 60))
        if let idx = blocks.firstIndex(where: { $0.id == block.id }) {
            blocks[idx].completedDateKey = nil
            saveBlocks()
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func clearPinnedBlock() {
        pinnedBlockId = nil
        pinnedStartDate = nil
        pinnedEndDate = nil
    }
}
