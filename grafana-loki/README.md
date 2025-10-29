# Loki + Promtail (Docker Compose)

Single-node Loki with Promtail for file + Docker logs. Point Grafana (on any host) at this Loki.

## Prereqs
- Docker + Docker Compose (Plugin)
- Linux host with access to `/var/log` and `/var/lib/docker/containers`

## Quick start
```bash
# 1) Clone
git clone https://github.com/<you>/loki-promtail-stack.git
cd loki-promtail-stack

# 2) (Optional) set environment
cp .env.example .env
# edit .env if you want custom ports/paths/retention

# 3) Prepare runtime dirs
./scripts/bootstrap.sh

# 4) Launch
docker compose pull
docker compose up -d
docker compose ps
