# SelfHostedApps

A curated collection of self-hosted applications and infrastructure, each with ready-to-use Docker Compose configurations. This repository is designed for homelab and self-hosting enthusiasts who want to deploy a wide range of open-source and third-party services quickly.

---

## Directory Overview

| Directory           | Description / Main Service(s)                |
|---------------------|----------------------------------------------|
| `authentik/`        | [Authentik](https://goauthentik.io/) - SSO & identity provider |
| `awx/`              | [AWX](https://github.com/ansible/awx) - Ansible UI (empty compose) |
| `coqui-ai/`         | [Coqui TTS](https://github.com/coqui-ai/TTS) - Text-to-speech server |
| `dashy/`            | [Dashy](https://github.com/Lissy93/dashy) - Dashboard UI |
| `docmost/`          | [Docmost](https://github.com/docmost/docmost) - Document management |
| `frameforge-site/`  | FrameForge site (custom, see Docker image)   |
| `glance/`           | [Glance](https://github.com/glanceapp/glance) - Dashboard & widgets |
| `grafana/`          | [Grafana](https://grafana.com/) - Metrics dashboard |
| `homarr/`           | [Homarr](https://github.com/ajnart/homarr) - Dashboard UI |
| `homeAssistant/`    | [Home Assistant](https://www.home-assistant.io/) - Home automation |
| `homebridge/`       | [Homebridge](https://homebridge.io/) - HomeKit bridge |
| `invoiceninja/`     | [Invoice Ninja](https://www.invoiceninja.com/) - Invoicing & billing |
| `kokoro/`           | [Kokoro](https://github.com/remsky/kokoro) - FastAPI GPU inference |
| `mjg-splash/`       | Custom splash page (see Docker image)        |
| `movie-tools/`      | Radarr, Sonarr, Sabnzbd - Media automation  |
| `n8nio/`            | [n8n](https://n8n.io/) - Workflow automation |
| `nextcloud/`        | [Nextcloud](https://nextcloud.com/) - File sync & sharing |
| `nginx-proxy-manager/` | [Nginx Proxy Manager](https://nginxproxymanager.com/) - Reverse proxy UI |
| `openspeedtest/`    | [OpenSpeedTest](https://openspeedtest.com/) - Network speed test |
| `openwebui/`        | [Open WebUI](https://github.com/open-webui/open-webui) - LLM chat UI |
| `overseerr/`        | [Overseerr](https://overseerr.dev/) - Media requests |
| `smokeping/`        | [SmokePing](https://oss.oetiker.ch/smokeping/) - Network latency monitor |
| `uptime-kuma/`      | [Uptime Kuma](https://github.com/louislam/uptime-kuma) - Uptime monitoring |
| `vaultwarden/`      | [Vaultwarden](https://github.com/dani-garcia/vaultwarden) - Bitwarden-compatible password manager |
| `whisparr/`         | [Whisparr](https://github.com/Whisparr/Whisparr) - Adult media automation |
| `wopr/`             | WOPR NORAD UI (custom React app, see below)  |
| `wordpress/`        | [WordPress](https://wordpress.org/) - Blogging platform |
| `SCRIPTS/`          | Utility scripts (e.g., Docker install)       |

---

## Usage

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/) installed.
- (Optional) Use [`SCRIPTS/docker-install.sh`](SCRIPTS/docker-install.sh) for easy Docker setup on Debian/Ubuntu.

### Quick Start

1. **Clone the repository:**
   ```sh
   git clone https://github.com/yourusername/SelfHostedApps.git
   cd SelfHostedApps
   ```

2. **Choose a service directory:**
   ```sh
   cd nextcloud
   ```

3. **Review and edit `.env` files as needed.**

4. **Start the service:**
   ```sh
   docker compose up -d
   ```

5. **Access the service via the mapped port (see each `compose.yaml` for details).**

---

## Notable Customizations

- **WOPR NORAD UI**  
  A custom React app inspired by the WOPR terminal from "WarGames".  
  See [`wopr/setup-wopr.sh`](wopr/setup-wopr.sh) for build instructions.

- **Glance, Dashy, Homarr**  
  Multiple dashboard UIs are included. See each directory for configuration.

- **Media Automation**  
  The `movie-tools/` stack includes Radarr, Sonarr, and Sabnzbd, with NFS volume examples.

---

## Environment Variables

Many services use `.env` files for secrets and configuration.  
**Always review and update these before deploying.**

---

## License

This repository is a collection of open-source and third-party Docker Compose files.  
Each application is subject to its own license.

---

## Credits

- See each subdirectory for upstream project links and documentation.# SelfHostedApps