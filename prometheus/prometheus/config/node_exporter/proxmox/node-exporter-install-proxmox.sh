# As root on the Proxmox node
cd /tmp
VER="1.8.1"  # update if needed
useradd --system --no-create-home --shell /usr/sbin/nologin node_exporter || true
wget -q https://github.com/prometheus/node_exporter/releases/download/v${VER}/node_exporter-${VER}.linux-amd64.tar.gz
tar -xzf node_exporter-${VER}.linux-amd64.tar.gz
cp node_exporter-${VER}.linux-amd64/node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter

cat >/etc/systemd/system/node_exporter.service <<'EOF'
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter \
  --collector.systemd \
  --collector.processes

Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now node_exporter
# Optional: if using pve-firewall, allow TCP/9100 from your Prometheus LXC/VM
