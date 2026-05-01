# Apps

This folder defines the intended production app boundaries.

Current runtime source still lives in the Flutter root layout because the active package, generated files, CI, Firebase, Cloudflare, and Supabase scripts depend on those paths.

- `mobile/`: native Flutter Android/iOS app boundary.
- `pwa/`: passenger/driver Flutter web PWA boundary.
- `admin/`: admin PWA/panel boundary.
- `website/`: public marketing and policy site boundary.
- `venue-dashboard/`: future venue/cooperative dashboard boundary.
- `agent-console/`: future operator/agent console boundary.

Do not add runtime code here until the Flutter workspace/package migration is planned and tested.
