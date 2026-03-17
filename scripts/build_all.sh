#!/bin/bash
set -e

# Colores para la terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Iniciando proceso de construcción completa...${NC}"

# 1. Detectar si estamos en un contenedor
IN_CONTAINER=false
if [ -f /.dockerenv ]; then
    IN_CONTAINER=true
    echo -e "${BLUE}🐳 Entorno de contenedor detectado.${NC}"
fi

# 2. Obtener versión del pubspec.yaml
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //')
VERSION_CLEAN=$(echo $VERSION | cut -d'+' -f1)
echo -e "${BLUE}📌 Versión detectada: $VERSION_CLEAN${NC}"

# 3. Gestión de dependencias
if [ "$IN_CONTAINER" = true ]; then
    echo -e "${BLUE}🧹 Limpiando configuración local para evitar conflictos...${NC}"
    rm -rf .dart_tool/
    flutter pub get
else
    if [ ! -d ".dart_tool" ]; then
        echo -e "${BLUE}🧹 Obteniendo dependencias...${NC}"
        flutter pub get
    fi
fi

# 4. Compilación de Flutter
echo -e "${BLUE}🔨 Compilando Flutter para Linux (Release)...${NC}"
flutter build linux --release --build-name=$VERSION_CLEAN

# 5. Empaquetado
echo -e "${GREEN}📦 Generando paquetes...${NC}"
./scripts/package_appimage.sh "$VERSION_CLEAN"
./scripts/package_tarball.sh "$VERSION_CLEAN"

echo -e "${GREEN}✅ ¡Proceso completado con éxito!${NC}"
