# NAADYANTRA — All-screen Light & Dark Background Pack

Contains **14 screen identities × 2 themes = 28 looping GIFs**, plus 28 static PNG fallbacks. Each GIF is 300×667, 16 frames, nominally 110 ms/frame. Original uploaded GIFs are retained for their original theme; matching counterpart variants are included for the opposite theme.

## Folder layout

- `backgrounds/light/`: `<screen>_light.gif`
- `backgrounds/dark/`: `<screen>_dark.gif`
- `backgrounds/fallback/light/`: static first-frame PNGs for light mode
- `backgrounds/fallback/dark/`: static first-frame PNGs for dark mode
- `manifest.json`: complete mapping

## Screens

`splash`, `login`, `home_overview`, `device_inventory`, `device_details`, `inspection`, `sessions`, `session_details`, `events`, `event_details`, `assessments`, `assessment_details`, `settings`, `help_field_guide`.

## Flutter integration

Copy the `backgrounds/` directory into `mobile_app/assets/images/backgrounds/`. In `pubspec.yaml`, make sure `assets/images/backgrounds/` is included under `flutter/assets` (relative to the `mobile_app` package root). Use the active `Theme.of(context).brightness` or the existing app theme provider to choose `light/` or `dark/`. Use fallback PNGs when reduced motion is enabled or GIF rendering is not desired.

Example asset selection (adapt to actual project paths and theme architecture):

```dart
final isDark = Theme.of(context).brightness == Brightness.dark;
final mode = isDark ? 'dark' : 'light';
final path = 'assets/images/backgrounds/$mode/home_overview_$mode.gif';
````

**Important:** A decorative GIF is not telemetry. Never use its motion to imply that the hardware is online or that readings are live. Keep content surfaces sufficiently opaque for text contrast and preserve interactive controls above the background.
