import Foundation

/// Generador local estilo Goblin.tools: divide tareas abrumadoras en 3 micro-pasos ridículamente pequeños
/// para vencer la parálisis por análisis y liberar micro-dosis de dopamina al tacharlos.
enum TaskBreakdownService {
    static func generateThreeMicroSteps(for taskTitle: String) -> [MicroStep] {
        let lower = taskTitle.folding(options: .diacriticInsensitive, locale: .current).lowercased()

        if lower.contains("examen") || lower.contains("estudiar") || lower.contains("odontolog") || lower.contains("repas") || lower.contains("clase") || lower.contains("leer") {
            return [
                MicroStep(title: "Sentarte en tu escritorio y dejar el teléfono boca abajo", estimatedMinutes: 2),
                MicroStep(title: "Sacar el cuaderno o abrir exactamente la guía del tema", estimatedMinutes: 1),
                MicroStep(title: "Leer solo la primera página o resumir 3 conceptos clave", estimatedMinutes: 5)
            ]
        }

        if lower.contains("informe") || lower.contains("practica") || lower.contains("tarea") || lower.contains("proyecto") || lower.contains("pdf") || lower.contains("trabajo") {
            return [
                MicroStep(title: "Abrir el documento en blanco y escribir solo el título", estimatedMinutes: 2),
                MicroStep(title: "Anotar 3 viñetas rápidas con lo que debe llevar", estimatedMinutes: 3),
                MicroStep(title: "Completar únicamente el primer párrafo sin buscar perfección", estimatedMinutes: 5)
            ]
        }

        if lower.contains("limpiar") || lower.contains("ordenar") || lower.contains("lavar") || lower.contains("cuarto") || lower.contains("casa") || lower.contains("ropa") {
            return [
                MicroStep(title: "Recoger solo 5 objetos fuera de lugar en 90 segundos", estimatedMinutes: 2),
                MicroStep(title: "Agrupar la ropa o basura en una sola bolsa o cesto", estimatedMinutes: 3),
                MicroStep(title: "Despejar únicamente una superficie (escritorio o cama)", estimatedMinutes: 5)
            ]
        }

        if lower.contains("cocinar") || lower.contains("comida") || lower.contains("desayuno") || lower.contains("almuerzo") || lower.contains("cena") {
            return [
                MicroStep(title: "Tomar un vaso de agua y poner los ingredientes sobre la mesa", estimatedMinutes: 2),
                MicroStep(title: "Encender la cocina o preparar la proteína/base principal", estimatedMinutes: 4),
                MicroStep(title: "Servir y dejar el plato principal remojándose al terminar", estimatedMinutes: 4)
            ]
        }

        if lower.contains("tramite") || lower.contains("pagar") || lower.contains("enviar") || lower.contains("correo") || lower.contains("certificado") || lower.contains("llamar") {
            return [
                MicroStep(title: "Buscar y tener a mano los datos o archivo que necesitas", estimatedMinutes: 2),
                MicroStep(title: "Abrir la página o redactar el borrador sin enviarlo aún", estimatedMinutes: 2),
                MicroStep(title: "Revisar rápido y presionar Enviar o confirmar el trámite", estimatedMinutes: 3)
            ]
        }

        // Respaldo universal anti-parálisis aplicable a cualquier tarea
        return [
            MicroStep(title: "Dejar el teléfono quieto y preparar solo lo necesario para empezar", estimatedMinutes: 2),
            MicroStep(title: "Definir una micro-meta de inicio (solo los primeros 3 minutos)", estimatedMinutes: 3),
            MicroStep(title: "Ejecutar el primer bloque mínimo sin preocuparte por terminar todo", estimatedMinutes: 5)
        ]
    }
}
