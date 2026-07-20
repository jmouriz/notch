# Notch

[![CI](https://github.com/jmouriz/notch/actions/workflows/ci.yml/badge.svg)](https://github.com/jmouriz/notch/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black.svg)](https://www.apple.com/macos/)

Notch es un editor nativo para macOS que permite importar audio local o desde
YouTube, seleccionar múltiples fragmentos sobre la forma de onda,
previsualizarlos y exportarlos como archivos independientes.

## Funcionalidades

- Importación de audio y video local.
- Descarga desde YouTube mediante `yt-dlp`.
- Caché configurable para evitar descargas repetidas.
- Forma de onda real, zoom, cabezal y reproducción.
- Selección, movimiento y ajuste preciso de múltiples recortes.
- Campos de tiempo editables y nombres individuales.
- Exportación a M4A, MP3 y WAV.
- Tres convenciones configurables para nombres y subcarpetas.
- Proyectos JSON con extensión `.notch`.
- Biblioteca persistente de proyectos recientes y conservados.
- Configuración nativa para caché, biblioteca y exportaciones.
- Interfaz en inglés, español y portugués, con detección automática del idioma
  de macOS y selección manual desde Configuración.

## Requisitos

- macOS 14 o posterior.
- Apple Silicon para la distribución precompilada actual.
- Xcode con Swift 6 para compilar el proyecto.

## Ejecutar desde el código fuente

```bash
git clone https://github.com/jmouriz/notch.git
cd notch
swift run Notch
```

También se puede abrir `Package.swift` directamente con Xcode y ejecutar el
esquema `Notch`.

## Pruebas

```bash
swift test
```

Las pruebas cubren importación, caché, reproducción, selección temporal,
proyectos, biblioteca, preferencias, traducciones y exportaciones reales en
los tres formatos.

## Crear la aplicación y el DMG

```bash
./Packaging/package-release.sh
```

El script genera:

```text
build/Notch.app
build/Notch-0.1.0.dmg
```

El paquete de desarrollo utiliza firma ad hoc. Para distribuir públicamente se
debe configurar una identidad Developer ID y notarizar la aplicación.

## Atajos

| Acción | Atajo |
| --- | --- |
| Nuevo proyecto | `⌘N` |
| Abrir proyecto | `⌘O` |
| Abrir audio o video | `⇧⌘O` |
| Guardar proyecto | `⌘S` |
| Guardar como | `⇧⌘S` |
| Configuración | `⌘,` |
| Nueva región | `⌘R` |
| Previsualizar región | `Espacio` |

## Componentes incluidos

- [yt-dlp](https://github.com/yt-dlp/yt-dlp), publicado bajo The Unlicense.
- [LAME](https://lame.sourceforge.io/), publicado bajo GNU LGPL 2.0.

FFmpeg no está incluido ni se invoca en esta versión. M4A y WAV utilizan los
frameworks multimedia nativos de macOS. Los avisos y textos completos están en
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Licencia

Notch está publicado bajo la [licencia MIT](LICENSE).

Copyright © 2026 Juan Manuel Mouriz.
