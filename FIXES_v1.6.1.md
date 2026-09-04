# DepthWallpaper v1.6.1 Fixes

- Fixed iPad preset ActionSheet crash by providing a popover anchor.
- Fixed log export path/file handling and iPad share-sheet anchoring.
- Fixed Lock Screen Widget refresh: it now listens for the shared Darwin reload notification.
- Improved widget attachment by attaching directly to `SBDashBoardViewController.view` when available, with delayed re-attach and front ordering.
- Cutout engine and `Tweak.x` were not modified.
