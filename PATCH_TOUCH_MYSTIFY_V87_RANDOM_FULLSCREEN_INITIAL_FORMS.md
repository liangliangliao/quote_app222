V87 - Touch Mystify random fullscreen initial forms

Scope:
- `android/app/src/main/java/com/example/quote_app/wallpaper/IntimacyMystifyWallpaperService.java`
- `lib/pages/touch_mystify_wallpaper_page.dart`

Changes:
1. Reworked the subject birth logic so the initial subject is no longer limited to a dot or short line.
   Each write cycle now starts from one of ten visible initial forms:
   - long line
   - triangular/wedge membrane
   - leaf/ellipse seed surface
   - arc / hook plate
   - comb-like line bundle
   - diamond / polygon patch
   - spiral curl
   - bifurcated open membrane
   - ring / aperture form
   - irregular soft patch
2. Added an explicit OpenGL initial-form layer (`drawInitialSubjectForm`) so early frames have real geometry and surface area before the complex flow-field body takes over.
3. Made every write cycle choose a random on-screen spawn location using `fullScreenCoverage`, including lower-screen regions that were previously under-used.
4. Made roaming paths, calm anchors, spawn points, span, and fan height respond to the actual phone Surface size and the full-screen coverage setting.
5. Added scale fitting against the current Surface dimensions so large subjects fill the screen without being severely clipped on tall portrait phones.
6. Updated the settings preview frame to use the real device portrait aspect ratio instead of a fixed 9:13 card, making the preview closer to the applied live wallpaper.

Validation:
- Java source syntax was checked by compiling `IntimacyMystifyWallpaperService.java` with local Android/EGL stubs via `javac`.
- Full Gradle/Flutter build could not be run in this environment because the package does not include `gradle-wrapper.jar` and the wrapper attempted to download it from the network, which is unavailable here.
