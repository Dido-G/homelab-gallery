# frontend/ — Phase 2 (placeholder)

Custom gallery UI built **on top of Immich's REST API**. Nothing here yet —
Phase 1 is getting Immich itself running and backing up the phone.

## Rules
- Talk to Immich only through `/api/*` with an API key (or a user session).
- Never read or write `UPLOAD_LOCATION` (`D:\homelab\gallery`) directly — Immich owns it.
- Never commit the API key. Read it from config at runtime / build time.

## Planned features
- [ ] Cinematic horizontal timeline with parallax
- [ ] GPS map view (Leaflet.js + OpenStreetMap tiles; Mapbox optional)
- [ ] Masonry grid with hover zoom + caption fade-in
- [ ] Full-screen ambient slideshow / screensaver (Ken Burns + crossfades),
      fed by `scripts/memories.py` output
- [ ] Mobile browser upload button (no-app fallback) → `POST /api/assets`

## Open decisions
- **Stack:** React + Vite vs. plain HTML/JS. Decide when starting Phase 2.
- **Same-origin serving:** a browser app on a different port than Immich will hit
  CORS. Plan is to serve the frontend and proxy `/api` to `immich-server:2283`
  from one small container (e.g. Caddy or nginx) added to `docker-compose.yml`.
  See `docs/architecture.md`.
- **Auth:** a shared read-only API key baked into a LAN-only page is simplest;
  logging in per user via Immich's `/api/auth/login` is safer if it's ever exposed.
