# Troubleshooting

These notes include issues encountered while developing the Apple Silicon workflow.

## Metal Toolchain Missing

Possible Unreal error:

    cannot execute tool 'metal' due to missing Metal Toolchain

Install it with:

    xcodebuild -downloadComponent MetalToolchain

Verify:

    xcrun -f metal

## Unreal Rejects the macOS SDK

Possible error:

    Platform Mac is not a valid platform to build.
    SDK validation failed.

Check:

    xcodebuild -version
    xcrun --sdk macosx --show-sdk-version

### Advanced / Unsupported Workaround

During development, UE 5.8 was successfully compiled after increasing the accepted MaxVersion in:

    Engine/Config/Apple/Apple_SDK.json

This is not an officially supported compatibility fix.

Back up the file first.

Do not automate this modification.

Bypassing the version check does not guarantee that a newer compiler or SDK is actually compatible.

Prefer an officially supported Unreal/Xcode combination when practical.

## Couldn't Find Target Rules File

This may occur with a Blueprint-only project.

In Unreal:

    Tools -> New C++ Class

Create a minimal class.

This generates the Source directory and Editor target files required for plugin compilation.

## Brush Command Not Found

If:

    which brush

returns nothing, Brush may still be installed.

The tested executable was:

    /Applications/brush-app-aarch64-apple-darwin/brush_app

Verify:

    /Applications/brush-app-aarch64-apple-darwin/brush_app --help

## Unreal Looks Softer Than Brush

Select:

    HarmonyActor
    -> GaussianSplatComponent
    -> Gaussian Splat
    -> Splat Scale

Try:

    1.0 -> 0.8 -> 0.6

Do not use Actor Transform Scale to sharpen the reconstruction.

## COLMAP Appears Frozen

During:

    Retriangulation and Global bundle adjustment

COLMAP may produce no Terminal output for a long time.

This does not necessarily mean it has crashed.

Check CPU activity before terminating the process.

## Processing Takes Too Long

Avoid using a fixed high extraction FPS for long videos.

Use the adaptive presets:

    FAST      ~120 panoramas
    NORMAL    ~250 panoramas
    QUALITY   ~500 panoramas

NORMAL is recommended for most cinematography previs.

## Invalid 360 Input

The source must be full equirectangular:

    width = 2 x height

Examples:

    7680 x 3840
    5760 x 2880

A normal 16:9 reframed Insta360 export is not suitable.
