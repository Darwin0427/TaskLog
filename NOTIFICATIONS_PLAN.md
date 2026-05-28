# Plan: Recordatorios personalizados por tarea

> **Estado**: Propuesta · No implementado todavía
> **Prioridad**: Alta (feature destacada, diferenciador frente a otras apps)

---

## Resumen

La mayoría de apps de tareas envían un único recordatorio el día de la
entrega. Este plan agrega **recordatorios personalizables por tarea**: el
usuario decide cuántos avisos quiere y cuándo, de forma independiente por
cada tarea.

### Ejemplo de uso real

Para una tarea "Parcial 1" que vence el 30 de mayo, el usuario podría
tener:

- 27 may 9:00 AM — *"3 días antes"*
- 29 may 6:00 PM — *"1 día antes"*
- 30 may 8:00 AM — *"El día de"*

Cada tarea tendría su propia configuración, independiente de las demás.

---

## Cómo se verá

### En el formulario de tarea

Después del campo "Fecha límite" aparece una nueva sección con chips
horizontales para activar/desactivar recordatorios y un botón para agregar
uno personalizado:

```
─────────────────────────────────────────
RECORDATORIOS
   ┌──────────────────────┐ ┌─────────────┐
   │ ✓ El día de · 8:00   │ │ ✗ 1d antes  │
   └──────────────────────┘ └─────────────┘
   ┌──────────────────────┐ ┌─────────────┐
   │ ✓ 3d antes · 9:00    │ │ ✗ 1sem antes│
   └──────────────────────┘ └─────────────┘

   + Agregar recordatorio personalizado
─────────────────────────────────────────
```

Cada chip se activa o desactiva con un toque. Tocar la hora abre un selector
para cambiarla. El botón "+" abre un modal donde se pueden combinar días,
horas y minutos a voluntad.

### En el detalle de tarea

Una sección dedicada muestra los recordatorios ya programados con su fecha
exacta calculada, y un botón de papelera al lado para borrarlos uno a uno:

```
Recordatorios programados
   27 may, 9:00 AM   (3 días antes)        [Eliminar]
   29 may, 6:00 PM   (1 día antes)         [Eliminar]
   30 may, 8:00 AM   (el día de)           [Eliminar]

   + Agregar recordatorio
```

---

## Presets por defecto según importancia

Para que el formulario sea cómodo sin tener que configurar todo a mano, los
recordatorios vienen pre-marcados según la importancia de la tarea:

| Importancia | Recordatorios por defecto |
|---|---|
| **Alta** | 7d antes, 3d antes, 1d antes, el día de |
| **Media** | 3d antes, 1d antes |
| **Baja** | el día de |

La hora por defecto es las 9:00 AM, configurable por cada recordatorio.

---

## Modelo de datos

Cada tarea guarda una lista de recordatorios. Un recordatorio se describe
con tres números: **cuántos días antes** del vencimiento debe sonar (0 = el
día de), **a qué hora** (0-23) y **a qué minuto** (0-59). La fecha exacta
se calcula al momento de programar la notificación, restando los días al
vencimiento de la tarea.

Esta lista se almacena en Firestore dentro del documento de la tarea como
un array de objetos, sin afectar la estructura existente.

---

## Plan de implementación en 7 fases

Cada fase es entregable e independiente — al terminarla, ya se puede
verificar manualmente que funciona.

### Fase 1 — Base del sistema de notificaciones

Instalar el plugin de notificaciones locales, pedir los permisos
correspondientes en Android e inicializar el servicio al arrancar la app.
Se crea un canal específico llamado "Recordatorios de tareas" que el
sistema operativo usa para agrupar y dar control al usuario.

**Cómo verificarlo**: con un botón temporal de prueba, lanzar una
notificación y confirmar que aparece en la bandeja del sistema.

### Fase 2 — Modelo de recordatorios

Definir el nuevo objeto `TaskReminder` y extender el modelo de tarea para
incluir la lista de recordatorios. Adaptar la lectura y escritura contra
Firestore para que persista correctamente.

**Cómo verificarlo**: crear una tarea con recordatorios programáticamente
y revisar en la consola de Firestore que se guarda como un array de mapas.

### Fase 3 — Interfaz de configuración

Construir el widget que permite al usuario activar, desactivar y
personalizar los recordatorios desde el formulario de la tarea. Incluye
los chips de presets, el selector de hora y el modal de recordatorio
personalizado. Aplicar los defaults inteligentes según la importancia.

**Cómo verificarlo**: crear una tarea desde la UI con varios recordatorios
y confirmar que se guardan correctamente.

### Fase 4 — Programación automática de notificaciones

