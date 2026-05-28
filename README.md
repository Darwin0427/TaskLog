# TaskLog

App Flutter para gestionar tareas, notas y calificaciones académicas con
Firebase (Authentication + Cloud Firestore). Diseñada para estudiantes:
organiza tu semestre por materias, registra tareas con prioridad y fechas
límite, lleva tus notas del curso y calcula automáticamente lo que necesitas
para aprobar.

## Integrantes

- Darwin Marin Giraldo
- Jean Paul Durango Márquez

---

## Cómo probar la aplicación

### 1. Instalar el APK

1. Descarga el archivo `TaskLog.apk` que viene con esta entrega (o compílalo
   desde el código fuente — ver "Compilar desde cero" más abajo).
2. Pasa el APK al celular Android (cable USB, correo, WhatsApp, Drive, lo
   que prefieras).
3. Ábrelo desde el explorador de archivos del celular.
4. Cuando Android pida permiso para "instalar de fuentes desconocidas",
   acéptalo.
5. Confirma la instalación. La app aparece como **TaskLog** en el menú de
   aplicaciones.

**Si el celular es Xiaomi/MIUI** puede salir un aviso adicional tipo "esta
app no fue verificada por MIUI" o pedir una pausa de seguridad de unos
segundos. Es normal con cualquier APK que no venga de Play Store; se puede
continuar sin problema.

**Requisitos mínimos:**

- Android 7.0 o superior.
- ~25 MB libres.
- Conexión a internet la primera vez. Después la app funciona offline y
  sincroniza al volver la conexión.

### 2. Crear cuenta

Al abrir la app por primera vez aparece la pantalla de login.

1. Toca "Crear cuenta".
2. Ingresa un correo electrónico.
3. Define una contraseña (mínimo 6 caracteres).
4. Confirma.

Cada cuenta tiene su propio espacio aislado en Firestore, así que puedes
registrarte con cualquier correo sin afectar datos de nadie más. Las
credenciales se manejan con Firebase Authentication.

### 3. Iniciar sesión

La sesión queda activa entre aperturas de la app. Solo te toca volver a
entrar si cerraste sesión explícitamente (el botón está en la esquina
superior derecha del tab Calificaciones).

---

## Funcionalidades disponibles

A continuación están **todas** las funciones implementadas, agrupadas por
área. Esta es la lista de verificación: todo lo que aparezca aquí debería
funcionar como se describe.

### Autenticación

- Registrar cuenta con email y contraseña.
- Iniciar sesión con email y contraseña.
- Cerrar sesión (botón en AppBar de Calificaciones).
- Mantener sesión activa entre cierres de app.
- Redirección automática al login si no hay sesión, y a la app si la hay.
- Mensajes de error traducidos al español (correo inválido, contraseña
  débil, demasiados intentos, sin red, etc.).

### Navegación principal

- 3 tabs en la barra inferior: **Tareas**, **Calendario**, **Calificaciones**.
- Cambio instantáneo entre tabs preservando el estado de cada uno.
- Botón flotante (FAB) expandible con dos acciones rápidas: **Nueva tarea**
  y **Nueva nota**.
- Animaciones del FAB al abrir/cerrar (rotación 45°, aparición desde abajo).
- Fondo oscurecido al abrir el FAB; tap fuera para cerrarlo.

### Materias

- Crear materia con nombre, color (paleta) e ícono (paleta).
- Campos opcionales: profesor, aula/salón, link de clase virtual.
- Editar todos los campos.
- Eliminar materia (con confirmación y **bloqueo si tiene tareas, notas o
  ítems evaluativos asociados** — te dice cuántos).
- Listado en pantalla Calificaciones mostrando promedio, % evaluado y
  conteo de ítems.

### Tareas

- Crear tarea con título, descripción, materia, importancia
  (Alta / Media / Baja) y fecha límite (selector de fecha).
- Editar todos los campos.
- Eliminar tarea (con confirmación).
- Marcar como completada/pendiente con un toque en el checkbox circular.
- Vista agrupada por prioridad (Alta → Media → Baja), ordenadas por fecha
  límite dentro de cada grupo.
- Sección "Completadas" colapsable al final.
- Tachado y opacidad reducida cuando está completada.
- Badge de prioridad con color (rojo / naranja / verde).
- Badge de materia con su color asignado.
- Tap en la tarjeta → pantalla de detalle.
- Mensaje "¡Todas las tareas completadas!" cuando no hay pendientes.

### Detalle de tarea

