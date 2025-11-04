# 1) Regenerate machine-id on first boot:
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id || true
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id

# 2) Remove old SSH host keys (new ones will be created on first boot)
sudo rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub

# 3) Reset cloud-init state (if you've installed it; recommended)
# (Install it if you want per-clone userdata even for ISO builds)
sudo apt-get install -y cloud-init
sudo cloud-init clean --logs

# 4) Clear DHCP leases (if NetworkManager is used, also clear its leases)
sudo rm -f /var/lib/dhcp/*

# 5) Keep netplan generic (DHCP) — do NOT hardcode old interface MACs
# Example minimal netplan (systemd-networkd):
# /etc/netplan/01-netcfg.yaml
# network:
#   version: 2
#   ethernets:
#     ens18:
#       dhcp4: true
# (Or leave NetworkManager/systemd default and let DHCP work.)

# 6) Optional: cleanup caches/logs
sudo apt-get autoremove -y
sudo apt-get clean
sudo journalctl --rotate
sudo journalctl --vacuum-time=1s
sudo rm -rf /tmp/* /var/tmp/*

# 7) Power off
sudo poweroff
