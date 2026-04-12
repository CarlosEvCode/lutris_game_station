# Lutris Game Station

Desktop utility for Linux users who manage retro and console libraries in Lutris.

Lutris Game Station combines two workflows in one application:

- **ROM injection**: import local ROM collections and generate Lutris entries.
- **Visual metadata management**: apply cover art, banners, and icons from SteamGridDB, with optional high-precision identification using ScreenScraper.

## Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Supported Platforms](#supported-platforms)
- [How Metadata Works](#how-metadata-works)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Build with ScreenScraper Developer Credentials](#build-with-screenscraper-developer-credentials)
- [Steam Export Requirements](#steam-export-requirements)
- [Usage](#usage)
- [Lutris Path Detection](#lutris-path-detection)
- [Project Structure](#project-structure)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## Overview

Lutris Game Station is a Flutter desktop app focused on improving the day-to-day management of large Lutris libraries.

It reads and updates Lutris data directly (including `pga.db`, YAML game configs, and media folders), while keeping operations practical for real-world setups:

- Native Lutris installation
- Flatpak Lutris installation
- Mixed ROM sets with multiple file formats
- Large metadata runs with API quota constraints

## Key Features

### 1) ROM injection and batch import

- Scans local folders and filters files by platform extension
- Creates Lutris-compatible game entries
- Supports cleaning previous runner entries before re-injection
- Handles extension priority to avoid duplicate game entries (for example, `.bin` over `.cue`)

### 2) SteamGridDB visual manager

- Search and select SteamGridDB game matches
- Download and apply:
  - **Cover** (portrait)
  - **Banner** (landscape)
  - **Icon** (square)
- Writes assets to Lutris media folders and updates icon files for Lutris/system usage
- Includes cache to reduce repeated API calls and improve responsiveness

### 3) ScreenScraper high-precision identification

- Optional hash-based identification (CRC32/MD5/SHA1)
- Intelligent request limiting based on current quota
- In-memory and persistent disk caching
- Failed-lookups cache to avoid repeated expensive misses
- Extra metadata enrichment when available (developer, release date, synopsis, media URLs)

### 4) Desktop-first detail workflow

- Game detail view before opening the visual selector
- Current Lutris media preview and ScreenScraper media preview in one place
- Per-media edit shortcuts (cover/banner/icon) to jump directly to the relevant selector tab

### 5) Steam export for non-Steam shortcuts

- Export single games from detail view or batch export from Visual Manager
- Creates/updates non-Steam shortcuts using `lutris:rungameid/<id>`
- Syncs Steam artwork slots (`cover`, `hero`, `icon`, `wide`)
- Auto-creates and updates simple Steam collections by platform
- Hides Steam export actions automatically when Steam or required runtime dependencies are unavailable

## Supported Platforms

Current platform registry includes:

- Sony PlayStation (`ps1`)
- Sony PlayStation 2 (`ps2`)
- Nintendo GameCube (`gamecube`)
- Nintendo Wii (`wii`)
- Nintendo Wii U (`wii_u`)
- Nintendo 3DS (`3ds`)
- Arcade MAME (`mame`)

Platform definitions live in `lib/platforms/platform_registry.dart`.

## How Metadata Works

Lutris Game Station separates responsibilities between providers:

- **SteamGridDB**: primary source for downloadable visual assets used in Lutris UI.
- **ScreenScraper**: high-precision game identification and supplemental metadata.

In practice:

1. You can inject/import ROMs first.
2. If high-precision mode is enabled, the app attempts ScreenScraper identification using file hashes.
3. SteamGridDB is used to search and apply visual art.
4. The detail screen shows both current local media and available ScreenScraper extras when present.

This keeps the visual workflow flexible while preserving accurate matching where possible.

## Requirements

- Linux desktop
- Lutris (native or Flatpak)
- Flutter SDK (for running/building from source)
- SteamGridDB API key

Optional (for high-precision mode):

- ScreenScraper user credentials (`ssid` / password)
- ScreenScraper developer credentials (`SS_DEV_ID`, `SS_DEV_PASSWORD`, `SS_SOFT_NAME`) embedded at build time

Optional (for Steam export workflow):

- Python 3 runtime
- `vdf` Python module
- `Pillow` (`PIL`) Python module

## Installation

```bash
git clone https://github.com/CarlosEvCode/lutris_game_station.git
cd lutris_game_station
flutter pub get
```

Run in development:

```bash
flutter run -d linux
```

## Configuration

Use the app settings dialog to configure your credentials. These keys are essential for the application to fetch high-quality artwork and identify your games accurately.

### Obtaining API Keys

#### 1. SteamGridDB (Required for Artwork)
SteamGridDB is the primary source for covers, banners, and icons.
1.  Go to [steamgriddb.com](https://www.steamgriddb.com/) and log in (typically via Steam).
2.  Navigate to your **Profile Settings** or go directly to [steamgriddb.com/profile/api](https://www.steamgriddb.com/profile/api).
3.  Click on **"Generate API Key"**.
4.  Copy the key and paste it into the **Settings** dialog within Lutris Game Station.

#### 2. ScreenScraper (Optional for High-Precision)
ScreenScraper is used for hash-based identification (ensuring the "Right Game" is matched).
1.  Register an account at [screenscraper.fr](https://www.screenscraper.fr/).
2.  In the app's **Settings**, enter your **Username** and **Password**.
3.  *Note:* High-precision features also require **Developer Credentials** to be embedded at build time (see the [Build section](#build-with-screenscraper-developer-credentials) below).

## Build with ScreenScraper Developer Credentials

ScreenScraper developer credentials are read via compile-time defines.

Use `.env.example` as reference, then build with:

```bash
flutter build linux \
  --dart-define=SS_DEV_ID=your_dev_id \
  --dart-define=SS_DEV_PASSWORD=your_dev_password \
  --dart-define=SS_SOFT_NAME=LutrisGameStation
```

Notes:

- These values are consumed by `ScreenScraperService`.
- Without developer credentials, high-precision features are limited/disabled.
- User credentials (ssid/password) are still needed at runtime for quota/account checks.

## Steam Export Requirements

Lutris Game Station can export your games to Steam as non-Steam shortcuts, including artwork sync and platform-based collections.

> **Note:** Currently, only the **Native** installation of Steam is automatically detected and supported for export operations. Support for Steam via Flatpak is planned for future updates.

Required on the target system:

- `python3`
- `vdf`
- `Pillow`

Install command:

```bash
python3 -m pip install --user vdf pillow
```

Notes:

- Export buttons are shown only when Steam paths and required dependencies are detected.
- This behavior prevents partial exports on systems missing Steam or Python modules.

## Usage

### Basic flow

1. Open Settings and configure SteamGridDB API key.
2. Select a platform and ROM folder.
3. Preview detected files and run injection.
4. Open Visual Manager to inspect/update game media.

### High-precision flow (optional)

1. Configure ScreenScraper user credentials in Settings.
2. Build with developer credentials (`--dart-define`).
3. Enable high-precision identification before batch processing.
4. The app checks quota and warns when remaining capacity is insufficient.

### Steam export flow (optional)

1. Ensure Steam is installed and closed during export operations.
2. Verify Python modules are installed (`vdf`, `pillow`).
3. Export from game detail (single game) or Visual Manager (platform/selected batch).
4. Re-open Steam and confirm shortcuts, artwork, and platform collections.

## Lutris Path Detection

The app auto-detects and configures Lutris paths depending on installation mode.

- **Native** (data): `~/.local/share/lutris/`
- **Flatpak** (data): `~/.var/app/net.lutris.Lutris/data/lutris/`

It manages distinct paths for:

- database (`pga.db`)
- covers (`coverart/`)
- banners (`banners/`)
- icons (`icons/`)
- game configs (`games/` or `~/.config/lutris/games/` depending on mode)

## Project Structure

Key directories/files:

- `lib/ui/` - desktop UI screens and dialogs
- `lib/core/injector/` - ROM injection and batch logic
- `lib/core/lutris/` - Lutris repository and path handling
- `lib/core/metadata/` - SteamGridDB and ScreenScraper services/cache
- `lib/platforms/` - platform definitions and extension rules

## Troubleshooting

### SteamGridDB search does not work

- Verify API key in Settings.
- Confirm internet access and API key validity.

### High-precision identification unavailable

- Ensure app was built with `SS_DEV_ID`, `SS_DEV_PASSWORD`, `SS_SOFT_NAME`.
- Verify ScreenScraper user credentials in Settings.
- Check remaining daily quota.

### Media is not visible in detail view

- Confirm Lutris mode/path detection is correct (native vs Flatpak).
- Verify files exist in Lutris media folders (`coverart`, `banners`, `icons`).

## Contributing

Contributions are welcome.

If you want to add support for another platform, improve metadata matching, or refine desktop UX:

1. Open an issue describing the problem/proposal.
2. Submit a pull request with clear scope and test steps.

Please keep changes aligned with existing architecture and path-detection behavior for both native and Flatpak Lutris installations.
