# gestor_tareas

App Flutter para gestionar tareas, notas y calificaciones académicas con Firebase
(Authentication + Cloud Firestore). Diseñada para estudiantes: organiza tu
semestre por materias, registra tareas con prioridad y fechas límite, lleva
tus notas del curso y calcula automáticamente lo que necesitas para aprobar.

## Integrantes

- Darwin Marín
- Jean Paul Durango Márquez

## Nota sobre el servicio de datos

Aunque el reto sugería implementar un fake backend en memoria con `uuid` y
`Future.delayed`, este proyecto integra **Cloud Firestore como backend real**.
Esto cumple e incluso supera los objetivos del fake backend:

- **Lista en "memoria"**: reemplazada por persistencia real en Firestore con
  caché offline automático.
- **`Future.delayed` simulado**: reemplazado por operaciones asíncronas reales
  vía `Future<void>` y `Stream` en `FirestoreService`.
- **IDs alfanuméricos con `uuid`**: reemplazados por los IDs auto-generados
  de Firestore (alfanuméricos, únicos y distribuidos).
- **CRUD**: implementado por entidad (Subjects, Tasks, Notes, GradeItems) con
  `add`, `update`, `delete` y `watch*` para streams en tiempo real.

Todos los **comportamientos visuales** que pide el reto se mantienen:
`CircularProgressIndicator` mientras guarda, manejo de errores, etc.

## Características

### Navegación principal
- **3 tabs**: Tareas, Calendario, Calificaciones.
- **FAB expandible** sobre la bottom bar para crear notas o tareas rápido.

### Tareas
- Agrupadas por prioridad (Alta / Media / Baja) ordenadas por fecha límite.
- Sección "Completadas" colapsable.
- Checkbox circular para marcar completada (tachado + opacidad).
- Detalle con notas asociadas, editar y eliminar (con confirmación).
- Una tarea puede vincularse a una calificación de su materia (ver abajo).

### Calendario
- Vista Mes / Semana (2 semanas) / Día.
- Indicador de día con tareas (punto de color de la materia).
- Filtro por materia (chips) que afecta puntos y lista del día.
- Lista de tareas del día seleccionado abajo.

### Calificaciones
- Lista de materias con promedio, barra de progreso del % evaluado y conteo de
  ítems.
- Detalle de materia con 3 sub-tabs: Notas, Tareas, Notas del curso.
- Información extra opcional: profesor, aula/salón, link de clase virtual.

### Notas del curso (grade items)
- Cada ítem evaluativo tiene nombre, % del curso, y nota (0-5).
- Validación de % al crear: no se puede superar el 100%.
- Cálculo automático de **Acumulado** y **Promedio actual**.
- Calculadora **"¿Qué nota necesito?"**: dado un objetivo (configurable con
  slider), te dice qué promedio necesitas en los ítems pendientes para llegar.
- Edición rápida de nota desde diálogo compacto.

### Vinculación tarea ↔ calificación
- Una tarea puede vincularse a UN ítem evaluativo de su materia.
- La nota de la tarea pasa a ser directamente la nota del ítem (sin pesos ni
  ponderaciones).
- Los ítems ya ocupados aparecen deshabilitados en el selector de tareas
  futuras.
- Indicador visual en el ítem: chip "Vinculada a: [título de tarea]" con tap
  para navegar a la tarea.

### Notas (apuntes)
- Cada nota pertenece a una materia y tiene importancia.
- Opcionalmente se puede vincular a una tarea concreta.
- Pantalla de detalle con contenido completo, editar y eliminar.

### Polish
- **Splash screen** morado con logo durante el arranque de Firebase.
- **Caché offline** habilitado en mobile y web — crear/editar funciona sin
  conexión y sincroniza al volver.
- **Pull to refresh** en las listas.
- **SnackBars amigables** que traducen errores de Firebase a español natural.
- **Animaciones** sutiles de aparición en las listas (fade + slide).
- **Tema claro/oscuro automático** según el sistema (Material 3).

## Stack

- Flutter `^3.11.4` · Dart `3.11.4`
- `firebase_core ^3.0.0`, `firebase_auth ^5.0.0`, `cloud_firestore ^5.0.0`
- `table_calendar ^3.1.2`, `intl ^0.20.2`, `flutter_localizations`
- Material Design 3

## Estructura del código

