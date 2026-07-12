# Recordatorios personalizados por tarea

> **Estado**: Implementado ✅
> **Prioridad**: Alta — feature destacada y diferenciador principal.

Este documento describe cómo funcionan los recordatorios y notificaciones
en TaskLog. Inicialmente era un plan de trabajo; ahora está construido y
verificado en un Xiaomi con la app cerrada.

---

## Resumen

A diferencia de la mayoría de apps de tareas, que envían un único
recordatorio el día de la entrega, TaskLog permite **recordatorios
personalizables por tarea**: el usuario decide cuántos avisos quiere y
cuándo, de forma independiente por cada tarea.

### Ejemplo de uso real

Para una tarea *"Parcial 1"* que vence el 30 de mayo, el usuario puede
tener:

- 27 may 9:00 — *"3 días antes"*
- 29 may 18:00 — *"1 día antes"*
- 30 may 8:00 — *"El día de"*

Cada tarea con su propia configuración, independiente de las demás.

---

## Cómo se ve para el usuario

### En el formulario de tarea

Cuando el usuario crea o edita una tarea, en la sección "Recordatorios"
aparece una **card compacta** con el conteo y una flecha:

```
─────────────────────────────────────────
Recordatorios

┌───────────────────────────────────────┐
│ [🔔]  2 configurados               →  │
│       Toca para configurar antes...   │
└───────────────────────────────────────┘
─────────────────────────────────────────
```

Al tocarla, se abre una pantalla dedicada con los chips de presets y el
diálogo para agregar personalizados. Al volver, la card actualiza el
conteo.

### En el detalle de tarea

Card similar entre "Descripción" y "Notas asociadas":

```
┌───────────────────────────────────────┐
│ [🔔]  Recordatorios                →  │
│       3 programados                    │
└───────────────────────────────────────┘
```

Al tocarla, se abre `GestionRecordatoriosScreen` que muestra cada
recordatorio con su fecha absoluta calculada y descripción relativa:

```
🔔 Recordatorios programados

┌───────────────────────────────────────┐
│  🔔  27 de may, 09:00              🗑 │
│      3 días antes                      │
├───────────────────────────────────────┤
│  🔔  29 de may, 18:00              🗑 │
│      1 día antes                       │
├───────────────────────────────────────┤
│  🔔  30 de may, 08:00              🗑 │
│      el día de                         │
└───────────────────────────────────────┘

  + Agregar recordatorio
```

### La notificación en el celular

Con formato contextual según cuánto falta:

```
🔔  TaskLog
    Parcial 1
    Hoy vence
```

Al **tocar la notificación**, la app abre directo al detalle de esa tarea.

---

## Presets por defecto según importancia

Cuando se crea una tarea nueva, los recordatorios vienen pre-marcados
según su importancia:

| Importancia | Recordatorios por defecto |
|---|---|
| **Alta** | 7d antes, 3d antes, 1d antes, el día de |
| **Media** | 3d antes, 1d antes |
| **Baja** | el día de |

Hora por defecto: **9:00 AM** (formato 24h). El usuario puede modificar la
hora de cada recordatorio con un `TimePicker` en modo teclado (dos campos
numéricos, sin AM/PM).

Al **editar** una tarea existente, se respetan los recordatorios que el
usuario ya configuró — no se sobrescriben con los defaults.

---

## Comportamientos automáticos

El sistema mantiene las notificaciones sincronizadas con el estado real
de las tareas:

- **Crear tarea con recordatorios** → se programan en el sistema.
- **Editar la fecha límite o los recordatorios** → se cancelan los viejos
  y se programan los nuevos.
- **Marcar tarea como completada** → se cancelan sus recordatorios.
- **Desmarcar (reactivar)** → se reprograman los que aún no hayan
  disparado.
- **Eliminar tarea** → se cancelan todos sus recordatorios.
- **Recordatorio para una fecha ya pasada** → se omite sin error (por
  ejemplo, agregar "7 días antes" a una tarea que vence mañana).

---

## Modelo de datos

Cada tarea tiene un array `recordatorios` en Firestore, donde cada
recordatorio se describe con tres números:

```json
"recordatorios": [
  { "diasAntes": 3, "hora": 9, "minuto": 0 },
  { "diasAntes": 1, "hora": 18, "minuto": 0 },
  { "diasAntes": 0, "hora": 8, "minuto": 0 }
]
```

