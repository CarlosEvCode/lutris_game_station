# Changelog

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

## [1.3.11](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.3.10...v1.3.11) (2026-03-15)


### Bug Fixes

* añadir lld a dependencias para resolver error de linker en ubuntu 20.04 ([a0e3c2b](https://github.com/CarlosEvCode/lutris_game_station/commit/a0e3c2b2cf542bd4c96521acdbacd704eab07750))

## [1.3.10](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.3.9...v1.3.10) (2026-03-15)


### Bug Fixes

* configurar git para confiar en todos los directorios dentro del contenedor ([0d2dcaf](https://github.com/CarlosEvCode/lutris_game_station/commit/0d2dcafa1077a8e86f3c8503a6a9b9674a5b5219))

## [1.3.9](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.3.8...v1.3.9) (2026-03-15)


### Bug Fixes

* añadir jq al contenedor para compatibilidad con flutter-action ([89745c3](https://github.com/CarlosEvCode/lutris_game_station/commit/89745c3d1276073622bed6accaf2c89755e787da))

## [1.3.8](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.3.7...v1.3.8) (2026-03-15)


### Bug Fixes

* establecer DEBIAN_FRONTEND=noninteractive para evitar bloqueos en el contenedor ([18ced8b](https://github.com/CarlosEvCode/lutris_game_station/commit/18ced8b7f0a126e1f6e117de5b93458af9ea6dd6))

## [1.3.7](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.3.6...v1.3.7) (2026-03-15)


### Bug Fixes

* compilar AppImage dentro de contenedor Ubuntu 20.04 para máxima compatibilidad ([7fe3950](https://github.com/CarlosEvCode/lutris_game_station/commit/7fe39501096161a35e7ca074eefb0192943b1205))

## [1.3.6](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.3.5...v1.3.6) (2026-03-15)


### Bug Fixes

* corregir título de la ventana principal de la aplicación ([0fa45a1](https://github.com/CarlosEvCode/lutris_game_station/commit/0fa45a1e26da44af6ef3db6b7beb50f2aafa6b8b))

## [1.3.5](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.3.4...v1.3.5) (2026-03-15)


### Bug Fixes

* implementar estrategia maestra v4 respetando el bundle nativo de Flutter para evitar errores de AOT ELF path ([e736c0e](https://github.com/CarlosEvCode/lutris_game_station/commit/e736c0eb1869c4c78e0d786337ff43c2c9505343))

## [1.3.4](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.3.3...v1.3.4) (2026-03-15)


### Bug Fixes

* implementar estrategia maestra v3 con patchelf y organización de librerías estándar para AppImage ([adb13d1](https://github.com/CarlosEvCode/lutris_game_station/commit/adb13d14abb53e6bc3d537eba8cf5e886014d16e))

## [1.3.3](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.3.2...v1.3.3) (2026-03-15)


### Bug Fixes

* implementar estrategia robusta v2 para AppImage con AppRun y LD_LIBRARY_PATH ([6782c06](https://github.com/CarlosEvCode/lutris_game_station/commit/6782c064e7c7d6ccf672c7a6cd49555ba0a76171))

## [1.3.2](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.3.1...v1.3.2) (2026-03-15)


### Bug Fixes

* incrustar libsqlite3.so directamente en el bundle de la app para asegurar carga dinámica ([55edfca](https://github.com/CarlosEvCode/lutris_game_station/commit/55edfcab6585c3e68ac40f1af62701b21729833b))

## [1.3.1](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.3.0...v1.3.1) (2026-03-15)


### Bug Fixes

* mantener bundle de Flutter íntegro y corregir enlace simbólico de sqlite3 en AppImage ([5a16923](https://github.com/CarlosEvCode/lutris_game_station/commit/5a16923cb917267d1cfa7adcc77268fd7f2c8839))

## [1.3.0](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.2.2...v1.3.0) (2026-03-15)


### Features

* mostrar ruta de configuración al guardar API Key para mayor transparencia ([c443527](https://github.com/CarlosEvCode/lutris_game_station/commit/c44352728d4ca006c830415e2ff20d919f51134f))
* persistencia de API Key en ~/.config/lutris_game_station/config.json ([c7163d4](https://github.com/CarlosEvCode/lutris_game_station/commit/c7163d479627ebd7ec4ae4e34f451e6dbab27ab9))
* Unificación y migración completa a Lutris Game Station ([4fd2f1a](https://github.com/CarlosEvCode/lutris_game_station/commit/4fd2f1a2371f6aa257aab8779227f1265b9082a9))


### Bug Fixes

* corregir descarga del plugin de Flutter para linuxdeploy usando curl y rama main ([c992d41](https://github.com/CarlosEvCode/lutris_game_station/commit/c992d419a9f53a12e782baf29e373cd98ec60826))
* corregir indentación YAML en el workflow de release ([8118f12](https://github.com/CarlosEvCode/lutris_game_station/commit/8118f12467614bbfee2b4c4b074f451a03a622cc))
* corregir URL de descarga del plugin y nombre de ejecutable para linuxdeploy ([611df07](https://github.com/CarlosEvCode/lutris_game_station/commit/611df07e9762e4e95042b3cc4361919a094f546d))
* empaquetado AppImage manual para evitar errores de red con el plugin de Flutter ([0581178](https://github.com/CarlosEvCode/lutris_game_station/commit/05811786eab74754c25afedf6aaffe804a0c5c87))
* evitar duplicados de juegos por múltiples formatos o re-inyecciones ([a24919d](https://github.com/CarlosEvCode/lutris_game_station/commit/a24919d768c2d8c11460c41eff7901752ba2ad1e))
* redimensionar icono a 512x512 para cumplir validación de linuxdeploy ([e657974](https://github.com/CarlosEvCode/lutris_game_station/commit/e657974629ab6aacfdc872a115d01726e7ac8324))
* resolver carga de sqlite3 y mejorar estructura del AppImage para temas GTK ([c1a7fcb](https://github.com/CarlosEvCode/lutris_game_station/commit/c1a7fcba6a2e9751383cadf5331363829aa44394))
* revertir cambios en main.dart y aplicar solución de sqlite3 vía symlink en AppImage ([5ea92a5](https://github.com/CarlosEvCode/lutris_game_station/commit/5ea92a57cdfc69475c19626b2331a2be1ff9e50d))

## [1.2.2](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.2.1...v1.2.2) (2026-03-15)


### Bug Fixes

* revertir cambios en main.dart y aplicar solución de sqlite3 vía symlink en AppImage ([5ea92a5](https://github.com/CarlosEvCode/lutris_game_station/commit/5ea92a57cdfc69475c19626b2331a2be1ff9e50d))

## [1.2.1](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.2.0...v1.2.1) (2026-03-15)


### Bug Fixes

* resolver carga de sqlite3 y mejorar estructura del AppImage para temas GTK ([c1a7fcb](https://github.com/CarlosEvCode/lutris_game_station/commit/c1a7fcba6a2e9751383cadf5331363829aa44394))

## [1.2.0](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.1.4...v1.2.0) (2026-03-15)


### Features

* mostrar ruta de configuración al guardar API Key para mayor transparencia ([c443527](https://github.com/CarlosEvCode/lutris_game_station/commit/c44352728d4ca006c830415e2ff20d919f51134f))
* persistencia de API Key en ~/.config/lutris_game_station/config.json ([c7163d4](https://github.com/CarlosEvCode/lutris_game_station/commit/c7163d479627ebd7ec4ae4e34f451e6dbab27ab9))
* Unificación y migración completa a Lutris Game Station ([4fd2f1a](https://github.com/CarlosEvCode/lutris_game_station/commit/4fd2f1a2371f6aa257aab8779227f1265b9082a9))


### Bug Fixes

* corregir descarga del plugin de Flutter para linuxdeploy usando curl y rama main ([c992d41](https://github.com/CarlosEvCode/lutris_game_station/commit/c992d419a9f53a12e782baf29e373cd98ec60826))
* corregir indentación YAML en el workflow de release ([8118f12](https://github.com/CarlosEvCode/lutris_game_station/commit/8118f12467614bbfee2b4c4b074f451a03a622cc))
* corregir URL de descarga del plugin y nombre de ejecutable para linuxdeploy ([611df07](https://github.com/CarlosEvCode/lutris_game_station/commit/611df07e9762e4e95042b3cc4361919a094f546d))
* empaquetado AppImage manual para evitar errores de red con el plugin de Flutter ([0581178](https://github.com/CarlosEvCode/lutris_game_station/commit/05811786eab74754c25afedf6aaffe804a0c5c87))
* evitar duplicados de juegos por múltiples formatos o re-inyecciones ([a24919d](https://github.com/CarlosEvCode/lutris_game_station/commit/a24919d768c2d8c11460c41eff7901752ba2ad1e))
* redimensionar icono a 512x512 para cumplir validación de linuxdeploy ([e657974](https://github.com/CarlosEvCode/lutris_game_station/commit/e657974629ab6aacfdc872a115d01726e7ac8324))

## [1.1.4](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.1.3...v1.1.4) (2026-03-15)


### Bug Fixes

* redimensionar icono a 512x512 para cumplir validación de linuxdeploy ([e657974](https://github.com/CarlosEvCode/lutris_game_station/commit/e657974629ab6aacfdc872a115d01726e7ac8324))

## [1.1.3](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.1.2...v1.1.3) (2026-03-15)


### Bug Fixes

* empaquetado AppImage manual para evitar errores de red con el plugin de Flutter ([0581178](https://github.com/CarlosEvCode/lutris_game_station/commit/05811786eab74754c25afedf6aaffe804a0c5c87))

## [1.1.2](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.1.1...v1.1.2) (2026-03-15)


### Bug Fixes

* corregir indentación YAML en el workflow de release ([8118f12](https://github.com/CarlosEvCode/lutris_game_station/commit/8118f12467614bbfee2b4c4b074f451a03a622cc))
* corregir URL de descarga del plugin y nombre de ejecutable para linuxdeploy ([611df07](https://github.com/CarlosEvCode/lutris_game_station/commit/611df07e9762e4e95042b3cc4361919a094f546d))

## [1.1.1](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.1.0...v1.1.1) (2026-03-15)


### Bug Fixes

* corregir descarga del plugin de Flutter para linuxdeploy usando curl y rama main ([c992d41](https://github.com/CarlosEvCode/lutris_game_station/commit/c992d419a9f53a12e782baf29e373cd98ec60826))

## [1.1.0](https://github.com/CarlosEvCode/lutris_game_station/compare/v1.0.0...v1.1.0) (2026-03-15)


### Features

* mostrar ruta de configuración al guardar API Key para mayor transparencia ([c443527](https://github.com/CarlosEvCode/lutris_game_station/commit/c44352728d4ca006c830415e2ff20d919f51134f))

## 1.0.0 (2026-03-15)


### Features

* persistencia de API Key en ~/.config/lutris_game_station/config.json ([c7163d4](https://github.com/CarlosEvCode/lutris_game_station/commit/c7163d479627ebd7ec4ae4e34f451e6dbab27ab9))
* Unificación y migración completa a Lutris Game Station ([4fd2f1a](https://github.com/CarlosEvCode/lutris_game_station/commit/4fd2f1a2371f6aa257aab8779227f1265b9082a9))


### Bug Fixes

* evitar duplicados de juegos por múltiples formatos o re-inyecciones ([a24919d](https://github.com/CarlosEvCode/lutris_game_station/commit/a24919d768c2d8c11460c41eff7901752ba2ad1e))
