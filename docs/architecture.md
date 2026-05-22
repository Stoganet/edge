# Architecture

## The two-host split

```
                        Internet
                            │
                            │  :80 :443 :3478/udp
                            ▼
                ┌───────────────────────┐
                │  edge VPS              │
                │  ─────────────────     │
                │  Caddy (TLS terminator)│
                │  NetBird control plane │
                │    (mgmt + signal +    │
                │     relay + IdP)       │
                │  NetBird agent (peer)  │
                └───────────────────────┘
                            │
                            │  NetBird overlay
                            │  (WireGuard, 100.x.x.x)
                            ▼
                ┌───────────────────────┐
                │  home box              │
                │  ─────────────────     │
                │  Traefik on overlay IP │
                │  Jellyfin, Jellyseerr  │
                │  Sonarr, Radarr,       │
                │  qBittorrent, Gluetun, │
                │  Portainer, …          │
                └───────────────────────┘
```

The edge is the only publicly reachable host. The home box has no inbound ports open — it joins the same NetBird overlay as a peer and Traefik on the home box listens on its overlay IP.

## How public requests reach private services

For a public service like `jellyfin.stoganet.com`:

1. DNS resolves to the VPS public IP.
2. Caddy on the VPS terminates TLS.
3. Caddy reverse-proxies to `https://{NETBIRD_HOME_IP}` (the home box's overlay IP) over the NetBird tunnel, with `Host` and SNI rewritten to `jellyfin.stoganet.com`.
4. Traefik on the home box matches the hostname and routes to the Jellyfin container.

This means the home box's TLS certs and routing rules live in `Stoganet/infra`, not here. The edge only needs to know one overlay IP.

## Why everything else stays NetBird-only

The \*arr stack, qBittorrent, Portainer, and the rest are reachable only by NetBird peers. Adding Jellyseerr was a conscious exception — it needs to accept requests from non-peer users who can authenticate via Jellyfin. Adding more services means adding a Caddy block here *and* accepting the resulting public surface.

## NetBird dogfooding

The same NetBird control plane that the home box and other peers use is the one this VPS hosts. The VPS runs both:

- The **server** (`netbird-server` + `netbird-dashboard` containers, embedded IdP)
- The **agent** (system service installed by `setup.sh`, joins the overlay as a peer)

The agent is what gives Caddy a route to the home box. If the control plane is down, existing peer connections keep working (NetBird sets up direct WireGuard tunnels and only needs the control plane for new peers and key rotation), but no new connections can be established.

## State that lives outside this repo

- `/etc/netbird/` — NetBird agent state (machine token, peer identity). Managed by the agent.
- `/var/lib/netbird/` — agent runtime data.
- Docker volume `netbird_netbird_data` — control-plane sqlite (users, peers, setup keys). Not currently backed up.
- `compose/caddy_data/` — issued certificates and ACME account key.
