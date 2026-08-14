# Project Skyroll 1.0 release checklist

## Completed in the release candidate

- 30 validated and reachable levels across three visually distinct worlds.
- Authored Blender models for blocks, tile states, Aeri, collectibles, portals, clouds, and landmarks.
- Branded application icon, boot splash, credits and license notice.
- Keyboard and gamepad controls, rebinding, audio settings, fullscreen, pause, save migration, progression, and achievements adapter.
- Deterministic art build, 1,699 automated assertions, Windows export, and executable smoke test.
- Runtime package excludes tests, tools, previews, reports, Blender sources, reference textures, and recoverable legacy assets.

## Store-owner actions before publishing

- Replace the offline platform adapter with the chosen Steamworks or storefront SDK adapter if platform achievements are required.
- Add the publisher's legal name, copyright line, support URL, privacy policy, and store-specific identifiers.
- Prepare store capsule art, screenshots, trailer, localized copy, pricing, age ratings, and accessibility disclosures.
- Code-sign the Windows executable if the publisher owns a signing certificate.
- Run a final controller and fullscreen playthrough on at least one second Windows machine.
