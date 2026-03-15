# 🎮 Lutris Game Station

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)](https://www.linux.org)
[![SteamGridDB](https://img.shields.io/badge/SteamGridDB-API-blue?style=for-the-badge)](https://www.steamgriddb.com/)

**Lutris Game Station** es una herramienta avanzada y unificada diseñada específicamente para usuarios de **Lutris en Linux**. Esta aplicación combina la gestión automatizada de ROMs con una potente interfaz visual para el enriquecimiento de metadatos, permitiéndote transformar tu biblioteca de juegos en una experiencia visualmente impactante y perfectamente organizada.

---

## ✨ Funcionalidades Principales

### 🚀 1. Inyector Automático de ROMs
Olvida la configuración manual de cada juego. Nuestro inyector automatiza todo el proceso:
- **Detección de Plataformas:** Soporte nativo para múltiples sistemas (PS1, PS2, GameCube, Wii, Wii U, 3DS, MAME).
- **Generación de Configuración:** Crea automáticamente los archivos YAML necesarios para Lutris.
- **Limpieza Inteligente:** Opción para limpiar entradas antiguas de un runner antes de una nueva inyección, manteniendo tu base de datos libre de duplicados.
- **Soporte Universal:** Funciona tanto con instalaciones de Lutris **Nativas** como **Flatpak**.

### 🎨 2. Gestor Visual de Metadatos
Dale vida a tu biblioteca con arte profesional directamente desde **SteamGridDB**:
- **Búsqueda en Tiempo Real:** Filtra tus juegos instalados para encontrar exactamente el que quieres mejorar.
- **Selector de Arte:** Interfaz intuitiva para elegir entre múltiples:
    - **Covers:** Portadas verticales de alta calidad (600x900).
    - **Banners:** Arte horizontal para la vista detallada.
    - **Iconos:** Iconografía para el sistema y la barra lateral de Lutris.
- **Caché Inteligente:** Visualiza instantáneamente los cambios gracias a nuestro sistema de refresco de imágenes.
- **Descarga Automatizada:** Descarga masiva de metadatos durante el proceso de inyección.

### 🤖 3. Integración con SteamGridDB
- **Bypass de Seguridad:** Sistema robusto con rotación de User-Agents y reintentos automáticos para evitar bloqueos.
- **Lógica Específica para Nintendo:** Salto automático de avisos legales para obtener las mejores portadas de juegos de Nintendo sin intervención manual.

---

## 🛠️ Tecnologías Utilizadas

- **Flutter & Dart:** Para una interfaz moderna, fluida y nativa en Linux.
- **SQLite:** Interacción directa con la base de datos `pga.db` de Lutris.
- **FlexColorScheme:** Estética profesional con soporte para temas claros y oscuros (optimizado para Dark Mode).
- **Http & Parallel Processing:** Descargas rápidas y seguras de recursos visuales.

---

## 🚀 Guía de Inicio Rápido

### Requisitos Previos
1. **Lutris** instalado (Nativo o Flatpak).
2. **Flutter SDK** (para desarrollo/compilación).
3. **API Key de SteamGridDB:** Consíguela gratuitamente en [SteamGridDB API](https://www.steamgriddb.com/profile/api).

### Instalación
Clona el repositorio y obtén las dependencias:
```bash
git clone <tu-repositorio>
cd lutris_game_station
flutter pub get
```

### Ejecución
```bash
flutter run
```

---

## 📖 Cómo usar Lutris Game Station

1. **Configuración Inicial:** Abre el icono de engranaje (Settings) y pega tu API Key de SteamGridDB.
2. **Auto-Inyección:**
    - Selecciona tu plataforma (ej: Sony PlayStation 2).
    - Busca la carpeta donde guardas tus archivos de juego.
    - Presiona "Inyectar + Metadatos" para automatizar todo el proceso.
3. **Gestión Visual:**
    - Ve a la pestaña "Gestor Visual".
    - Busca un juego específico en la barra superior.
    - Haz clic en el icono de editar sobre cualquier juego para buscar y seleccionar manualmente nuevas portadas, banners o iconos.

---

## 🐧 Compatibilidad con Linux

Lutris Game Station detecta automáticamente las rutas estándar de Lutris:
- **Nativo:** `~/.local/share/lutris/`
- **Flatpak:** `~/.var/app/net.lutris.Lutris/data/lutris/`

---

## 🤝 Contribuciones

¿Tienes una idea para una nueva plataforma o funcionalidad? ¡Las contribuciones son bienvenidas! Siente libertad de abrir un Issue o un Pull Request.

---

## 📄 Licencia

Este proyecto está bajo la licencia MIT. Consulta el archivo `LICENSE` para más detalles.

---
*Desarrollado con ❤️ para la comunidad de gaming en Linux.*
