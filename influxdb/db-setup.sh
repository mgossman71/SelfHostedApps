# Create DB "proxmox"
docker exec -it influxdb influx -username admin -password 'CHANGE_ME' \
  -execute 'CREATE DATABASE "proxmox"'

# (optional) keep only 30 days by default
#docker exec -it influxdb influx -username admin -password 'CHANGE_ME' \
  -execute 'CREATE RETENTION POLICY "thirty_days" ON "proxmox" DURATION 30d REPLICATION 1 DEFAULT'
