# NAADYANTRA Cinematic Background GIF Pack

These are ambient, decorative looping background assets for the NAADYANTRA Flutter app. They are designed around the approved industrial ivory / charcoal / burnt-orange identity and a screen-specific visual motif.

## Assets and suggested routes
- `splash.gif` — animated brand-intro atmosphere (`/splash`)
- `login.gif` — quiet industrial horizon (`/login`)
- `home_overview.gif` — abstract acoustic waves (`/`)
- `device_inventory.gif` — technical grid and node pulse (`/devices`)
- `inspection.gif` — decorative oscilloscope/spectrum motif (Inspect tab)
- `device_details.gif` — layered component schematic (`/devices/:deviceId`)
- `sessions.gif` — session timeline (`/sessions`)
- `session_details.gif` — layered chart texture (`/sessions/:sessionId`)
- `events.gif` — vertical event timeline (`/events`)
- `event_details.gif` — radial diagnostic focus (event detail sheet/route if present)
- `assessments.gif` — evaluation layers (`/assessments`)
- `assessment_details.gif` — technical paper/blueprint (`/assessments/:assessmentId`)
- `settings.gif` — mechanical geometry (`/settings`)
- `help_field_guide.gif` — layered guide pages (`/help`)

## Integration recommendation
Place the files in `mobile_app/assets/animations/backgrounds/` and register that folder or the exact asset paths in `pubspec.yaml`. A common `Stack`/background wrapper can show the GIF beneath the existing screen content. Add a translucent ivory or charcoal scrim between background and foreground widgets, tuned per screen, to preserve text contrast and accessibility. Keep the background clipped to the page/safe area where needed.

Example:
```dart
Stack(
  fit: StackFit.expand,
  children: [
    Image.asset(
      'assets/animations/backgrounds/home_overview.gif',
      fit: BoxFit.cover,
      gaplessPlayback: true,
    ),
    ColoredBox(color: Color(0xCCF7F5F0)), // tune per screen
    SafeArea(child: existingPageContent),
  ],
)
```

## Important safety and data-integrity note
All motion in these GIFs is ambient decoration, not sensor output. It must never be presented as a live waveform, device activity, leak detection or a safety signal. Real device status, telemetry freshness and alerts must remain separate, accurately sourced UI components. For `inspection.gif`, avoid using the moving pattern in a way that could be mistaken for captured live acoustic telemetry.

These GIFs are 300 x 667 px looping backgrounds. Static poster images are provided in `posters/` for reduced-motion mode and low-power fallback. Use a translucent themed overlay to tune intensity per page; do not place critical text directly over bright artwork. If performance or battery use is a concern, use a poster or replace the GIF with a lightweight CustomPainter animation.
