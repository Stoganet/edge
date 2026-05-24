#!/usr/bin/env bash
set +e

echo "### VPS HEAD"
echo '```'
git -C /srv/stoganet rev-parse HEAD
echo '```'
echo

echo "### docker compose ps (caddy)"
echo '```'
docker compose -f /srv/stoganet/compose/docker-compose.yml ps
echo '```'
echo

echo "### docker compose ps (netbird)"
echo '```'
docker compose -f /srv/stoganet/compose/netbird/docker-compose.yml ps
echo '```'
echo

echo "### docker logs --tail 50 caddy"
echo '```'
docker logs --tail 50 caddy
echo '```'
echo

echo "### docker logs --tail 50 netbird-server"
echo '```'
docker logs --tail 50 netbird-server
echo '```'