```
lib/
├── firebase_options.dart       # generado por flutterfire (no editar)
├── main.dart                   # entry point: Firebase init + locales + tema
├── theme/
│   └── app_theme.dart          # paleta, íconos, ThemeData light/dark
├── models/
│   ├── subject.dart
│   ├── task_item.dart
│   ├── note.dart
│   └── grade_item.dart
├── services/
│   ├── auth_service.dart       # FirebaseAuth wrapper
│   └── firestore_service.dart  # CRUD bajo users/{uid}/... + cálculos auto
├── utils/
│   ├── error_messages.dart     # helper de SnackBars amigables
│   └── grade_calc.dart         # cálculo de nota efectiva de un grade item
├── widgets/                    # PriorityBadge, EmptyState, selectores, etc.
└── screens/
    ├── splash_screen.dart
    ├── auth/                   # AuthGate, Login, Register
    ├── main_screen.dart        # BottomNav 3 tabs + FAB expandible
    ├── tasks/                  # TasksScreen + DetalleTareaScreen
    ├── calendar/               # CalendarScreen
    ├── notes/                  # DetalleNotaScreen
    ├── grades/                 # GradesScreen + DetalleMateriaScreen
    └── forms/                  # CrearTarea, CrearNota, CrearGradeItem, CrearMateria
```

## Estructura en Firestore

Todos los documentos viven bajo `users/{uid}/...`:

| Colección | Campos |
|---|---|
| `subjects/{id}` | `nombre`, `color` (hex), `iconName`, `profesor?`, `aula?`, `classLinkUrl?`, `creadoEn` |
| `tasks/{id}` | `titulo`, `descripcion`, `subjectId`, `importancia`, `fechaLimite`, `completada`, `completadaEn?`, `gradeItemId?`, `nota?`, `creadoEn` |
| `notes/{id}` | `titulo`, `contenido`, `subjectId`, `importancia`, `taskId?`, `creadoEn` |
| `gradeItems/{id}` | `subjectId`, `nombre`, `porcentaje`, `nota?` (auto si tiene tarea vinculada), `creadoEn` |

## Reglas de seguridad de Firestore

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

## Cómo correr el proyecto

### Primera vez (después de clonar)

Los archivos de configuración de Firebase NO están en el repo por seguridad.
Hay que generarlos localmente:

```powershell
# 1. Instalar las CLIs (solo la primera vez)
npm install -g firebase-tools
flutter pub global activate flutterfire_cli

# 2. Autenticarse con Firebase
firebase login

# 3. Conectar este clon con el proyecto de Firebase
cd "ruta/al/proyecto/gestor_tareas"
flutterfire configure
# → elegir el proyecto "gestor-tareas-1f581"
# → marcar las plataformas (android, web)

# 4. Bajar dependencias
flutter pub get
```

Después de eso, `lib/firebase_options.dart` y
`android/app/google-services.json` aparecerán generados localmente. Como están
en `.gitignore`, no se subirán de vuelta al repo.

### En navegador (Chrome)

```powershell
flutter run -d chrome
```

### En Android (con dispositivo conectado por USB y depuración activada)

```powershell
flutter devices    # lista dispositivos disponibles
flutter run        # o: flutter run -d <device-id>
```

### Análisis estático

```powershell
flutter analyze
```

### Compilación release

```powershell
flutter build apk         # Android
flutter build web         # Web (genera build/web/)
```

## Setup de Firebase (ya hecho)

Este proyecto ya tiene `firebase_options.dart` generado vía
`flutterfire configure`. Si necesitas re-configurarlo para otro proyecto
Firebase:

```powershell
flutter pub global activate flutterfire_cli   # solo si no está instalado
flutterfire configure                          # interactivo
```

### Authentication

Email/Password debe estar habilitado en Firebase Console →
Authentication → Sign-in method.

## Convenciones

- **StreamBuilder** en todas las listas que leen de Firestore (tiempo real).
- **TextEditingController** + `GlobalKey<FormState>` en formularios.
- Colores de prioridad fijos: Alta `#E24B4A`, Media `#BA7517`, Baja `#3B6D11`.
- Acento principal: `#534AB7` (morado). ColorScheme generado desde ese seed.

## Roadmap pendiente

- Tareas recurrentes (semanal/diaria/mensual con fecha de fin).
- Filtros rápidos en lista de Tareas (Hoy / Esta semana / Vencidas).
- Indicador visual de vencida y "vence hoy".
- Swipe actions (deslizar para completar/borrar).
- Múltiples puntos por día en Calendario (uno por materia).
- Botón "Hoy" en AppBar del calendario.
- Notificaciones push de fechas límite.
- Adjuntos en notas (Firebase Storage).
