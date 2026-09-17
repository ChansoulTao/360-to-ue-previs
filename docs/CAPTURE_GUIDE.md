# 360 Capture Guide

This capture strategy is optimized for cinematography previs rather than archival scanning.

## Camera

The workflow was developed with an Insta360 X4 Air.

Other 360 cameras should work if they can export a standard full 2:1 equirectangular video.

## Recommended Capture

- Use the highest practical 360 resolution.
- Move slowly and smoothly.
- Lock exposure when practical.
- Keep both lenses clean.
- Avoid excessive motion blur.
- Minimize moving people and vehicles.
- Avoid very close moving foliage when possible.

## Capture Path

Do not simply walk in a straight line.

For an important shooting area, consider:

1. An outer loop.
2. An inner loop.
3. A pass through the main actor and camera area.
4. Extra coverage around important camera positions.

Spatial parallax is more valuable than simply recording a very long video.

## Adaptive Panorama Count

The pipeline does not use a fixed extraction FPS.

Instead it targets approximately:

- FAST: 120 panoramas
- NORMAL: 250 panoramas
- QUALITY: 500 panoramas

Each panorama becomes 12 virtual perspective views for COLMAP.

NORMAL is recommended for most cinematography previs.

## Scale Reference

Measure a known real-world distance during the scout.

The current default is:

2.5 meters

Later, calibrate this distance to 250 cm inside Unreal Engine.

## What Matters Most

For previs, prioritize reliable reconstruction of:

- architecture
- terrain
- roads
- walls
- horizon
- major set pieces
- camera-accessible areas

Perfect grass, leaves, and fine vegetation are usually less important than useful spatial relationships.
