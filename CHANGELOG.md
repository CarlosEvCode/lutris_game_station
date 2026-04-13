# Changelog

## [2.7.0](https://github.com/CarlosEvCode/lutris_game_station/compare/v2.6.0...v2.7.0) (2026-04-13)


### Features

* implement ZSync update information and cleanup release assets ([f2ce9a9](https://github.com/CarlosEvCode/lutris_game_station/commit/f2ce9a948f310075b1bb4e261e2a25ccc8812bdc))

## [2.6.0](https://github.com/CarlosEvCode/lutris_game_station/compare/v2.5.1...v2.6.0) (2026-04-13)


### Features

* add GBA, PS Vita and enhance DS/Xbox with standalone runner support based on Lutris JSON definitions ([a04809c](https://github.com/CarlosEvCode/lutris_game_station/commit/a04809c5c41ce89658d29eca640564c161f794ab))
* add PSP and Dreamcast platforms with multi-emulator support ([2fc7a43](https://github.com/CarlosEvCode/lutris_game_station/commit/2fc7a4378856bf0d5a9a442000b9dd109fa283c8))
* implement multi-emulator architecture per platform and enhance visual manager compatibility ([c33974f](https://github.com/CarlosEvCode/lutris_game_station/commit/c33974fd6838ca9d4e483db413702072e7be11ce))

## [2.5.1](https://github.com/CarlosEvCode/lutris_game_station/compare/v2.5.0...v2.5.1) (2026-04-13)


### Bug Fixes

* use static runtime in AppImage to remove libfuse2 dependency ([645f6b5](https://github.com/CarlosEvCode/lutris_game_station/commit/645f6b595dccd66b1ac3f9e894695456d3f8121e))

## [2.5.0](https://github.com/CarlosEvCode/lutris_game_station/compare/v2.4.2...v2.5.0) (2026-04-12)


### Features

* show Steam export requirements dialog instead of hiding actions ([eeb4b84](https://github.com/CarlosEvCode/lutris_game_station/commit/eeb4b84e053351827e89ab70e3165d0bcb5a050c))

## [2.4.2](https://github.com/CarlosEvCode/lutris_game_station/compare/v2.4.1...v2.4.2) (2026-04-12)


### Bug Fixes

* ensure libselinux portability in AppImage by removing manual deletion ([af22f2b](https://github.com/CarlosEvCode/lutris_game_station/commit/af22f2b15fbb27bf1cd5c9b39531c2294942521f))
* make Steam platform sync safe and deterministic ([63bb716](https://github.com/CarlosEvCode/lutris_game_station/commit/63bb716cadec386ea0452ab455e56407b4ee316c))

## [2.4.1](https://github.com/CarlosEvCode/lutris_game_station/compare/v2.4.0...v2.4.1) (2026-03-21)


### Bug Fixes

* ensure libselinux portability in AppImage by removing manual deletion
* make Steam platform sync safe and deterministic ([8bd7c28](https://github.com/CarlosEvCode/lutris_game_station/commit/8bd7c28813a45464f6b7b4fbf86dc1c31d70ec5b))

## [2.4.0](https://github.com/CarlosEvCode/lutris_game_station/compare/v2.3.0...v2.4.0) (2026-03-21)


### Features

* add Steam batch export actions with availability gating ([39aa5a1](https://github.com/CarlosEvCode/lutris_game_station/commit/39aa5a13f543ce79852058b0ba59ac9ade17662c))
* add Steam shortcut export with Lutris URI and artwork sync ([b5a0197](https://github.com/CarlosEvCode/lutris_game_station/commit/b5a01976eaab59bca8ecf2a1d5aa47ea75d96553))
* auto-create Steam simple collections by platform ([d616e7e](https://github.com/CarlosEvCode/lutris_game_station/commit/d616e7e0df102b5d378626536cb71415546aadc3))
* gate Steam export by runtime dependencies and document setup ([4c9f739](https://github.com/CarlosEvCode/lutris_game_station/commit/4c9f739621251ea8d787afadb4b9ca6837ba5df6))

## [2.3.0](https://github.com/CarlosEvCode/lutris_game_station/compare/v2.2.0...v2.3.0) (2026-03-20)


### Features

* enhance visual manager UX with detailed game information screen ([7075254](https://github.com/CarlosEvCode/lutris_game_station/commit/7075254f737fe609845d996a4585dbbcefb2d508))
* improve detail correction flow and ROM source visibility ([e8afb5e](https://github.com/CarlosEvCode/lutris_game_station/commit/e8afb5ee652d7b1a56a696367b7248eb3e7461ae))
* optimize ScreenScraper API usage with intelligent caching ([aaa2274](https://github.com/CarlosEvCode/lutris_game_station/commit/aaa22742ef330dc649e494d3ad5b1b06173947d0))
* polish detail UX and sync visual manager platform context ([95ec5d7](https://github.com/CarlosEvCode/lutris_game_station/commit/95ec5d761d79d63a78c526b25ef4af51f80ef213))
* streamline detail actions with per-media edit shortcuts ([ba4cafd](https://github.com/CarlosEvCode/lutris_game_station/commit/ba4cafde853594fda5bba18d4f881aa2e531e2e6))


### Bug Fixes

* refresh media previews after apply and keep detail open ([ad72739](https://github.com/CarlosEvCode/lutris_game_station/commit/ad72739b2ab89e85d4b4bc4e10411976f71d4165))

## [2.2.0](https://github.com/CarlosEvCode/lutris_game_station/compare/v2.1.1...v2.2.0) (2026-03-18)


### Features

* redesign visual manager for desktop workflow ([5335de9](https://github.com/CarlosEvCode/lutris_game_station/commit/5335de95c8f0eda66bccad99cddfcc7208a901bb))

## [2.1.1](https://github.com/CarlosEvCode/lutris_game_station/compare/v2.1.0...v2.1.1) (2026-03-18)


### Bug Fixes

* embed developer credentials at compile time via --dart-define ([b145bee](https://github.com/CarlosEvCode/lutris_game_station/commit/b145bee69c60df79ba1c95796c6992b9043e6ba5))

## [2.1.0](https://github.com/CarlosEvCode/lutris_game_station/compare/v2.0.0...v2.1.0) (2026-03-18)


### Features

* trigger build with .env secrets configuration ([ed3e37e](https://github.com/CarlosEvCode/lutris_game_station/commit/ed3e37e24c20e31cbe94377f4128af3f5a4311e9))

## [2.0.0](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.6.0...v2.0.0) (2026-03-17)


### ⚠ BREAKING CHANGES

* UI layout restructured from vertical scroll to 2-column desktop layout

### Features

* complete ScreenScraper API integration and desktop UI redesign ([4d2dbe7](https://github.com/CarlosEvCode/lutris_game_station/commit/4d2dbe7c77cb15c29cff861cd2a329e00d7c62df))

## [1.6.0](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.5.2...v1.6.0) (2026-03-17)


### Features

* añadir alternancia entre vista de cuadrícula y lista en el gestor visual ([f23bb05](https://github.com/CarlosEvCode/lutris_game_station/commit/f23bb052951cc88f473202e97d73de80d577b784))
* añadir selector interactivo entre Lutris Nativo y Flatpak ([35cd94a](https://github.com/CarlosEvCode/lutris_game_station/commit/35cd94a0fd59c8aff96080dd15a85261a7bc5da4))
* implementar filtrado de metadatos faltantes y sincronización con el disco ([62226b7](https://github.com/CarlosEvCode/lutris_game_station/commit/62226b77ac92b9f9636262e1dace54253ff6542e))
* implementar previsualización y selección manual de ROMs antes de la inyección ([4535a57](https://github.com/CarlosEvCode/lutris_game_station/commit/4535a578be0c6782a0a20c08ce505df49fe0c91a))
* implementar scroll infinito en el gestor visual para mejorar rendimiento ([f05ba94](https://github.com/CarlosEvCode/lutris_game_station/commit/f05ba9491fd712e13c465c3e8f9a3154de94975b))
* mejoras avanzadas en el inyector (edición de nombres, escaneo recursivo y perfiles de ruta) ([85053ed](https://github.com/CarlosEvCode/lutris_game_station/commit/85053ed635be1d91a0df9428fcf1521beb94f82f))


### Bug Fixes

* refrescar gestor visual automáticamente al cambiar modo de Lutris ([eb2cc14](https://github.com/CarlosEvCode/lutris_game_station/commit/eb2cc14475efa2d0b55744b7aa2bf74a2b0876ab))

## [1.5.2](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.5.1...v1.5.2) (2026-03-17)


### Bug Fixes

* asegurar permisos de ejecución del binario en el AppImage ([60c39c0](https://github.com/CarlosEvCode/lutris_game_station/commit/60c39c056ab03138e09d98119cca76f6f08ce380))

## [1.5.1](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.5.0...v1.5.1) (2026-03-17)


### Bug Fixes

* forzar DEPLOY_GTK_VERSION=3 para GitHub Actions ([a8f4668](https://github.com/CarlosEvCode/lutris_game_station/commit/a8f466882cafc9c56782266ebec79133f9e2fe29))

## [1.5.0](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.4.6...v1.5.0) (2026-03-17)


### Features

* implementar detección de ROMs por hash e integración con ScreenScraper ([fba1d0a](https://github.com/CarlosEvCode/lutris_game_station/commit/fba1d0a394d9e0fddd23ef2a992a3aef731cb38e))
* profesionalizar flujo de empaquetado Linux (AppImage, Tarball, Flatpak) ([00f3407](https://github.com/CarlosEvCode/lutris_game_station/commit/00f34077894aea1ec319f1fa89b759cb3c940f4c))

## [1.4.6](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.4.5...v1.4.6) (2026-03-15)


### Bug Fixes

* pulir integración con el host (cursor del mouse y limpieza de librerías base) y profesionalizar ID de aplicación ([a4f9de3](https://github.com/CarlosEvCode/lutris_game_station/commit/a4f9de3c05800cf8ad317e7da36056f47377f7f3))

## [1.4.5](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.4.4...v1.4.5) (2026-03-15)


### Bug Fixes

* añadir dpkg-dev a dependencias para compatibilidad con plugin GTK en contenedor ([e5e15e7](https://github.com/CarlosEvCode/lutris_game_station/commit/e5e15e746c9cadc68b89638c412fe8b4b87b362f))

## [1.4.4](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.4.3...v1.4.4) (2026-03-15)


### Bug Fixes

* corregir descarga y ejecución del plugin GTK para linuxdeploy ([993e973](https://github.com/CarlosEvCode/lutris_game_station/commit/993e9732f90d4eda8387d7738855570fe96dcc4d))

## [1.4.3](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.4.2...v1.4.3) (2026-03-15)


### Bug Fixes

* integrar plugin GTK y configurar variables de entorno para cargadores de imágenes y temas en AppImage ([ba4cd59](https://github.com/CarlosEvCode/lutris_game_station/commit/ba4cd59f8f61de36dc9dc267803e139651e031d4))

## [1.4.2](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.4.1...v1.4.2) (2026-03-15)


### Bug Fixes

* implementar estrategia maestro v6 con empaquetado manual mediante appimagetool y runtime local ([6c479a3](https://github.com/CarlosEvCode/lutris_game_station/commit/6c479a30a22842658d54f3feeb34c9ce3332ea55))

## [1.4.1](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.4.0...v1.4.1) (2026-03-15)


### Bug Fixes

* implementar estrategia maestra v5 con runtime local y LD_LIBRARY_PATH para linuxdeploy ([800db3b](https://github.com/CarlosEvCode/lutris_game_station/commit/800db3b820d88fe86ccdc29fa2d10ef89681f2ab))

## [1.4.0](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.3.11...v1.4.0) (2026-03-15)


### Features

* mostrar ruta de configuración al guardar API Key para mayor transparencia ([c443527](https://github.com/CarlosEvCode/lutris_game_station/commit/c44352728d4ca006c830415e2ff20d919f51134f))
* persistencia de API Key en ~/.config/lutris_game_station/config.json ([c7163d4](https://github.com/CarlosEvCode/lutris_game_station/commit/c7163d479627ebd7ec4ae4e34f451e6dbab27ab9))
* Unificación y migración completa a Lutris Game Station ([4fd2f1a](https://github.com/CarlosEvCode/lutris_game_station/commit/4fd2f1a2371f6aa257aab8779227f1265b9082a9))


### Bug Fixes

* añadir jq al contenedor para compatibilidad con flutter-action ([89745c3](https://github.com/CarlosEvCode/lutris_game_station/commit/89745c3d1276073622bed6accaf2c89755e787da))
* añadir lld a dependencias para resolver error de linker en ubuntu 20.04 ([a0e3c2b](https://github.com/CarlosEvCode/lutris_game_station/commit/a0e3c2b2cf542bd4c96521acdbacd704eab07750))
* compilar AppImage dentro de contenedor Ubuntu 20.04 para máxima compatibilidad ([7fe3950](https://github.com/CarlosEvCode/lutris_game_station/commit/7fe39501096161a35e7ca074eefb0192943b1205))
* configurar git para confiar en todos los directorios dentro del contenedor ([0d2dcaf](https://github.com/CarlosEvCode/lutris_game_station/commit/0d2dcafa1077a8e86f3c8503a6a9b9674a5b5219))
* corregir descarga del plugin de Flutter para linuxdeploy usando curl y rama main ([c992d41](https://github.com/CarlosEvCode/lutris_game_station/commit/c992d419a9f53a12e782baf29e373cd98ec60826))
* corregir indentación YAML en el workflow de release ([8118f12](https://github.com/CarlosEvCode/lutris_game_station/commit/8118f12467614bbfee2b4c4b074f451a03a622cc))
* corregir título de la ventana principal de la aplicación ([0fa45a1](https://github.com/CarlosEvCode/lutris_game_station/commit/0fa45a1e26da44af6ef3db6b7beb50f2aafa6b8b))
* corregir URL de descarga del plugin y nombre de ejecutable para linuxdeploy ([611df07](https://github.com/CarlosEvCode/lutris_game_station/commit/611df07e9762e4e95042b3cc4361919a094f546d))
* empaquetado AppImage manual para evitar errores de red con el plugin de Flutter ([0581178](https://github.com/CarlosEvCode/lutris_game_station/commit/05811786eab74754c25afedf6aaffe804a0c5c87))
* establecer DEBIAN_FRONTEND=noninteractive para evitar bloqueos en el contenedor ([18ced8b](https://github.com/CarlosEvCode/lutris_game_station/commit/18ced8b7f0a126e1f6e117de5b93458af9ea6dd6))
* evitar duplicados de juegos por múltiples formatos o re-inyecciones ([a24919d](https://github.com/CarlosEvCode/lutris_game_station/commit/a24919d768c2d8c11460c41eff7901752ba2ad1e))
* implementar estrategia maestra v3 con patchelf y organización de librerías estándar para AppImage ([adb13d1](https://github.com/CarlosEvCode/lutris_game_station/commit/adb13d14abb53e6bc3d537eba8cf5e886014d16e))
* implementar estrategia maestra v4 respetando el bundle nativo de Flutter para evitar errores de AOT ELF path ([e736c0e](https://github.com/CarlosEvCode/lutris_game_station/commit/e736c0eb1869c4c78e0d786337ff43c2c9505343))
* implementar estrategia robusta v2 para AppImage con AppRun y LD_LIBRARY_PATH ([6782c06](https://github.com/CarlosEvCode/lutris_game_station/commit/6782c064e7c7d6ccf672c7a6cd49555ba0a76171))
* incrustar libsqlite3.so directamente en el bundle de la app para asegurar carga dinámica ([55edfca](https://github.com/CarlosEvCode/lutris_game_station/commit/55edfcab6585c3e68ac40f1af62701b21729833b))
* mantener bundle de Flutter íntegro y corregir enlace simbólico de sqlite3 en AppImage ([5a16923](https://github.com/CarlosEvCode/lutris_game_station/commit/5a16923cb917267d1cfa7adcc77268fd7f2c8839))
* redimensionar icono a 512x512 para cumplir validación de linuxdeploy ([e657974](https://github.com/CarlosEvCode/lutris_game_station/commit/e657974629ab6aacfdc872a115d01726e7ac8324))
* resolver carga de sqlite3 y mejorar estructura del AppImage para temas GTK ([c1a7fcb](https://github.com/CarlosEvCode/lutris_game_station/commit/c1a7fcba6a2e9751383cadf5331363829aa44394))
* revertir cambios en main.dart y aplicar solución de sqlite3 vía symlink en AppImage ([5ea92a5](https://github.com/CarlosEvCode/lutris_game_station/commit/5ea92a57cdfc69475c19626b2331a2be1ff9e50d))
