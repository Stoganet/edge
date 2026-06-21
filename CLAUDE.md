# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`Stoganet/edge` is the public-facing edge for the Stoganet home infra. It is **infra-as-config**, not application code — there is nothing to build, lint, or test. Changes are deployed by `git pull` + `docker compose up -d` on the VPS at `/srv/stoganet`.

Two Compose stacks live in `compose/`, sharing an external Docker network `proxy-net`:

- `compose/docker-compose.yml` — Caddy (TLS terminator, reverse proxy)
- `compose/netbird/docker-compose.yml` — self-hosted NetBird control plane (`netbird-server` combined mgmt+signal+relay+STUN, plus `netbird-dashboard`)

The VPS also runs the NetBird **agent** as a system service (installed via `compose/setup.sh`), so it joins its own overlay as a peer. That overlay IP is how Caddy reaches the home box.

## The architecture in one paragraph

Only the edge VPS is publicly reachable (ports 80/443/3478udp/22). Public requests for `*.stoganet.com` hit Caddy, which either serves the NetBird control plane directly (`netbird.stoganet.com`) or reverse-proxies over the NetBird WireGuard overlay to `https://${NETBIRD_HOME_IP}` (the home box), rewriting `Host` and SNI so Traefik on the home box can route to the right container. The home box has no inbound ports open. State that lives outside this repo: `/etc/netbird/`, `/var/lib/netbird/`, Docker volume `netbird_netbird_data`, `compose/caddy_data/`.

## Operational commands (run on the VPS)

```bash
# First-time bootstrap (Docker, NetBird agent + overlay join, SSH hardening, UFW, proxy-net, /var/log/caddy)
NB_SETUP_KEY=... ./compose/setup.sh

# Apply changes
cd /srv/stoganet/compose         && docker compose up -d   # caddy
cd /srv/stoganet/compose/netbird && docker compose up -d   # control plane

# Reload Caddy config without restart
docker exec caddy caddy reload --config /etc/caddy/Caddyfile

# Validate Caddyfile before reloading
docker exec caddy caddy validate --config /etc/caddy/Caddyfile

# Logs
docker logs -f caddy
docker logs -f netbird-server
tail -f /var/log/caddy/jellyfin.log
```

## Editing rules of thumb

- **Adding a public hostname** requires *both* a Caddy block in `compose/Caddyfile` *and* a conscious decision to widen the public surface. Most services should stay NetBird-only — Jellyseerr is the intentional exception because it needs unauthenticated users to reach it.
- **Reverse proxies to the home box** use the pattern in the existing `jellyfin` / `seerr` blocks: `reverse_proxy https://{$NETBIRD_HOME_IP}` with `header_up Host` and `tls_server_name` rewritten to the public hostname so Traefik on the home box matches it.
- **`netbird-server` is a single combined binary** (mgmt + signal + relay + STUN). The Caddy block for `netbird.stoganet.com` routes gRPC via `h2c://`, the `/relay /ws-proxy /api /oauth2` paths to the server, and everything else to the dashboard — order matters.
- The two compose stacks talk to each other only via the external `proxy-net` network. Don't inline either stack into the other.
- `compose/netbird/config.yaml` and `compose/.env` are gitignored; only `*.example` files are tracked. Don't commit real secrets, domains, or overlay IPs.

## Sibling repos (not in this checkout)

- `Stoganet/infra` — home box (Traefik + \*arr + media stack). TLS certs and per-service routing for everything proxied through here live there, not here.
- `Stoganet/stogad` — release-please managed; commit/PR conventions in the `committing` and `creating-pull-requests` skills apply across the org.
