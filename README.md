# TDAH Copilot (iOS)

Aplicación de asistencia ejecutiva en **SwiftUI** diseñada específicamente para **TDAH Inatento**, con estética **Liquid Glass** (`.ultraThinMaterial`, `.cornerRadius(24)` y gradientes nocturnos en azul/morado).

## Módulos Implementados

### Módulo 1: Dashboard de Rutina Visual (`RoutineDashboardView.swift`)
- **Cabecera de Estado**: Saludo personalizado (`Hola, José`) e indicador dinámico de fase del día (`Modo Mañana`, `Modo Universidad`, `Modo Estudio`, `Hora de Descanso`).
- **Línea de Tiempo Visual**: Bloques verticales diarios (`Despertar`, `Cocinar`, `Clase ULA`, `Clase UNEFA`, `Tarea`, `Hora de Descanso`).
  - Bloque activo resaltado con resplandor y cuenta regresiva gigante en vivo.
  - Bloques pasados difuminados con baja opacidad (`0.38`).
  - Permite enfocar manualmente cualquier bloque (`▶`) o agregar bloques personalizados.
- **Botón de Pánico / Niñero Digital (`Me distraje`)**: Botón flotante que abre `DistractionPanicSheet.swift` con guía empática inmediata y cuenta regresiva háptica de 5 segundos.
- **Atajos de iPhone (URL Scheme)**: Soporta `tdahcopilot://distracted` para abrir directamente el modal anti-procrastinación al detectar apertura de apps como TikTok mediante Atajos de iOS.

### Módulo 2: Recordatorios Persistentes (`RemindersView.swift` y `ActiveReminderSheet.swift`)
- **Bandeja de Entrada Rápida**: Captura tareas para hoy, 1 semana, 1 mes o fecha exacta con nivel de **Fricción** (`Baja`, `Media`, `Alta`).
- **Alarma de Tarea (Full-Screen Takeover)**:
  - Bloquea cierre por deslizamiento (`.interactiveDismissDisabled(true)`).
  - Reproduce alarma sonora continua sintetizada con `AVFoundation` (`AlarmAudioService.swift`) hasta recibir interacción.
  - **3 Opciones Estrictas**:
    1. **Botón Verde (`Hacerlo ahora`)**: Inicia de inmediato un temporizador visual Pomodoro.
    2. **Botón Azul (`Desglosar`)**: Divide la tarea en 3 micro-pasos fáciles (`TaskBreakdownService.swift`) para vencer la parálisis por análisis.
    3. **Botón Rojo (`Posponer 10 min`)**: Pospone estrictamente 10 minutos con recordatorio firme (`"Ok, 10 minutos, pero no abras TikTok."`).

## Compilación en GitHub Actions (.ipa sin firmar)
El workflow `.github/workflows/ios-build.yml` compila `TDAHCopilot` en `xcode-27` y genera `TDAHCopilot-Unsigned.ipa` listo para instalar en iPhone mediante SideStore, AltStore o Sideloadly.
