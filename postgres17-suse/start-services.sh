#!/bin/bash
set -e

## Start PostgreSQL
echo "Starting PostgreSQL..."
su - postgres -c "/usr/pgsql-17/bin/pg_ctl -D /var/lib/pgsql/17/data/ -l logfile start"

#Mount NFS
mkdir -p /nfs/mount
mount -o nolock -t nfs nfs-server:/nfs /nfs/mount

#Setup test table on NFS filesystem in PostgreSQL
chown postgres:postgres /nfs/mount
chmod 700 /nfs/mount
su postgres -c "psql -c \"CREATE TABLESPACE testspace LOCATION '/nfs/mount';\""
su postgres -c "psql -c \"CREATE TABLE test_nfs_table (id serial PRIMARY KEY, data text) TABLESPACE testspace;\""

#Start SSH
echo "Starting SSH..."
ssh-keygen -A
"/usr/sbin/sshd" 

#Function to stop services gracefully
stop_services() {
   echo "Stopping services..."
   su postgres -c "/usr/lib/postgresql/17/bin/pg_ctl -D /var/lib/postgresql/17/main stop"
   exit 0
}

#Trap SIGTERM and SIGINT
trap stop_services SIGTERM SIGINT

# Keep the script running
echo "Services started, waiting for signals..."
while true; do
    sleep 1
done