- Ver título, descripción, materia, prioridad, fecha límite, estado.
- Ver notas (apuntes) asociadas a esa tarea.
- Botón para crear nueva nota directamente vinculada a la tarea.
- Botón editar (abre el formulario con los campos pre-llenados).
- Botón eliminar (con confirmación).
- Si está vinculada a un ítem evaluativo, ver cuál y su calificación.

### Calendario

- Vista en tres formatos intercambiables: **Mes**, **2 semanas**, **Semana**.
- Selector de día tocando cualquier fecha.
- Indicador (punto de color) en días con tareas, usando el color de la
  materia.
- Filtro por materia (chips horizontales con "Todas" + cada materia).
- Botón "Filtrar" para mostrar/ocultar los chips.
- Lista de tareas del día seleccionado debajo del calendario.
- Tap en una tarea del listado → pantalla de detalle.
- Localización en español (días de la semana, meses).
- Hoy resaltado con halo morado claro, día seleccionado en morado fuerte.

### Calificaciones

- Lista de materias con tarjeta por cada una mostrando:
  - Ícono y color de la materia.
  - Promedio actual sobre 5.0.
  - Barra de progreso del % evaluado.
  - Conteo de ítems evaluativos.
- Tap en materia → pantalla de detalle.

### Detalle de materia

- Header con información extra (profesor, aula, link de clase virtual si
  están).
- Cálculo de **Acumulado** (suma ponderada de notas obtenidas).
- Cálculo de **Promedio actual**.
- 3 sub-tabs:
  - **Notas** (apuntes de la materia).
  - **Tareas** (tareas de la materia).
  - **Notas del curso** (ítems evaluativos).
- Editar/eliminar la materia desde el AppBar.

### Ítems evaluativos (notas del curso)

- Crear ítem con nombre y porcentaje del curso (% que vale dentro de la
  materia).
- **Validación**: la suma de porcentajes no puede superar 100% (te bloquea
  con mensaje claro).
- Asignar nota manualmente en un diálogo compacto (escala 0-5).
- Editar nombre/porcentaje.
- Eliminar ítem (con confirmación).
- Si está vinculado a una tarea, la nota se hereda automáticamente y no se
  puede editar manual (te lo dice con un mensaje).

### Calculadora "¿Qué nota necesito?"

- Tarjeta expandible dentro del detalle de materia.
- Slider para escoger nota objetivo (entre 3.0 y 5.0).
- Cálculo automático del promedio necesario en los ítems pendientes para
  llegar al objetivo.
- Maneja los casos "ya superaste el objetivo" y "ya no puedes llegar" con
  mensajes específicos.

### Vinculación tarea ↔ calificación

- Al crear/editar una tarea, opcionalmente vincularla a un ítem evaluativo
  de su materia.
- La nota de la tarea se convierte automáticamente en la nota del ítem.
- Selector tipo chips que **deshabilita los ítems ya ocupados** por otra
  tarea.
- En el detalle del ítem evaluativo, chip "Vinculada a: [título de tarea]"
  con tap para navegar a la tarea.
- Al cambiar el vínculo, recálculo automático del ítem viejo y el nuevo.
- Al eliminar o desvincular la tarea, el ítem queda sin nota.

### Notas (apuntes)

- Crear nota con título, contenido (texto largo), materia e importancia.
- Opcionalmente vincular la nota a una tarea.
- Editar todos los campos.
- Eliminar nota (con confirmación).
- Pantalla de detalle con contenido completo.
- Aparecen en el sub-tab "Notas" del detalle de materia.
- Aparecen también en el detalle de cada tarea si están vinculadas.

### Sincronización y offline

- Caché local habilitado en mobile y web.
- Crear/editar/eliminar funciona **sin conexión** — los cambios se
  sincronizan al recuperar internet.
- Todas las listas se actualizan en **tiempo real** vía StreamBuilder (los
  cambios desde otro dispositivo se reflejan al instante).
- Gesto "pull to refresh" en las listas para forzar reconexión al servidor.

### Polish y UX

- Splash screen morado con logo durante el arranque de Firebase.
- Paleta consistente: morado `#534AB7` como acento principal (Material Design 3).
- Colores fijos de prioridad: rojo (Alta), naranja (Media), verde (Baja).
- SnackBars amigables al guardar (verde) o fallar (rojo, con mensaje
  traducido al español).
- Loading spinners (`CircularProgressIndicator`) mientras cargan datos.
- Pantallas vacías con ícono, título y subtítulo guía cuando no hay datos.
- Animaciones de aparición (fade + slide) en items de listas.
- Validación de formularios (campos requeridos, formatos numéricos).
- Confirmaciones antes de cualquier acción destructiva.

---

## Guía rápida de prueba

Si quieres recorrer toda la app en una sola sesión y verificar que todo
funcione, este es el camino recomendado. Cada paso depende de los
anteriores.