La fecha absoluta se calcula al momento de programar la notificación:
`fechaLimite - diasAntes días @ hora:minuto local`.

En Dart este es el modelo `TaskReminder` (`lib/models/task_reminder.dart`).

---

## Implementación técnica

### Plugin usado: `awesome_notifications`

El plan original apuntaba a `flutter_local_notifications`, pero durante
la implementación descubrimos que ese plugin usa `AlarmManager` puro, que
MIUI (Xiaomi) mata en background. Migramos a **`awesome_notifications`**
que internamente usa **`WorkManager`**, mucho más respetuoso con las
políticas de restricción de fabricantes agresivos.

Con esta migración, las notificaciones llegan puntuales incluso con la
app cerrada en Xiaomi, después de que el usuario configure los ajustes
del sistema (autoinicio + sin restricciones de batería).

### Canal Android

- **Key**: `recordatorios_tareas`
- **Nombre**: "Recordatorios de tareas"
- **Importancia**: `Max` (heads-up banner, no puede ser silenciado)
- **Categoría por notificación**: `Alarm` (máxima prioridad para
  esquivar restricciones)
- **Wake up screen**: sí
- **Sonido y vibración**: usa los que el usuario tenga configurados

### IDs de notificación

Determinísticos por tarea + índice del recordatorio:

```
id = (hash(taskId) & 0x7FFFFFFF) % 20_000_000 * 100 + índice
```

Esto permite cancelar recordatorios específicos de una tarea sin afectar
los de otras.

### Timezone

`flutter_timezone` se usa para configurar `tz.local` con la zona horaria
real del dispositivo (por ejemplo `America/Bogota`). Sin esto, `tz.local`
quedaría en UTC y las fechas se desfasarían.

### Navegación al tap

Se registra un `GlobalKey<NavigatorState>` en `MaterialApp`. El callback
`onActionReceivedMethod` de `awesome_notifications` lo usa para hacer
push a `DetalleTareaScreen` con el `taskId` del payload.

---

## Limitaciones conocidas (Xiaomi y similares)

MIUI (Xiaomi) y sistemas similares (EMUI de Huawei, ColorOS de Oppo,
FuntouchOS de Vivo) cierran aplicaciones en background de forma agresiva.
Para que los recordatorios sean 100% confiables, el usuario debe
configurar tres ajustes en su celular:

1. **Ajustes → Aplicaciones → TaskLog → Alarmas y recordatorios** → ON.
2. **Ajustes → Aplicaciones → TaskLog → Ahorrar batería** → "Sin
   restricciones".
3. **Ajustes → Permisos → Autoinicio → TaskLog** → ON.

Esto **no es un bug de TaskLog** — pasa con cualquier app en Xiaomi,
incluyendo WhatsApp, Gmail y Telegram. Es la razón por la cual mucha
gente configura las apps de mensajería al comprar un Xiaomi.

Una futura versión podría incluir una pantalla de onboarding que detecte
el fabricante y guíe al usuario a estos ajustes automáticamente
(feature en el roadmap del README).

---

## Librerías usadas

| Librería | Para qué |
|---|---|
| `awesome_notifications: ^0.10.1` | Motor principal de notificaciones locales, con WorkManager por debajo. |
| `timezone: ^0.9.4` | Base de datos de zonas horarias. |
| `flutter_timezone: ^3.0.1` | Obtiene la zona horaria del dispositivo para configurar `tz.local`. |

---

## Archivos relevantes en el código

- `lib/models/task_reminder.dart` — modelo del recordatorio.
- `lib/models/task_item.dart` — extendido con `List<TaskReminder>
  recordatorios`.
- `lib/services/notification_service.dart` — programación, cancelación,
  navegación al tap.
- `lib/services/firestore_service.dart` — engancha `add`, `update`,
  `delete` y `setTaskCompletada` con el servicio de notificaciones.
- `lib/widgets/recordatorios_selector.dart` — chips de presets + diálogo
  de agregar personalizado.
- `lib/screens/forms/seleccionar_recordatorios_screen.dart` — pantalla
  para configurar recordatorios al crear/editar tarea.
- `lib/screens/tasks/gestion_recordatorios_screen.dart` — pantalla para
  gestionar recordatorios desde el detalle de tarea.
