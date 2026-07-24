# CopyPasteMemory

A free, native macOS clipboard history manager — the Cmd+Option+V equivalent of Windows' Win+V.

🇬🇧 [English](#english) · 🇪🇸 [Español](#español)

---

## English

**CopyPasteMemory** is a lightweight menu bar app for macOS that keeps a history of your last 25 copied items (text and images) and lets you bring any of them back with a global shortcut — no paid subscription, unlike most clipboard managers on the Mac App Store.

### Features

- Lives entirely in the menu bar — no Dock icon, no big window.
- Keeps your last **25** copied items (text and images).
- Global shortcut **⌘⌥V** opens the history panel from anywhere, even over fullscreen apps.
- Navigate with the arrow keys + Enter, or click an item, to copy it back to the clipboard — then just press **⌘V** to paste it, like normal.
- **Pin** items you want to keep even after restarting your Mac (📌 icon on each row):
  - Pinned text is stored encrypted in the macOS Keychain.
  - Pinned images are stored locally inside the app's own sandboxed folder.
  - Items over 100 KB (text) / 5 MB (image) can't be pinned — you'll get a clear warning instead of a silent failure.
- Skips anything marked "concealed" by password managers (e.g. 1Password) — those never enter the history.
- Optional **"Open at Login"** toggle.
- Fully localized: **Spanish, English, German, French, Italian**.
- Runs sandboxed, with no Accessibility permission and no network access required.

### Requirements

- macOS with Xcode 16 or newer installed (the project uses Xcode's modern file-system-synchronized groups and String Catalogs).
- A free Apple ID is enough to build and run it locally — **no paid Apple Developer Program membership needed**. The only downside of the free tier is that a build stops working after 7 days. This repo includes `Scripts/resign-and-relaunch.sh`, which — combined with a local `launchd` job (see step 6 below) — **re-signs and relaunches the app on its own every 6 days**, so once set up you never have to think about it again.

### Build & run

1. Clone the repo:
   ```bash
   git clone https://github.com/AdrianCardin/CopyPasteMemory.git
   ```
2. Open `CopyPasteMemory.xcodeproj` in Xcode.
3. Select your own signing team: click the **CopyPasteMemory** target → **Signing & Capabilities** → set **Team** to your own Apple ID (the repo ships with the original author's team, which won't work on your machine).
4. Press **⌘R** to build and run.
5. The first time you copy something or pin a text item, macOS may ask for Keychain access — click **Allow Always**.
6. *(Optional but recommended)* Set up the self-renewing signature so you never hit the 7-day expiration:
   - Create a LaunchAgent (e.g. `~/Library/LaunchAgents/com.yourname.copypastememory.resign.plist`) pointing to `Scripts/resign-and-relaunch.sh` inside your local clone, running on a `StartInterval` of a few days. The script itself uses `$HOME`, so it works as-is — only the `.plist` needs your own absolute path, since `launchd` doesn't support `$HOME` there.
   - Load it with `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.yourname.copypastememory.resign.plist`.

### Updating

There's no auto-update yet — since you built it from source, updating means pulling the latest code and rebuilding:

```bash
cd CopyPasteMemory
git pull
```

Then reopen the project in Xcode (or let it reload automatically if it was already open) and press **⌘R** again.

### Usage

| Action | Result |
|---|---|
| ⌘C (anywhere, as always) | Copies normally — CopyPasteMemory just watches silently in the background |
| ⌘⌥V | Opens the history panel |
| Click a row / Enter | Restores that item to the clipboard, closes the panel — press ⌘V to paste it |
| 📌 icon on a row | Pins/unpins that item so it survives a restart |
| Menu bar icon | Show History, Clear History, Open at Login, Quit |

### Privacy & data

- The history lives **only in memory** by default — closing the app clears it, except for pinned items.
- Pinned **text** goes to the macOS Keychain, marked "this device only" (never synced via iCloud Keychain).
- Pinned **images** are saved as local files inside the app's private sandbox container — nowhere else on disk.
- Content marked as "concealed"/"transient" by other apps (the convention used by password managers) is never recorded.

### Roadmap

- **Permanent signing.** Right now the app is signed with a free Apple ID, so a local build would stop working after 7 days — but a local `launchd` job (see `Scripts/resign-and-relaunch.sh`) already re-signs and relaunches it automatically in the background, so in practice it never stops working. Getting a paid Apple Developer Program membership is planned for later — that would allow a properly signed, notarized `.app` release that anyone could just download and run, no Xcode, self-renewing script, or Apple ID needed.

### License

[MIT](LICENSE) — do whatever you'd like with it.

---

## Español

**CopyPasteMemory** es una app ligera de barra de menú para macOS que guarda un historial de tus últimos 25 elementos copiados (texto e imágenes) y te deja recuperar cualquiera de ellos con un atajo global — sin suscripción de pago, a diferencia de la mayoría de gestores de portapapeles de la Mac App Store.

### Funcionalidades

- Vive solo en la barra de menú — sin icono en el Dock, sin ventana grande.
- Guarda tus últimos **25** elementos copiados (texto e imágenes).
- Atajo global **⌘⌥V** para abrir el panel del historial desde cualquier sitio, incluso sobre apps a pantalla completa.
- Navega con las flechas + Enter, o haz clic en un elemento, para copiarlo de nuevo al portapapeles — luego solo pulsa **⌘V** para pegarlo, como siempre.
- **Pinea** los elementos que quieras conservar aunque reinicies el Mac (icono 📌 en cada fila):
  - El texto pineado se guarda cifrado en el Llavero de macOS.
  - Las imágenes pineadas se guardan en local, dentro de la carpeta privada de la propia app.
  - Los elementos de más de 100 KB (texto) / 5 MB (imagen) no se pueden pinear — te avisa con un mensaje claro en vez de fallar en silencio.
- Ignora todo lo marcado como "oculto" por gestores de contraseñas (ej. 1Password) — eso nunca entra en el historial.
- Interruptor opcional de **"Abrir al iniciar sesión"**.
- Totalmente traducida a **español, inglés, alemán, francés e italiano**.
- Funciona con sandbox activado, sin necesitar permiso de Accesibilidad ni acceso a red.

### Requisitos

- macOS con Xcode 16 o superior instalado (el proyecto usa las carpetas sincronizadas con el sistema de archivos y los catálogos de cadenas modernos de Xcode).
- Con un Apple ID gratuito es suficiente para compilarlo y ejecutarlo en tu Mac — **no hace falta pagar la cuenta de Apple Developer Program**. El único inconveniente del plan gratuito es que el build deja de funcionar a los 7 días. Este repositorio incluye `Scripts/resign-and-relaunch.sh`, que — combinado con un job de `launchd` local (ver paso 6 más abajo) — **se refirma y se relanza solo cada 6 días**, así que una vez configurado no tienes que volver a pensar en ello.

### Compilar y ejecutar

1. Clona el repositorio:
   ```bash
   git clone https://github.com/AdrianCardin/CopyPasteMemory.git
   ```
2. Abre `CopyPasteMemory.xcodeproj` en Xcode.
3. Elige tu propio equipo de firma: en el target **CopyPasteMemory** → **Signing & Capabilities** → cambia **Team** a tu propio Apple ID (el repositorio trae configurado el equipo del autor original, que no te va a funcionar a ti).
4. Pulsa **⌘R** para compilar y ejecutar.
5. La primera vez que copies algo o pinees un texto, macOS puede pedirte acceso al Llavero — dale a **Permitir siempre**.
6. *(Opcional pero recomendado)* Configura el refirmado automático para no toparte nunca con la caducidad de 7 días:
   - Crea un LaunchAgent (ej. `~/Library/LaunchAgents/com.tunombre.copypastememory.resign.plist`) que apunte a `Scripts/resign-and-relaunch.sh` dentro de tu copia local, con un `StartInterval` de pocos días. El script ya usa `$HOME`, así que funciona tal cual — solo el `.plist` necesita tu propia ruta absoluta, porque `launchd` no admite `$HOME` ahí.
   - Cárgalo con `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.tunombre.copypastememory.resign.plist`.

### Actualizar

Todavía no hay actualización automática — como lo compilaste desde el código fuente, actualizar significa traer los cambios nuevos y volver a compilar:

```bash
cd CopyPasteMemory
git pull
```

Luego vuelve a abrir el proyecto en Xcode (o deja que se recargue solo si ya lo tenías abierto) y pulsa **⌘R** otra vez.

### Uso

| Acción | Resultado |
|---|---|
| ⌘C (en cualquier sitio, como siempre) | Copia con normalidad — CopyPasteMemory solo observa en segundo plano |
| ⌘⌥V | Abre el panel del historial |
| Clic en una fila / Enter | Restaura ese elemento al portapapeles y cierra el panel — pulsa ⌘V para pegarlo |
| Icono 📌 de una fila | Pinea/despinea ese elemento para que sobreviva a un reinicio |
| Icono de la barra de menú | Mostrar historial, Vaciar historial, Abrir al iniciar sesión, Salir |

### Privacidad y datos

- El historial vive **solo en memoria** por defecto — al cerrar la app se pierde, salvo los elementos pineados.
- El **texto** pineado va al Llavero de macOS, marcado "solo este dispositivo" (nunca se sincroniza por iCloud Keychain).
- Las **imágenes** pineadas se guardan como archivos locales dentro de la carpeta privada de la app — en ningún otro sitio del disco.
- El contenido marcado como "oculto"/"transitorio" por otras apps (la convención que usan los gestores de contraseñas) nunca se registra.

### Próximos pasos

- **Firma permanente.** Ahora mismo la app está firmada con un Apple ID gratuito, así que un build local dejaría de funcionar a los 7 días — pero un job de `launchd` local (ver `Scripts/resign-and-relaunch.sh`) ya la refirma y relanza solo en segundo plano, así que en la práctica nunca deja de funcionar. Está pendiente pasar a la cuenta de pago de Apple Developer Program más adelante — eso permitiría publicar un `.app` firmado y notarizado que cualquiera pudiera simplemente descargar y abrir, sin necesitar Xcode, script de auto-refirmado ni Apple ID propio.

### Licencia

[MIT](LICENSE) — úsalo como quieras.
