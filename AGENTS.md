# AGENTS.md

`Stoganet/edge` is infra-as-config for the public-facing edge VPS — see [README.md](README.md) for what it does and how traffic flows through it. Deploys are `git pull` + `docker compose up -d` on the VPS at `/srv/stoganet`, one Compose stack in `compose/netbird/`.

## The one rule that must never break

Never route `netbird.stoganet.com` through `netbird-reverse-proxy` as an ordinary service. It's the mesh's own control-plane transport (management/signal/relay) — routing it as a peer-hop service is self-referential once the proxy owns 80/443, and causes a mesh-wide outage. Traefik terminates TLS for it directly; the reverse-proxy only handles jellyfin/seerr/api.

## Operational commands (run on the VPS)

```bash
NB_SETUP_KEY=... ./compose/setup.sh          # first-time bootstrap
cd /srv/stoganet/compose/netbird && docker compose up -d   # apply changes

docker logs -f traefik
docker logs -f netbird-server
docker logs -f netbird-reverse-proxy
```

## Editing rules of thumb

- Traefik routing is `compose/netbird/traefik/dynamic.yml` — static file, no Docker labels, no Docker socket mount.
- New hostnames on `netbird-reverse-proxy` are added via the NetBird dashboard, not this repo — keep `dynamic.yml`'s `HostSNI` list in sync with what's configured there.
- `netbird-server` is a single combined binary (mgmt + signal + relay + STUN). Router order/specificity in `dynamic.yml` matters: gRPC (`h2c://`) → REST paths → dashboard catch-all.
- `compose/netbird/config.yaml` and `compose/netbird/.env` are gitignored; only `*.example` files are tracked.
- Images pinned by digest (`renovate.json`, `docker:pinDigests`). `netbird-server`/`dashboard`/`traefik` require manual review on minor/major bumps; digest/patch automerge.

## Deploying

Production deploys are a one-click flow in GitHub:

1. Go to **Actions → Deploy** and click **Run workflow** (leave `ref` blank to deploy `main`).
2. Watch the run. The workflow summary reports one of three outcomes:
   - `deploy-ok` — on the target SHA, healthchecks green
   - `rolled-back` — deploy failed, rolled back to the previous SHA, healthchecks green on the previous SHA
   - `MANUAL INTERVENTION REQUIRED` — both deploy and rollback failed; SSH to the VPS to investigate

`main` is "next batch ready to ship" — Renovate auto-merges low-risk PRs there. Nothing is live on the VPS until you click Run workflow. The workflow has no `push` or `pull_request` trigger, so Renovate / Dependabot cannot deploy.

### Manual recovery

If the workflow is wedged or the runner can't reach the VPS, SSH to the VPS as the operator and run the same scripts the workflow runs:

```bash
sudo -iu deploy /srv/stoganet/bin/deploy.sh <sha>
sudo -iu deploy /srv/stoganet/bin/rollback.sh <sha>
```

### One-time VPS bootstrap

Run on the VPS as the operator:

```bash
sudo useradd -m -s /bin/bash -G docker deploy
sudo -u deploy mkdir -p ~deploy/.ssh
sudo chmod 700 ~deploy/.ssh
# Paste the public half of DEPLOY_SSH_KEY into:
sudo -u deploy tee -a ~deploy/.ssh/authorized_keys
sudo chmod 600 ~deploy/.ssh/authorized_keys

sudo chown -R deploy:deploy /srv/stoganet
```

### Required GitHub secrets

| Secret | Value |
| ------ | ----- |
| `NB_SETUP_KEY` | NetBird setup key (reusable + ephemeral, scoped to a `deploy-runners` group with minimal ACL) |
| `DEPLOY_SSH_KEY` | Private half of an ed25519 keypair generated for CI (`ssh-keygen -t ed25519 -f deploy_key -N ""`) |
| `VPS_OVERLAY_IP` | The VPS's NetBird overlay IP |
| `VPS_SSH_HOST_KEY` | Output of `ssh-keyscan -t ed25519 localhost` run on the VPS |
| `NB_MGMT_URL` | `https://netbird.stoganet.com` |
| `HEALTHCHECK_URL_NETBIRD` | A URL that should return a healthy response through Traefik, e.g. `https://netbird.stoganet.com` |
| `HEALTHCHECK_URL_API` | Same, for the api-proxy service |

## Sibling repos (not in this checkout)

- `Stoganet/infra` — home box, its own unrelated Traefik + \*arr + media stack.
- `Stoganet/stogad` — release-please managed; `committing` / `creating-pull-requests` skill conventions apply.
