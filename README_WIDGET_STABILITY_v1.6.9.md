# v1.6.9 widget stability update

- Widget parent is now fixed to the Lock Screen dashboard; it no longer follows the cutout host.
- Reordering uses direct dashboard branches for clock, cutout, and notifications.
- Widget reload runs on the main thread and logs all 3 slot type/text values.
- Text changes are re-read from the shared metadata file on every reload.
- The cutout/depth renderer in Tweak.x is unchanged.
