#!/bin/bash
set -e

# Start SSH
echo "Starting SSH..."
service ssh start
service rpcbind start

# Start PostgreSQL
echo "Starting PostgreSQL..."
su postgres -c "/usr/lib/postgresql/17/bin/pg_ctl -D /var/lib/postgresql/17/main -o '-c config_file=/etc/postgresql/17/main/postgresql.conf' -l /var/log/postgresql/postgresql-17-main.log start"

# Copy SSL certificate to accessible location for Windows clients
echo "Copying SSL certificate to /tmp/certs..."
mkdir -p /tmp/certs
cp /var/lib/postgresql/17/main/ssl/server.crt /tmp/certs/ 2>/dev/null || echo "Certificate copy failed, certificate might already exist in /tmp/"
chmod 644 /tmp/certs/server.crt 2>/dev/null || true

# Check PostgreSQL status and log
if ! su postgres -c "/usr/lib/postgresql/17/bin/pg_ctl -D /var/lib/postgresql/17/main status"; then
    echo "PostgreSQL failed to start. Showing last 20 lines of log:"
    tail -n 20 /var/log/postgresql/postgresql-17-main.log
fi

#Mount NFS
mkdir -p /nfs/mount
mount -t nfs nfs-server:/nfs /nfs/mount

#Setup test table on NFS filesystem in PostgreSQL
chown postgres:postgres /nfs/mount
chmod 700 /nfs/mount
su postgres -c "psql -c \"CREATE TABLESPACE testspace LOCATION '/nfs/mount';\""
su postgres -c "psql -c \"CREATE TABLE test_nfs_table (id serial PRIMARY KEY, data text) TABLESPACE testspace;\""

# Function to stop services gracefully
stop_services() {
    echo "Stopping services..."
    su postgres -c "/usr/lib/postgresql/17/bin/pg_ctl -D /var/lib/postgresql/17/main stop"
    service ssh stop
    exit 0
}

# Trap SIGTERM and SIGINT
trap stop_services SIGTERM SIGINT

# Keep the script running
echo "Services started, waiting for signals..."
while true; do
    sleep 1
done