# yt toolchain binaries

This directory contains **prebuilt third-party CLI binaries** used by the yt scripts.
All binaries are stored **inside the repository** to ensure deterministic,
environment-independent behavior across machines and platforms.

Binaries are organized by platform under `bin/<platform>/`.

---

## Platform: darwin (macOS)

### yt-dlp

* File: `bin/darwin/yt-dlp`
* Purpose: YouTube / media downloader
* Version: see `yt-dlp --version`
* Source: [https://github.com/yt-dlp/yt-dlp/releases](https://github.com/yt-dlp/yt-dlp/releases)
* Notes:

  * Single-file official binary
  * No Python dependency
  * Used by all yt download scripts

### ffmpeg

* File: `bin/darwin/ffmpeg`
* Purpose: Media processing (transcode, cut, merge, remux)
* Version: 8.0.1
* Source: [https://evermeet.cx/ffmpeg/](https://evermeet.cx/ffmpeg/)
* Build type: static
* Notes:

  * Self-contained binary
  * Does not rely on system ffmpeg

### ffprobe

* File: `bin/darwin/ffprobe`
* Purpose: Media metadata inspection (duration, streams, codecs)
* Version: 8.0.1
* Source: [https://evermeet.cx/ffmpeg/](https://evermeet.cx/ffmpeg/)

### jq

* File: `bin/darwin/jq-macos-amd64`
* Purpose: JSON processor (parse and extract structured data)
* Version: 1.8.1
* Source: https://github.com/jqlang/jq/releases
* Notes:

  * Official single-file binary
  * No runtime dependencies
  * Used for parsing yt-dlp JSON output

---

## Platform: linux

### yt-dlp

* File: `bin/linux/yt-dlp_linux`
* Purpose: YouTube / media downloader
* Version: see `yt-dlp_linux --version`
* Source: [https://github.com/yt-dlp/yt-dlp/releases](https://github.com/yt-dlp/yt-dlp/releases)
* Notes:

  * Official single-file Linux binary
  * No Python dependency

### ffmpeg

* File: `bin/linux/ffmpeg`
* Purpose: Media processing
* Version: 7.0.2
* Source: [https://johnvansickle.com/ffmpeg/](https://johnvansickle.com/ffmpeg/)
* Build type: static
* Architecture: amd64
* Notes:

  * Fully static build
  * Portable across most modern Linux systems

### ffprobe

* File: `bin/linux/ffprobe`
* Purpose: Media metadata inspection
* Version: 7.0.2
* Source: [https://johnvansickle.com/ffmpeg/](https://johnvansickle.com/ffmpeg/)

### jq

* File: `bin/linux/jq-linux-amd64`
* Purpose: JSON processor
* Version: 1.8.1
* Source: https://github.com/jqlang/jq/releases
* Notes:

  * Official static binary
  * Used by yt metadata parsing scripts

---

## Platform: windows

### yt-dlp

* File: `bin/windows/yt-dlp.exe`
* Purpose: YouTube / media downloader
* Version: see `yt-dlp.exe --version`
* Source: [https://github.com/yt-dlp/yt-dlp/releases](https://github.com/yt-dlp/yt-dlp/releases)
* Notes:

  * Portable single executable
  * No installation required

### ffmpeg

* File: `bin/windows/ffmpeg.exe`
* Purpose: Media processing
* Version: 8.0.1 (essentials)
* Source: [https://www.gyan.dev/ffmpeg/builds/](https://www.gyan.dev/ffmpeg/builds/)
* Build type: essentials
* Notes:

  * Includes common codecs only
  * Selected for stability and smaller footprint

### ffprobe

* File: `bin/windows/ffprobe.exe`
* Purpose: Media metadata inspection
* Version: 8.0.1
* Source: [https://www.gyan.dev/ffmpeg/builds/](https://www.gyan.dev/ffmpeg/builds/)

### jq

* File: `bin/windows/jq-win64.exe`
* Purpose: JSON processor
* Version: 1.8.1
* Source: https://github.com/jqlang/jq/releases
* Notes:

  * Portable executable
  * No installation required

---

## Design principles

* Only **runtime-required executables** are included.
* Filenames are kept **stable** (no version suffixes).
* Version information is recorded here instead of filenames.
* Scripts must **not rely on system-installed tools**.
* Platform differences are handled via a resolve layer.

---

## Upgrade policy

* Binaries are upgraded manually.
* When upgrading:

  1. Replace the executable file.
  2. Update the version information in this README.
* No automatic self-update is performed by scripts.

---

## Non-goals

The following tools are intentionally **not included**:

* ffplay (debug-only media player)
* ffserver (deprecated / removed)
* documentation, man pages, presets

This directory is a **minimal, deterministic runtime toolchain**.
