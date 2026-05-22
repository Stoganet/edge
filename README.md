# Stoganet/edge

Public-facing edge proxy for the Stoganet home infrastructure. Runs on a small VPS and:

- Terminates TLS for `*.stoganet.com`
- Hosts the self-hosted NetBird control plane (management, signal, relay, STUN, dashboard, embedded IdP)
- Reverse-proxies the few public services (Jellyfin, Jellyseerr) back to the home box over the NetBird overlay

The home box and all of the \*arr stack stay behind NetBird — they are never directly exposed to the internet.

## Layout

```
edge/
├── compose/      Docker Compose stack (Caddy + self-hosted NetBird control plane)
└── docs/         Architecture notes
```

## Deploy

```
git clone https://github.com/Stoganet/edge.git /srv/stoganet
cd /srv/stoganet/compose

cp services.env.example .env
$EDITOR .env

cp netbird/config.yaml.example netbird/config.yaml
$EDITOR netbird/config.yaml          # set authSecret, encryptionKey, exposedAddress, auth.issuer

NB_SETUP_KEY=... ./setup.sh          # Docker, NetBird agent + join, UFW, proxy-net, /var/log/caddy

docker compose up -d                 # caddy
cd netbird && docker compose up -d   # netbird control plane
```

The VPS joins its own NetBird overlay as a peer — that overlay IP is what Caddy uses to reach the home box for the Jellyfin/Jellyseerr reverse proxies.

## Public surface

| Port      | Service                               |
| --------- | ------------------------------------- |
| 80, 443   | Caddy (all `*.stoganet.com` hosts)    |
| 3478/udp  | NetBird STUN                          |
| 22        | SSH                                   |

Everything else is NetBird-only.