Conectar la lógica de programación con el sistema operativo. Cada vez que
se crea o edita una tarea, la app calcula la fecha exacta de cada
recordatorio y la registra en el sistema. Si la tarea se marca como
completada o se elimina, las notificaciones se cancelan automáticamente.
Si se desmarca, vuelven a programarse las que aún no han vencido.

**Cómo verificarlo**: crear una tarea con un recordatorio para dentro de
dos minutos, esperar y confirmar que la notificación llega.

### Fase 5 — Visualización en el detalle

Mostrar al usuario qué recordatorios tiene programados para esa tarea,
con la fecha exacta ya calculada y una descripción legible ("3 días
antes"). Permitir eliminarlos individualmente desde ahí o agregar nuevos
sin tener que editar la tarea completa.

**Cómo verificarlo**: abrir el detalle de una tarea con recordatorios,
eliminar uno y comprobar que también se canceló su notificación
correspondiente en el sistema.

### Fase 6 — Onboarding para celulares con restricciones

Detectar si el dispositivo es Xiaomi, Huawei u Oppo (fabricantes
conocidos por restricciones agresivas en background) y, la primera vez,
mostrar una pantalla guía con los pasos específicos para que las
notificaciones lleguen confiablemente. Incluye accesos directos a los
ajustes del sistema.

**Cómo verificarlo**: en un Xiaomi, abrir la app por primera vez y
confirmar que aparece el onboarding; abrirla una segunda vez y verificar
que ya no se muestra.

### Fase 7 — Testing y pulido

Validación manual de los escenarios completos: notificaciones que llegan
a tiempo, re-programación al editar fechas, cancelación al completar o
borrar tareas, persistencia tras reiniciar el celular, manejo correcto
de recordatorios cuya fecha ya pasó, y comportamiento esperado en
dispositivos con restricciones.

---

## Plan B — MVP rápido

Si se prefiere una versión más simple primero antes del plan completo:

1. **Un solo recordatorio por tarea** en lugar de una lista. Un campo de
   fecha y hora únicos.
2. **Cuatro presets fijos** sin opción de personalizar: "El día de",
   "1 día antes", "3 días antes", "1 semana antes".
3. **Sin onboarding de Xiaomi** — solo se agrega si en pruebas reales
   aparecen problemas.

Esta versión cubre el 80% del valor con una fracción del trabajo. Después
se puede iterar hacia el plan completo si la feature se valida con
usuarios reales.

---

## Limitaciones conocidas (Xiaomi y similares)

MIUI (el sistema de Xiaomi) cierra aplicaciones en segundo plano de forma
agresiva. Para que los recordatorios sean confiables, el usuario debe
configurar tres ajustes en su celular:

1. **Ajustes → Aplicaciones → TaskLog → Inicio automático**: activar.
2. **Ahorro de batería**: marcar la app como "sin restricciones".
3. **Otros permisos → Mostrar en pantalla bloqueada**: activar.

Esto **no es un bug de la app**: ocurre con cualquier app en Xiaomi,
incluyendo WhatsApp, Gmail y Telegram. Por eso la Fase 6 del plan agrega
una pantalla de onboarding que explica al usuario estos pasos la primera
vez que abre la app en un dispositivo afectado.

Otros fabricantes con restricciones similares: Huawei, Oppo, Vivo y
Realme.

---

## Librerías que se usarían

| Librería | Para qué sirve |
|---|---|
| `flutter_local_notifications` | Programar notificaciones locales en Android e iOS. |
| `timezone` | Manejo correcto de zonas horarias para que las notificaciones lleguen a la hora exacta. |
| `app_settings` | Abrir directamente los ajustes nativos del sistema desde la app. |
| `device_info_plus` | Detectar el fabricante del dispositivo para mostrar el onboarding solo cuando hace falta. |
| `shared_preferences` | Guardar localmente la marca de "onboarding completado" para no repetirlo. |

---

## Decisiones por tomar antes de implementar

Antes de empezar conviene cerrar estas decisiones de producto:

- Confirmar qué presets son los más útiles para estudiantes (los cuatro
  propuestos u otros).
- Definir si la hora por defecto es 9:00 AM fija o si el usuario la elige
  globalmente la primera vez.
- Decidir qué pasa si el usuario cambia la importancia de una tarea
  después de crearla: ¿se actualizan los recordatorios automáticamente al
  preset nuevo, o se respetan los que el usuario ya configuró?
- Definir el texto del cuerpo de la notificación. Opciones a evaluar:
  *"Vence en X días"*, *"Mañana vence: [título]"*, *"Hoy vence:
  [título]"*.
