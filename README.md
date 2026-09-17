# 360 to UE Previs

A Mac-first pipeline for turning 360° location scans into Gaussian Splat environments for cinematography previs in Unreal Engine.

Designed around:

**Insta360 → COLMAP → Brush → Gaussian Splat PLY → Unreal Engine → CineCamera**

The goal is not photogrammetry for archival scanning. The goal is a fast, repeatable way for cinematographers and filmmakers to bring a real location into Unreal Engine and start testing lenses, camera positions, blocking, lighting direction, and shot design.

---

## Pipeline

```text
Insta360 / 360 Camera
        ↓
8K 2:1 Equirectangular Video
        ↓
360_TO_UE.command
        ↓
Adaptive Panorama Extraction
        ↓
12-view Virtual Camera Rig
        ↓
COLMAP / PyCOLMAP
        ↓
Brush
        ↓
Gaussian Splat .PLY
        ↓
Unreal Engine
        ↓
Harmony Gaussian Splat Renderer
        ↓
Scale Calibration
        ↓
CineCamera Previs
Why?
Traditional location previs often means rebuilding a location manually, using rough geometry, or relying on reference photos.
This workflow uses a small 360 camera to capture the location and reconstructs it as a Gaussian Splat.
Once inside Unreal Engine, the scan can be combined with:
- CineCamera Actors
- real lens focal lengths
- actor blocking
- production design proxies
- sun studies
- lighting positions
- dolly / crane / tripod positions
- Sequencer
- shot planning
The emphasis is on cinematography and techvis, rather than creating a perfect 3D asset.
Current Platform
The workflow has been tested on:
- Apple Silicon Mac
- macOS
- Insta360 X4 Air
- 8K 2:1 equirectangular video
- Python 3.12
- PyCOLMAP / COLMAP
- Brush
- Unreal Engine 5.8
- Harmony Gaussian Splat renderer
Other 360 cameras should work if they can export a standard 2:1 equirectangular video.
Presets
The script automatically chooses extraction FPS based on video duration.
Instead of using a fixed FPS, each preset targets a useful number of real panorama positions.
FAST
Approximately:
120 panoramas
1440 virtual views
Brush 7,500 steps
1920 max resolution
Best for:
- rough blocking
- quick scouts
- checking basic camera positions
NORMAL
Recommended default.
Approximately:
250 panoramas
3000 virtual views
Brush 15,000 steps
2560 max resolution
Best for:
- cinematography previs
- CineCamera work
- lens testing
- blocking
- most location scouts
QUALITY
Approximately:
500 panoramas
6000 virtual views
Brush 20,000 steps
3072 max resolution
Best for:
- important locations
- more detailed previs
- presentation-quality scouting
Large datasets can take several hours.
Preflight
Before processing, the script checks the source video and displays:
File
Duration
Resolution
360 format validation
Selected preset
Adaptive extraction FPS
Estimated panoramas
Estimated virtual views
Brush settings
Estimated COLMAP time
Estimated Brush time
Estimated total time
The ETA is currently an approximate model based on real Apple Silicon tests and should be treated as a planning estimate rather than a guaranteed completion time.
Capture
Export a full 360° video from Insta360 Studio.
Recommended:
Resolution: highest practical resolution
Projection: Equirectangular
Aspect ratio: 2:1
Movement: slow and smooth
Exposure: locked when possible
For reconstruction quality, camera movement matters more than simply recording for a long time.
Walk around the important shooting area rather than only walking in a straight line.
More capture guidance is coming in:
docs/CAPTURE_GUIDE.md
Quick Start
Install the dependencies first.
Then make the script executable:
chmod +x 360_TO_UE.command
Run it:
./360_TO_UE.command
Or drag an exported 360 video onto the .command file in Finder.
Choose:
1 — FAST
2 — NORMAL
3 — QUALITY
The final file will be exported into:
UE_PREVIS_OUTPUT/
with a name similar to:
LOCATION_NORMAL_UE.ply
Unreal Engine
The current UE workflow uses the Harmony Gaussian Splat renderer.
Import the generated .ply into the previs project and place the resulting Harmony actor in the level.
For image quality, do not confuse these two controls:
Actor Transform Scale
controls the physical size of the scanned location.
Gaussian Splat → Splat Scale
controls the rendered size of individual splats.
A lower Splat Scale can make the reconstruction appear sharper, although values that are too low may reveal holes.
Real-World Scale
COLMAP reconstruction does not automatically guarantee real-world absolute scale.
For cinematography previs, scale accuracy matters.
The current workflow uses a:
2.5 meter calibration reference
Measure or place a known 2.5 m reference at the real location.
Inside Unreal Engine, uniformly adjust the Harmony Actor Transform Scale until the same reference measures:
250 cm
After calibration:
1 Unreal Unit = 1 cm
This makes camera distance, actor height, production design proxies, and lens testing much more meaningful.
Brush
Brush is used for Gaussian Splat training and PLY export.
The pipeline runs Brush from the command line, so the GUI does not need to stay open during automated processing.
Brush is a separate project and is not distributed by this repository.
COLMAP 360 Rig
A 360 panorama does not behave like a normal perspective photograph.
This workflow converts each panorama into a virtual multi-camera perspective rig before COLMAP reconstruction.
The current setup uses:
12 virtual perspective views per panorama
Camera poses are reconstructed and converted back into a dataset suitable for Brush.
Important
This repository does not include or redistribute:
- COLMAP
- PyCOLMAP
- Brush
- Harmony
- Unreal Engine
- Insta360 Studio
They remain separate projects with their own licenses.
Project Status
Early working version.
The full pipeline has successfully completed:
360 video
→ panorama extraction
→ 12-view conversion
→ COLMAP reconstruction
→ Brush training
→ PLY export
→ Harmony
→ Unreal Engine 5.8
Future improvements:
- better runtime ETA
- saved machine benchmarks
- automatic ETA calibration
- progress display
- configurable presets
- easier dependency installation
- optional UE project template
- improved capture validation
Intended Use
Built primarily for:
- cinematographers
- directors
- VFX / virtual production
- location scouts
- production designers
- previs artists
- film students
The project is especially focused on small film crews that want a lightweight alternative to dedicated LiDAR or photogrammetry capture systems.
License
MIT License.
Third-party dependencies retain their respective licenses.
