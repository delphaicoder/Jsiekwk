# DepthWallpaper v1.6.2

Fixed the DWWidget.x compile error caused by accessing `self.view` through the forward-declared `SBDashBoardViewController` class. The three `self.view` accesses in the widget hook now cast `self` to `UIViewController *` first. The cutout/depth engine and the rest of the source are unchanged.
