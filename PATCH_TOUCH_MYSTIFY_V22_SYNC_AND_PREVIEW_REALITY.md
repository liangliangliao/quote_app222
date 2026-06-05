# V22 - Settings sync and preview reality fix

This patch addresses two issues:

1. App preview and actual live wallpaper look very different because they are rendered by different engines:
   - Flutter page: CustomPainter demonstration preview.
   - Actual wallpaper: Android native OpenGL/FBO renderer.
   They cannot be guaranteed identical until the preview is also changed to use the same native renderer.

2. Settings synchronization:
   - Save now uses SharedPreferences.commit() rather than apply(), so the wallpaper renderer can read changes immediately.
   - A SharedPreferences listener is registered inside the live wallpaper render thread.
   - When config changes, the renderer reloads config, clears old FBO residue, resets strokes, and applies new visual parameters without re-applying the wallpaper.

Also fixes a ratio normalization bug: ratioRelease was divided by the sum twice.

Important: exact visual parity still requires replacing Flutter CustomPainter preview with a native OpenGL preview using the same renderer path as the wallpaper.
