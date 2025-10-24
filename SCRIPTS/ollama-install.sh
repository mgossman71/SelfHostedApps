#!/bin/bash

set -e

# Install needed tools
apt install curl -y

# Create and move to the ollama directory
mkdir -p /code/ollama
cd /code/ollama

# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Install pipx if not present
if ! command -v pipx &>/dev/null; then
  apt update
  apt install -y pipx
fi

# Ensure pipx path is set
pipx ensurepath

# Install open-webui using pipx
pipx install open-webui

# Create open-webui.service with the specified content
cat <<EOF > /etc/systemd/system/open-webui.service
[Unit]
Description=Open WebUI Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/root/.local/bin/open-webui serve
Restart=always
Environment=PATH=/root/.local/bin:/usr/bin:/bin
Environment=ENABLE_RAG_WEB_SEARCH=true
Environment="OLLAMA_HOST=0.0.0.0"

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd to recognize the new service
systemctl daemon-reexec       # Reload systemd manager itself
systemctl daemon-reload       # Reload unit files
systemctl restart ollama      # Restart the Ollama service 
systemctl enable open-webui   # Enable the Open WebUI service to start on boot
systemctl start open-webui    # Start the Open WebUI service
# Print success message
echo "Ollama and Open WebUI have been successfully set up."
# Print the status of the Open WebUI service
systemctl status open-webui --no-pager
# Print the status of the Ollama service
systemctl status ollama --no-pager
