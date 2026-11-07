# TaskLog en iPhone (sin Mac y sin pagar)

Flujo: desarrollas en Windows como siempre → GitHub compila la versión de
iPhone en una Mac en la nube → instalas el `.ipa` en tu iPhone con
Sideloadly.

Esto se configura **una sola vez** (pasos 1 a 3). Después, cada versión
nueva es solo el paso 4 y el paso 5.

> **Bundle ID de iOS:** `com.darwinmarin.tasklog`
> (Android sigue con `com.example.gestor_tareas`, no se tocó).

---

## 1. Registrar la app de iOS en Firebase

En la terminal de Windows, dentro de la carpeta del proyecto:

```powershell
flutterfire configure --platforms=android,ios,web --ios-bundle-id=com.darwinmarin.tasklog
```

- Elige el proyecto `gestor-tareas-1f581`.
- Deja marcado **android** (si no, se pierde la config de Android).
- Esto crea la app de iOS en Firebase y actualiza `lib/firebase_options.dart`
  agregando una sección `static const FirebaseOptions ios = ...`.

Si `flutterfire` muestra un error sobre Xcode o Ruby en la parte de iOS, no
pasa nada mientras `lib/firebase_options.dart` haya quedado con la sección
`ios`. Revísalo abriendo el archivo.

**Si no aparece la sección `ios`**, hazlo a mano:

1. Firebase Console → proyecto → ⚙️ Configuración del proyecto → *Agregar
   app* → iOS. ID del paquete: `com.darwinmarin.tasklog`. Registra y
   descarga `GoogleService-Info.plist`.
2. Abre ese `.plist` con el Bloc de notas y copia los valores a
   `lib/firebase_options.dart`:

```dart
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: '...',            // API_KEY
    appId: '...',             // GOOGLE_APP_ID
    messagingSenderId: '...', // GCM_SENDER_ID
    projectId: 'gestor-tareas-1f581',
    storageBucket: '...',     // STORAGE_BUCKET
    iosBundleId: 'com.darwinmarin.tasklog',
  );
```

   Y en el `switch` de `currentPlatform`, que `TargetPlatform.iOS` devuelva
   `ios` en vez de lanzar `UnsupportedError`.

La app de Android sigue funcionando igual con ese archivo.

## 2. Guardar la configuración de Firebase como secret en GitHub

`firebase_options.dart` no se sube al repo (está en `.gitignore`), así que
la Mac de GitHub no lo tiene. Se lo pasamos como *secret*:

1. GitHub → repo `gestor_tareas` → **Settings** → **Secrets and variables**
   → **Actions** → **New repository secret**.
2. Name: `FIREBASE_OPTIONS_DART`
3. Secret: pega **todo** el contenido de `lib/firebase_options.dart`.
4. *Add secret*.

Opcional: si tienes `ios/Runner/GoogleService-Info.plist`, crea otro secret
`GOOGLE_SERVICE_INFO_PLIST` con su contenido. No es necesario para que la
app funcione.

Cada vez que vuelvas a correr `flutterfire configure`, actualiza este secret.

## 3. Preparar Windows y el iPhone

En el PC:

- Instala **Sideloadly**: <https://sideloadly.io>
- Sideloadly necesita **iTunes** e **iCloud** descargados de la web de
  Apple (no las versiones de Microsoft Store).

En el iPhone:

- **Ajustes → Privacidad y seguridad → Modo de desarrollador** → activar
  (el iPhone se reinicia). Si no aparece la opción, aparece después del
  primer intento de instalación.

## 4. Compilar la versión de iPhone

Cualquiera de las dos:

- Haz push a la rama `ios`, o
- GitHub → pestaña **Actions** → **Compilar iOS** → **Run workflow**.

Tarda unos 10-20 minutos. Al terminar, entra a la ejecución (círculo
verde ✅) y abajo, en **Artifacts**, descarga **TaskLog-ipa**. Es un `.zip`;
descomprímelo y queda `TaskLog.ipa`.

Si sale ❌ rojo, abre el paso que falló y mira el mensaje. Los más comunes
están en "Problemas frecuentes".

## 5. Instalar en el iPhone

1. Conecta el iPhone al PC por cable y desbloquéalo. Si pregunta, toca
   **Confiar en este computador**.
2. Abre Sideloadly y arrastra `TaskLog.ipa` a la ventana.
3. En *Apple account* pon tu Apple ID y dale **Start**. Te pedirá la
   contraseña (y el código de verificación la primera vez).
4. En el iPhone: **Ajustes → General → VPN y gestión de dispositivos** → tu
   Apple ID → **Confiar**.
5. Abre TaskLog. La primera vez pide permiso para notificaciones: acéptalo.

### Cada 7 días

Con una cuenta gratis de Apple, la app deja de abrir a los 7 días. Repite el
paso 5 con el mismo `.ipa` (o uno nuevo). Tus datos están en Firestore, no
se pierden. Los recordatorios se reprograman solos al abrir la app.

En Sideloadly puedes activar el **auto-refresh**: renueva la app solo cuando
el iPhone y el PC están en la misma Wi-Fi.

Límites de la cuenta gratis: máximo 3 apps instaladas así a la vez y 10 App
IDs nuevos por semana.

---

## Qué cambió en el código para iOS

- `ios/Podfile`: creado, con los ajustes que pide `awesome_notifications`.
- iOS mínimo: **15.0**.
- Nombre en el iPhone: **TaskLog**. Ícono generado desde
  `LogoTaskLog.jpeg` durante la compilación.
- **Límite de 64 notificaciones de iOS:** la app ya no programa todos los
  recordatorios de golpe. Programa solo los 60 más próximos (400 en Android)
  y vuelve a calcular al abrir la app y cada vez que creas, editas,
  completas o borras una tarea. Lógica en
  `lib/utils/recordatorios_scheduler.dart`, con pruebas en
  `test/recordatorios_scheduler_test.dart`.
- Al **cerrar sesión** se borran los recordatorios programados, para que
  otra cuenta en el mismo teléfono no reciba avisos ajenos.
- El onboarding de Xiaomi/Huawei solo corre en Android. En iPhone solo se
  pide el permiso de notificaciones.

## Problemas frecuentes

| Mensaje | Qué hacer |
|---|---|
| `Falta el secret FIREBASE_OPTIONS_DART` | Paso 2. |
| `firebase_options.dart no tiene la configuración de iOS` | Paso 1: falta la sección `ios`. Después actualiza el secret. |
| Error en `pod install` / CocoaPods | Copia el error completo y revísalo. Suele ser una versión de iOS mínima de algún paquete. |
| La app se instala pero se cierra al abrir | Falta confiar en el perfil (paso 5.4) o el Modo de desarrollador. |
| La app abre en el splash con "No se pudo iniciar" | La config de Firebase iOS está mal (paso 1). |
| Sideloadly: "Maximum number of apps" | Ya tienes 3 apps instaladas con cuenta gratis. Borra una. |
