#!/bin/bash
set -e

IMAGE_NAME="lgs-builder-ubuntu-22-04"

echo "🛠️ Construyendo imagen de compilación para Ubuntu 22.04..."

# Usamos docker directamente
if command -v docker &> /dev/null; then
    CONTAINER_TOOL="docker"
else
    echo "❌ Error: Docker no está instalado."
    exit 1
fi

# Construir la imagen
$CONTAINER_TOOL build -t $IMAGE_NAME -f Dockerfile.build .

echo "🚀 Iniciando compilación en contenedor Ubuntu 22.04..."
# Montamos la carpeta actual y corremos el script de build completo
$CONTAINER_TOOL run --rm -v "$(pwd):/app:z" $IMAGE_NAME

echo "✅ Proceso terminado. Archivos generados compatibles con Ubuntu 22.04+."
