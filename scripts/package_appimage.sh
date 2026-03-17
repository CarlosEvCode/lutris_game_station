#!/bin/bash
set -e

# Variable crítica para que funcione dentro de Docker/CI sin FUSE
export APPIMAGE_EXTRACT_AND_RUN=1

# Colores para la terminal
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Configuración básica (SINCRONIZADA CON EL CÓDIGO C++)
APP_NAME="lutris_game_station"
# Este ID DEBE coincidir con el del main.cc
APP_ID="com.lutris_game_station.app"
VERSION=${1:-"unknown"}
BUNDLE_DIR="build/linux/x64/release/bundle"

echo -e "${BLUE}📦 Generando AppImage para $APP_NAME version $VERSION...${NC}"

# 1. Validar herramientas locales
if [ ! -f /.dockerenv ]; then
    for tool in patchelf convert; do
        if ! command -v $tool &> /dev/null; then
            echo -e "${RED}❌ Error: '$tool' no está instalado.${NC}"
            exit 1
        fi
    done
fi

# 2. Descargar herramientas de AppImage
[ ! -f linuxdeploy-x86_64.AppImage ] && curl -L -o linuxdeploy-x86_64.AppImage https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
[ ! -f linuxdeploy-plugin-gtk.sh ] && curl -L -o linuxdeploy-plugin-gtk.sh https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh
[ ! -f appimagetool-x86_64.AppImage ] && curl -L -o appimagetool-x86_64.AppImage https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
[ ! -f runtime-x86_64 ] && curl -L -o runtime-x86_64 https://github.com/AppImage/AppImageKit/releases/download/continuous/runtime-x86_64
chmod +x *.AppImage *.sh

# 3. Estructura AppDir
rm -rf AppDir && mkdir -p AppDir/usr/bin AppDir/usr/lib AppDir/usr/share/applications AppDir/usr/share/icons/hicolor/512x512/apps

# 4. Copiar bundle de Flutter
cp -r $BUNDLE_DIR/* AppDir/usr/bin/

# 5. SQLITE: Inyectar en lib/
SQLITE_LIB="/usr/lib/x86_64-linux-gnu/libsqlite3.so.0"
if [ -f "$SQLITE_LIB" ]; then
    mkdir -p AppDir/usr/bin/lib
    cp -v "$SQLITE_LIB" AppDir/usr/bin/lib/libsqlite3.so.0
    ln -sf libsqlite3.so.0 AppDir/usr/bin/lib/libsqlite3.so
fi

# 6. Fijar RPATH
BINARY="AppDir/usr/bin/$APP_NAME"
patchelf --set-rpath '$ORIGIN/lib' "$BINARY"

# 7. Desktop e Icono (USANDO EL APP_ID CORRECTO)
DESKTOP_FILE="AppDir/usr/share/applications/$APP_ID.desktop"
cp "linux/$APP_NAME.desktop" "$DESKTOP_FILE"

# Forzamos el ID correcto en el archivo desktop
sed -i "s/^Icon=.*/Icon=$APP_ID/" "$DESKTOP_FILE"
if ! grep -q "StartupWMClass" "$DESKTOP_FILE"; then
    echo "StartupWMClass=$APP_ID" >> "$DESKTOP_FILE"
fi

if [ -f "linux/$APP_NAME.png" ]; then
    echo -e "${BLUE}🎨 Procesando icono con ID: $APP_ID...${NC}"
    convert "linux/$APP_NAME.png" -resize 512x512! "AppDir/usr/share/icons/hicolor/512x512/apps/$APP_ID.png"
    mkdir -p AppDir/usr/share/pixmaps
    cp "AppDir/usr/share/icons/hicolor/512x512/apps/$APP_ID.png" "AppDir/usr/share/pixmaps/$APP_ID.png"
    cp "AppDir/usr/share/icons/hicolor/512x512/apps/$APP_ID.png" "AppDir/$APP_ID.png"
fi

# 8. Plugin GTK
mkdir -p ./plugins
cp linuxdeploy-plugin-gtk.sh ./plugins/linuxdeploy-plugin-gtk
export PATH=$PATH:$(pwd)/plugins
export LD_LIBRARY_PATH=$(pwd)/AppDir/usr/bin/lib:$LD_LIBRARY_PATH

# SOLUCIÓN AL ERROR DE AUTO-DETECCIÓN: Forzamos GTK 3 (que es la que usa Flutter)
export DEPLOY_GTK_VERSION=3

./linuxdeploy-x86_64.AppImage --appdir AppDir \
    --executable "$BINARY" \
    --desktop-file "$DESKTOP_FILE" \
    --icon-file "AppDir/usr/share/icons/hicolor/512x512/apps/$APP_ID.png" \
    --plugin gtk

# 9. Limpieza
find AppDir/usr/lib -name "libselinux*" -delete || true
find AppDir/usr/lib -name "libdbus*" -delete || true

# 10. AppRun Personalizado
cat > AppDir/AppRun <<'APP_RUN'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/usr/bin/lib:$HERE/usr/lib:$LD_LIBRARY_PATH"

# Detección de Tema de Cursor e Iconos
HOST_CURSOR_THEME=$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d "'")
export XCURSOR_THEME="${HOST_CURSOR_THEME:-Adwaita}"
export XCURSOR_PATH="~/.icons:~/.local/share/icons:/usr/share/icons:/usr/share/pixmaps:$HERE/usr/share/icons"

# Prioridad a las carpetas del AppImage para que encuentre su propio icono por nombre
export XDG_DATA_DIRS="$HERE/usr/share:$XDG_DATA_DIRS:/usr/share:/usr/local/share"

export GTK_CSD=0
export GTK_OVERLAY_SCROLLING=1
export GDK_BACKEND=x11

exec "$HERE/usr/bin/lutris_game_station" "$@"
APP_RUN
chmod +x AppDir/AppRun

# 11. Generar el AppImage final
export ARCH=x86_64
./appimagetool-x86_64.AppImage --runtime-file runtime-x86_64 AppDir "${APP_NAME}-${VERSION}-x86_64.AppImage"

echo -e "${BLUE}✅ AppImage profesional generado: ${APP_NAME}-${VERSION}-x86_64.AppImage${NC}"
