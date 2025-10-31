# Make sure folders exist
mkdir -p ./data/chronograf ./data/influxdb

# Give Chronograf ownership of its data dir
sudo chown -R 999:999 ./data/chronograf

# (Good practice) set reasonable perms
sudo find ./data/chronograf -type d -exec chmod 0775 {} \;
sudo find ./data/chronograf -type f -exec chmod 0664 {} \;

# If a stale DB exists as root, fix or remove it
sudo chown 999:999 ./data/chronograf/chronograf-v1.db 2>/dev/null || true
# or: sudo rm -f ./data/chronograf/chronograf-v1.db
