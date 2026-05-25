#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run as a regular user with sudo, not as root directly." >&2
    exit 1
fi

COMPOSE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$COMPOSE_DIR"

echo "==> Installing Docker"
if ! command -v docker >/dev/null; then
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker "$USER"
    echo "    Added $USER to docker group. Log out/in for it to take effect."
fi

echo "==> Installing NetBird agent"
if ! command -v netbird >/dev/null; then
    curl -fsSL https://pkgs.netbird.io/install.sh | sudo sh
fi

echo "==> Joining NetBird overlay"
if ! sudo netbird status >/dev/null 2>&1; then
    if [[ -z "${NB_SETUP_KEY:-}" ]]; then
        echo "    Set NB_SETUP_KEY (one-time setup key from the NetBird dashboard) and re-run." >&2
        exit 1
    fi
    sudo netbird up \
        --management-url https://netbird.stoganet.com \
        --setup-key "$NB_SETUP_KEY"
fi

echo "==> Configuring UFW"
if command -v ufw >/dev/null; then
    sudo ufw allow 22/tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow 3478/udp
    sudo ufw --force enable
fi

echo "==> Creating shared docker network 'proxy-net'"
docker network inspect proxy-net >/dev/null 2>&1 || docker network create proxy-net

echo "==> Creating /var/log/caddy"
sudo mkdir -p /var/log/caddy
sudo chown 1000:1000 /var/log/caddy

# Caddy runs as root inside the container with cap_drop: ALL, which removes
# DAC_OVERRIDE — so root-in-container cannot bypass host file permissions.
# The bind-mounted data/config dirs must therefore be owned by root on the host.
echo "==> Ensuring caddy_data and caddy_config are root-owned"
sudo mkdir -p "$COMPOSE_DIR/caddy_data" "$COMPOSE_DIR/caddy_config"
sudo chown -R root:root "$COMPOSE_DIR/caddy_data" "$COMPOSE_DIR/caddy_config"

echo "==> Done. Next:"
echo "    1. cp services.env.example .env  &&  \$EDITOR .env"
echo "    2. cp netbird/config.yaml.example netbird/config.yaml  &&  \$EDITOR netbird/config.yaml"
echo "    3. docker compose up -d"
echo "    4. cd netbird && docker compose up -d"
