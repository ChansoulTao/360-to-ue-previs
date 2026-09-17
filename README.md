# 360 to UE Previs

A Mac-first pipeline for turning 360° location captures into Gaussian Splat environments for cinematography previs in Unreal Engine.

**360 Camera → COLMAP → Brush → Gaussian Splat → Unreal Engine → CineCamera**

> Built for cinematographers, directors, location scouts, virtual production and small film crews who want to bring a real location into Unreal Engine quickly.

## Workflow

**360 Camera**  
↓  
**8K 2:1 Equirectangular Video**  
↓  
**Adaptive Panorama Extraction**  
↓  
**12-view Virtual Camera Rig**  
↓  
**COLMAP / PyCOLMAP**  
↓  
**Brush**  
↓  
**Gaussian Splat `.PLY`**  
↓  
**Unreal Engine + Harmony**  
↓  
**Real-world Scale Calibration**  
↓  
**CineCamera Previs**

## What is this for?

Traditional location previs often means rebuilding a location manually, working from reference photos, or using rough geometry.

This workflow captures the real location with a small 360 camera and reconstructs it as a Gaussian Splat.

Once the location is inside Unreal Engine, you can use it for:

- CineCamera placement
- real focal-length testing
- actor blocking
- production-design proxies
- sun studies
- lighting positions
- dolly / crane / tripod planning
- Sequencer
- shot design

The goal is **useful cinematography previs**, not archival-quality photogrammetry.

## Quick Start

### 1. Capture

Record the location with a 360 camera and export a full equirectangular video.

The input must be **2:1**.

Examples:

- `7680 × 3840`
- `5760 × 2880`

A normal reframed 16:9 export will not work.

### 2. Run

Make the launcher executable:

    chmod +x 360_TO_UE.command

Then run:

    ./360_TO_UE.command

You can also drag a compatible video onto `360_TO_UE.command` in Finder.

### 3. Choose a preset

| Preset | Target Panoramas | Virtual Views | Brush | Best For |
|---|---:|---:|---:|---|
| FAST | ~120 | ~1,440 | 7.5k / 1920 | Rough blocking |
| NORMAL | ~250 | ~3,000 | 15k / 2560 | Most previs |
| QUALITY | ~500 | ~6,000 | 20k / 3072 | Important locations |

**NORMAL is the recommended default.**

The extraction FPS is calculated automatically from the duration of the video.

A 10-minute video therefore does not accidentally create a massive dataset just because a fixed 2 FPS setting was used.

## Preflight

Before processing, the script displays:

- source filename
- duration
- resolution
- 2:1 validation
- selected preset
- adaptive extraction FPS
- estimated panorama count
- estimated virtual-view count
- Brush settings
- estimated COLMAP time
- estimated Brush time
- estimated total runtime

Runtime estimates are currently approximate and scene-dependent.

## Output

Successful processing produces a file similar to:

`UE_PREVIS_OUTPUT/LOCATION_NORMAL_UE.ply`

The intermediate Brush dataset is kept so higher-quality training can be performed later without repeating the entire reconstruction.

## Unreal Engine

The current workflow uses the **Harmony Gaussian Splat renderer**.

Import the generated `.ply`, place the Harmony Actor in the level, and begin building the previs around it.

### Splat Scale vs Transform Scale

These are different controls.

**Transform Scale** changes the physical size of the reconstructed location.

Use it for real-world calibration.

**Splat Scale** changes the rendered size of individual Gaussian splats.

If Unreal looks softer than Brush, try reducing Splat Scale:

`1.0 → 0.8 → 0.6 → 0.4`

Smaller values can look sharper, but values that are too low may reveal holes.

## Real-world Scale

COLMAP does not automatically guarantee absolute real-world scale.

The current workflow uses a known:

**2.5 m reference**

Inside Unreal Engine, uniformly scale the Harmony Actor until the same reference measures:

**250 cm**

After calibration:

**1 Unreal Unit = 1 cm**

This makes camera distance, actor height, lens tests and production-design proxies much more meaningful.

## Capture Strategy

For reconstruction, **coverage and parallax matter more than recording a very long video**.

For an important shooting area, consider capturing:

1. an outer loop
2. an inner loop
3. a pass through the main actor / camera area
4. additional coverage around important camera positions

Try to minimize moving people, vehicles and close moving foliage.

## Tested Setup

The initial working pipeline was developed and tested with:

- Apple Silicon Mac
- macOS
- Insta360 X4 Air
- 8K 2:1 equirectangular video
- Python 3.12
- COLMAP / PyCOLMAP
- Brush
- Unreal Engine 5.8
- Harmony Gaussian Splat renderer

Other 360 cameras should work if they can export a standard full 2:1 equirectangular video.

## Documentation

Detailed guides:

- [macOS Installation](docs/INSTALL_MAC.md)
- [360 Capture Guide](docs/CAPTURE_GUIDE.md)
- [Unreal Engine Setup](docs/UNREAL_SETUP.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

## Dependencies

This repository does not redistribute:

- COLMAP
- PyCOLMAP
- Brush
- Harmony
- Unreal Engine
- Insta360 Studio

These remain separate projects with their own licenses.

## Project Status

**Early working release.**

The complete workflow has been tested end-to-end:

**360 video → panorama extraction → virtual camera rig → COLMAP → Brush → PLY → Harmony → Unreal Engine**

Planned improvements include:

- machine-specific benchmark history
- self-calibrating ETA
- better live progress reporting
- configurable presets
- easier dependency installation
- optional Unreal previs template
- improved capture validation

## License

MIT License. See [LICENSE](LICENSE).

Third-party dependencies retain their respective licenses.
