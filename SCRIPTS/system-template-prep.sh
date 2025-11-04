# --- BASELINE: make sure required services exist & will start ---
sudo apt-get update
sudo apt-get install -y openssh-server qemu-guest-agent cloud-init
sudo systemctl enable ssh qemu-guest-agent

# --- FIX 1: don't leave a zero-byte machine-id (causes early-boot races) ---
# Instead, remove it so systemd can regenerate on first boot.
sudo rm -f /etc/machine-id /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id

# --- FIX 2: guarantee SSH host keys exist before ssh.service starts on first boot ---
# We add a one-shot unit that (re)creates keys and unmarks ssh if needed.
sudo tee /etc/systemd/system/firstboot-regen-ssh.service >/dev/null <<'EOF'
[Unit]
Description=Regenerate machine-id (if missing) and SSH host keys on first boot
ConditionFirstBoot=yes
Before=ssh.service
After=network-pre.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c '\
  [ -s /etc/machine-id ] || systemd-machine-id-setup; \
  rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub; \
  /usr/bin/ssh-keygen -A; \
  systemctl unmask ssh 2>/dev/null || true \
'

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable firstboot-regen-ssh.service

# --- CLOUD-INIT: keep it fresh for per-clone customization ---
sudo cloud-init clean --logs || true

# --- DHCP leases: clear stale leases from the template ---
sudo rm -f /var/lib/dhcp/* 2>/dev/null || true
sudo rm -f /var/lib/NetworkManager/*lease* 2>/dev/null || true

# --- (Optional) keep netplan generic (example only; ensure the NIC name fits your VM) ---
# cat <<'YAML' | sudo tee /etc/netplan/01-netcfg.yaml
# network:
#   version: 2
#   ethernets:
#     ens18:
#       dhcp4: true
# YAML
# sudo netplan generate

# --- housekeeping ---
sudo apt-get autoremove -y
sudo apt-get clean
sudo journalctl --rotate
sudo journalctl --vacuum-time=1s
sudo rm -rf /tmp/* /var/tmp/*

# --- shutdown; convert to template in Proxmox afterward ---
sudo poweroff
