# DepthWallpaper v1.6.5

This update keeps the v1.5.6 cutout/depth engine untouched and adds only widget-side functionality.

- The Lock Screen widget is now one grouped container containing three simultaneous widget slots.
- Each slot can independently be Battery, Weather, or Text.
- Weather/Text slots can store their own custom text.
- Widget group transparency is configurable as a numeric percentage from 0 to 100.
- Existing legacy widget settings are migrated as slot 1 when present.
- Widget opacity is applied to the group container without changing cutout rendering.
- Options includes the three widget slot settings and numeric transparency input.
