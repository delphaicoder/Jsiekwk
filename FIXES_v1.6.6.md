# v1.6.6

- Three widgets are now laid out horizontally in one group.
- Widget transparency affects only the group background; icons/text stay fully opaque at 0%.
- Widget ordering is explicitly managed as **clock < cutout < widget < notifications** when those views share an ancestor.
- The widget manager can discover the existing cutout host from the stable `DWManager` at runtime without changing the cutout renderer.
- Notification/dashboard layout hooks trigger widget reattachment so the order is refreshed when Lock Screen UI changes.
- No image processing or cutout rendering code was changed.
