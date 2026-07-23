#!/bin/bash
#
# resign-and-relaunch.sh
#
# Recompila CopyPasteMemory y la vuelve a lanzar. Esto renueva la firma de
# desarrollo gratuita (que caduca a los 7 días sin cuenta de pago de Apple
# Developer Program) antes de que deje de funcionar. Pensado para ejecutarse
# solo, cada pocos días, vía un LaunchAgent (ver
# ~/Library/LaunchAgents/com.acl.copypastememory.resign.plist).
#
# Nota sobre el LaunchAgent (~/Library/LaunchAgents/com.acl.copypastememory.resign.plist):
# ese archivo SÍ tiene que vivir fuera del repo, en esa carpeta exacta —
# es una exigencia de macOS, launchd solo lee LaunchAgents desde ahí. Además,
# al ser XML no admite variables como $HOME, así que lleva la ruta absoluta
# de este Mac escrita a mano. Si otra persona clona este repo y quiere
# reutilizar esta automatización, tendrá que crear su propio .plist con su
# propia ruta absoluta apuntando a este script (que él sí puede reutilizar
# tal cual, porque usa $HOME más abajo, no una ruta fija).

set -euo pipefail

PROJECT_DIR="$HOME/Proyectos/CopyPasteMemory"
SCHEME="CopyPasteMemory"
LOG_FILE="$HOME/Library/Logs/CopyPasteMemory-resign.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "Iniciando recompilación..."

cd "$PROJECT_DIR"

if ! xcodebuild -project CopyPasteMemory.xcodeproj -scheme "$SCHEME" -configuration Debug build >> "$LOG_FILE" 2>&1; then
    log "ERROR: xcodebuild ha fallado. Revisa el log para más detalle."
    exit 1
fi

# Preguntamos a xcodebuild dónde ha dejado el .app compilado, en vez de
# adivinar la ruta a mano (esa carpeta de DerivedData incluye un hash que
# puede cambiar).
BUILT_PRODUCTS_DIR=$(xcodebuild -project CopyPasteMemory.xcodeproj -scheme "$SCHEME" -configuration Debug -showBuildSettings 2>/dev/null | awk -F'= ' '/ BUILT_PRODUCTS_DIR / {print $2; exit}')
APP_PATH="$BUILT_PRODUCTS_DIR/CopyPasteMemory.app"

if [ ! -d "$APP_PATH" ]; then
    log "ERROR: no se encontró el .app compilado en $APP_PATH"
    exit 1
fi

# Cerramos la instancia en marcha (si la hay) antes de abrir la recién firmada
osascript -e 'quit app "CopyPasteMemory"' 2>/dev/null || true
sleep 1

open "$APP_PATH"

log "Recompilado y relanzado correctamente desde $APP_PATH"
