# DepthWallpaper v1.6.0

## New features
- Saved Depth Presets: save/load/delete up to 20 configurations. Presets copy the existing wallpaper, cutout PNG and metadata; the cutout renderer itself is unchanged.
- Options panel: diagnostics/log export moved here.
- Experimental Lock Screen Widget: Battery, manual Weather text, or Custom Text. The widget is implemented in a separate `DWWidget.x` component so `Tweak.x` (stable cutout engine) is untouched.

## Important
Weather is intentionally manual in this build: iOS 15 does not provide a simple public weather API suitable for a rootless tweak. Enter a value such as `27°C` in Options. Battery updates from the device battery level.

## Preset limit
Maximum 20 saved presets. Each preset stores the current files and metadata only; it does not re-process the cutout.