1. **Crea tu primera materia** desde el tab Calificaciones. Ponle nombre,
   color, ícono y, si quieres, profesor / aula / link de clase virtual.
2. **Crea unas cuantas tareas** desde el botón "+" flotante. Mezcla
   prioridades (Alta, Media, Baja) para ver el agrupamiento. Marca una como
   completada para ver la sección colapsable al final.
3. **Crea una nota (apunte)** y vincúlala a una tarea. Verifica que aparece
   en el detalle de esa tarea.
4. **Crea ítems evaluativos** en la materia (por ejemplo: Parcial 1 30%,
   Taller 20%, Final 50%). Intenta crear uno que haga que la suma pase del
   100% para ver la validación bloqueando la operación.
5. **Asigna notas** a los ítems tocándolos. Mira cómo se actualizan el
   promedio y la barra de % evaluado en la tarjeta de la materia.
6. **Vincula una tarea a un ítem evaluativo** desde el formulario de la
   tarea. La nota de la tarea pasa al ítem automáticamente. Crea otra tarea
   y nota que ese ítem ya aparece deshabilitado en el selector.
7. **Usa la calculadora "¿Qué nota necesito?"** dentro del detalle de la
   materia. Mueve el slider de objetivo para ver el cálculo en vivo.
8. **Ve al Calendario** y cambia entre Mes / Semana / Día. Filtra por
   materia. Toca un día para ver sus tareas.

### Cosas extra que vale la pena verificar

- **Modo offline**: activa modo avión, crea o edita cosas, desactiva el modo
  avión y observa cómo se sincroniza solo.
- **Tiempo real**: si instalas la app en dos dispositivos con la misma
  cuenta, verás los cambios aparecer al instante en el otro.
- **Pull to refresh**: arrastra hacia abajo desde la parte superior de
  cualquier lista.
- **Errores amigables**: intenta registrarte con un correo inválido, una
  contraseña corta, o entrar con datos errados — los mensajes salen en
  español claro, no códigos técnicos.

---

## Lo que NO está en esta entrega

Para que quede claro qué se incluye y qué no:

- **Notificaciones / recordatorios por tarea** — planificada como feature
  destacada con el plan completo en
  [`NOTIFICATIONS_PLAN.md`](./NOTIFICATIONS_PLAN.md), pero no implementada
  en esta entrega.
- **Tareas recurrentes** (semanal / diaria / mensual con fecha de fin).
- **Filtros rápidos en Tareas** (Hoy / Esta semana / Vencidas).
- **Indicador visual** de tareas vencidas o que vencen hoy.
- **Swipe actions** en tareas (deslizar para completar o borrar).
- **Múltiples puntos** por día en el calendario (uno por materia).
- **Botón "Hoy"** en el AppBar del calendario.
- **Pantalla "Gestionar cuenta"** (perfil, preferencias, eliminar cuenta).
- **Adjuntos en notas** (Firebase Storage).
- **Recuperación de contraseña** por correo.
- **Sign in con Google**.

Estas funcionalidades forman el roadmap del proyecto. Están listadas para
ser transparentes sobre el alcance actual.

---

## Stack técnico

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

---

## Compilar desde cero

Si en lugar de usar el APK ya construido prefieres compilar el proyecto:

### Primera vez (después de clonar el repo)

Los archivos de configuración de Firebase NO están en el repo por
seguridad. Hay que generarlos localmente:

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
`android/app/google-services.json` aparecen generados localmente. Están en
`.gitignore`, así que no se suben de vuelta al repo.

### Correr en navegador (Chrome)

```powershell
flutter run -d chrome
```

### Correr en Android (con dispositivo conectado por USB y depuración activada)

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
flutter build apk --release --split-per-abi    # genera APKs (uno por ABI)
flutter build appbundle --release              # bundle para Play Store
flutter build web                              # build para web
```

### Authentication

Email/Password debe estar habilitado en Firebase Console →
Authentication → Sign-in method (ya configurado en este proyecto).

---

## Convenciones

- **StreamBuilder** en todas las listas que leen de Firestore (tiempo real).
- **TextEditingController** + `GlobalKey<FormState>` en formularios.
- Colores de prioridad fijos: Alta `#E24B4A`, Media `#BA7517`, Baja `#3B6D11`.
- Acento principal: `#534AB7` (morado). ColorScheme generado desde ese seed.

---

## Contacto

- **Darwin Marin Giraldo** — darwin.marin906@pascualbravo.edu.co
- **Jean Paul Durango Márquez** — jean.durango753@pascualbravo.edu.co

Repositorio: https://github.com/Darwin427/gestor_tareas
