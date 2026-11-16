import Foundation
import AVFoundation
import UIKit

/// Servicio de alarma auditiva persistente con `AVFoundation`.
/// Sintetiza tonos PCM en memoria sin depender de archivos externos y reproduce en bucle continuo
/// hasta que el usuario elija una de las 3 acciones estrictas de `ActiveReminderSheet`.
@MainActor
final class AlarmAudioService {
    static let shared = AlarmAudioService()

    private var audioPlayer: AVAudioPlayer?
    private var hapticTask: Task<Void, Never>?
    private(set) var isRinging: Bool = false

    private init() {}

    /// Inicia la alarma sonora en bucle infinito y pulsos hápticos acorde al nivel de fricción.
    func startAlarm(friction: FrictionLevel) {
        stopAlarm()

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)

            let wavData = Self.synthesizeAlarmWAV(for: friction)
            let player = try AVAudioPlayer(data: wavData, fileTypeHint: AVFileType.wav.rawValue)
            player.numberOfLoops = -1
            switch friction {
            case .low:
                player.volume = 0.65
            case .medium:
                player.volume = 0.85
            case .high:
                player.volume = 1.0
            }
            player.prepareToPlay()
            player.play()
            audioPlayer = player
            isRinging = true
        } catch {
            // Respaldo háptico si el hardware o simulador rechaza la sesión de audio
            isRinging = true
        }

        startHapticLoop(for: friction)
    }

    /// Detiene inmediatamente el sonido persistente y los pulsos hápticos.
    func stopAlarm() {
        isRinging = false
        hapticTask?.cancel()
        hapticTask = nil

        audioPlayer?.stop()
        audioPlayer = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Ignorar si otro audio estaba activo o en simulador
        }
    }

    private func startHapticLoop(for friction: FrictionLevel) {
        hapticTask?.cancel()
        triggerHaptic(for: friction)

        let interval: TimeInterval
        switch friction {
        case .low: interval = 2.6
        case .medium: interval = 1.6
        case .high: interval = 1.0
        }

        hapticTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled, let self, self.isRinging else { return }
                self.triggerHaptic(for: friction)
            }
        }
    }

    private func triggerHaptic(for friction: FrictionLevel) {
        switch friction {
        case .low:
            let gen = UIImpactFeedbackGenerator(style: .soft)
            gen.impactOccurred()
        case .medium:
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.warning)
        case .high:
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.error)
        }
    }

    // MARK: - Síntesis PCM WAV en Memoria

    private nonisolated static func synthesizeAlarmWAV(for friction: FrictionLevel) -> Data {
        let sampleRate = 44100
        let cycleSeconds: Double
        let pulses: [(start: Double, duration: Double, f1: Double, f2: Double)]

        switch friction {
        case .low:
            cycleSeconds = 2.6
            pulses = [
                (0.05, 0.28, 523.25, 783.99),
                (0.42, 0.35, 659.25, 987.77)
            ]
        case .medium:
            cycleSeconds = 1.8
            pulses = [
                (0.04, 0.18, 659.25, 987.77),
                (0.28, 0.18, 783.99, 1174.66),
                (0.54, 0.24, 659.25, 987.77)
            ]
        case .high:
            cycleSeconds = 1.35
            pulses = [
                (0.03, 0.14, 880.00, 1318.51),
                (0.21, 0.14, 987.77, 1479.98),
                (0.39, 0.14, 880.00, 1318.51),
                (0.60, 0.22, 1046.50, 1567.98)
            ]
        }

        let totalSamples = Int(Double(sampleRate) * cycleSeconds)
        var pcm = Data(capacity: 44 + totalSamples * 2)

        let dataByteCount = UInt32(totalSamples * 2)
        let riffSize = UInt32(36) + dataByteCount

        // Cabecera WAV estándar RIFF/PCM 16-bit mono 44.1 kHz
        pcm.append(contentsOf: Array("RIFF".utf8))
        appendLittleEndian(riffSize, to: &pcm)
        pcm.append(contentsOf: Array("WAVE".utf8))
        pcm.append(contentsOf: Array("fmt ".utf8))
        appendLittleEndian(UInt32(16), to: &pcm)           // Subchunk1Size (PCM)
        appendLittleEndian(UInt16(1), to: &pcm)            // AudioFormat = 1
        appendLittleEndian(UInt16(1), to: &pcm)            // NumChannels = 1
        appendLittleEndian(UInt32(sampleRate), to: &pcm)   // SampleRate
        appendLittleEndian(UInt32(sampleRate * 2), to: &pcm) // ByteRate
        appendLittleEndian(UInt16(2), to: &pcm)            // BlockAlign
        appendLittleEndian(UInt16(16), to: &pcm)           // BitsPerSample
        pcm.append(contentsOf: Array("data".utf8))
        appendLittleEndian(dataByteCount, to: &pcm)

        let attack = 0.012
        let release = 0.028

        for i in 0..<totalSamples {
            let t = Double(i) / Double(sampleRate)
            var sampleValue = 0.0

            for pulse in pulses {
                let end = pulse.start + pulse.duration
                if t >= pulse.start && t <= end {
                    let localT = t - pulse.start
                    let envIn = min(1.0, localT / attack)
                    let envOut = min(1.0, (end - t) / release)
                    let env = min(envIn, envOut)
                    let wave = 0.62 * sin(2.0 * .pi * pulse.f1 * t) + 0.38 * sin(2.0 * .pi * pulse.f2 * t)
                    sampleValue += wave * env * 0.55
                }
            }

            let clamped = max(-1.0, min(1.0, sampleValue))
            let intSample = Int16(clamped * Double(Int16.max))
            appendLittleEndian(UInt16(bitPattern: intSample), to: &pcm)
        }

        return pcm
    }

    private nonisolated static func appendLittleEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { rawBuffer in
            data.append(contentsOf: rawBuffer)
        }
    }
}
