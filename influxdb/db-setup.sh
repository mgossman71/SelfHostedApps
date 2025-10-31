# Create DB "proxmox"
docker exec -it influxdb influx -username admin -password 'secret' \
  -execute 'CREATE DATABASE "proxmox"'

# (optional) keep only 30 days by default
#docker exec -it influxdb influx -username admin -password 'secret' \
  -execute 'CREATE RETENTION POLICY "thirty_days" ON "proxmox" DURATION 30d REPLICATION 1 DEFAULT'


# create a Proxmox-specific user
docker exec -it influxdb influx -username admin -password 'secret' \
  -execute 'CREATE USER "pve" WITH PASSWORD '\''STRONG_PASS_HERE'\'''

# grant write (or all) on the proxmox DB
docker exec -it influxdb influx -username admin -password 'secret' \
  -execute 'GRANT ALL ON "proxmox" TO "pve"'
# If you prefer least-privilege: GRANT WRITE ON "proxmox" TO "pve"
