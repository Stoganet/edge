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

echo "==> Hardening SSH"
SSHD_DROP_IN=/etc/ssh/sshd_config.d/99-stoganet-hardening.conf
sudo tee "$SSHD_DROP_IN" > /dev/null <<'SSHEOF'
PasswordAuthentication no
PermitRootLogin no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
SSHEOF
sudo chmod 644 "$SSHD_DROP_IN"
# Validate before reloading to avoid locking ourselves out
if sudo sshd -t; then
    sudo systemctl reload sshd
    echo "    SSH hardened and reloaded."
else
    echo "    sshd config test failed — drop-in written but NOT reloaded. Fix manually." >&2
fi

echo "==> Configuring UFW"
if command -v ufw >/dev/null; then
    sudo ufw allow 22/tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow 3478/udp
    sudo ufw --force enable
fi

echo "==> Done. Next:"
echo "    1. cd netbird && cp .env.example .env  &&  \$EDITOR .env"
echo "    2. cp config.yaml.example config.yaml  &&  \$EDITOR config.yaml"
echo "    3. docker compose up -d"
