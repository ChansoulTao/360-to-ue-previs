# Unreal Engine Setup

The tested workflow uses Unreal Engine 5.8 with the Harmony Gaussian Splat renderer.

## Harmony

Install Harmony inside the Unreal project:

    YourProject/
      Plugins/
        Harmony/
          Harmony.uplugin

Compile the project and open:

    Edit -> Plugins

Search for Harmony.

The intended plugin is the Gaussian splat renderer by Spacemonster, not Epic's Harmonix audio plugin.

## Import

The pipeline generates a file similar to:

    UE_PREVIS_OUTPUT/LOCATION_NORMAL_UE.ply

Import the PLY into Unreal and place the resulting Harmony Actor into the Level.

## Splat Scale

Select the Harmony Actor.

In Details, select:

    GaussianSplatComponent

Search for:

    scale

You should see both Transform Scale and Gaussian Splat -> Splat Scale.

They are different.

Transform Scale controls the physical size of the entire location.

Splat Scale controls the rendered size of individual Gaussian splats.

If Unreal looks softer than Brush, try:

    1.0
    0.8
    0.6
    0.4

Lower values can appear sharper but may reveal holes.

## Real-World Calibration

The default reference is:

    2.5 m = 250 cm

Find the measured A-B reference inside the scan.

Uniformly adjust the Harmony Actor Transform Scale until that distance measures 250 cm in Unreal.

Do not scale only one axis.

After calibration:

    1 Unreal Unit = 1 cm

Camera distance, actor height, lens tests, and production-design proxies now become much more useful.

## Suggested Previs Template

A reusable previs project can include:

- Harmony
- CineCamera Actors
- common camera sensor presets
- 24 / 28 / 32 / 40 / 50 / 75 mm lens presets
- 1.75 m human proxy
- 4x4 / 8x8 / 12x12 frame proxies
- tripod and dolly proxies
- lighting stand proxies
- Sun / Sky
- Sequencer

The repeatable workflow then becomes:

    PLY -> Import -> Scale Calibration -> Camera / Blocking -> Previs
