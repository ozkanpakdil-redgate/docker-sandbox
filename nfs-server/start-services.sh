#!/bin/bash
set -e

#Start NFS server
service rpcbind start
service nfs-kernel-server start

# Function to stop services gracefully
stop_services() {
    echo "Stopping services..."
    exit 0
}

# Trap SIGTERM and SIGINT
trap stop_services SIGTERM SIGINT

# Keep the script running
echo "Services started, waiting for signals..."
while true; do
    sleep 1
done