#!/bin/bash
# Multi-node PostgreSQL SSL Connection Script (Bash version)
# This script can connect to any node in the cluster using the appropriate certificates

usage() {
    echo "Usage: $0 <node1|node2|node3> [database] [user] [command]"
    echo "Examples:"
    echo "  $0 node1"
    echo "  $0 node2 postgres postgres '\\l'"
    echo "  $0 node3 redgatemonitor redgatemonitor 'SELECT version();'"
    exit 1
}

# Check if node parameter is provided
if [ $# -lt 1 ]; then
    usage
fi

NODE=$1
DATABASE=${2:-"redgatemonitor"}
USER=${3:-"redgatemonitor"}
COMMAND=${4:-"SELECT 'Connected to ' || current_setting('server_version') || ' on ' || inet_server_addr() || ':' || inet_server_port() as connection_info;"}

# Define node configurations
case $NODE in
    "node1")
        HOSTNAME="postgres-node1.local"
        PORT=5432
        CERT_PATH="./node1/certs"
        ;;
    "node2")
        HOSTNAME="postgres-node2.local"
        PORT=5433
        CERT_PATH="./node2/certs"
        ;;
    "node3")
        HOSTNAME="postgres-node3.local"
        PORT=5434
        CERT_PATH="./node3/certs"
        ;;
    *)
        echo "Error: Invalid node '$NODE'. Must be node1, node2, or node3."
        usage
        ;;
esac

# Build connection string
CONNECTION_STRING="host=$HOSTNAME port=$PORT dbname=$DATABASE user=$USER sslmode=verify-full sslcert=$CERT_PATH/redgatemonitor.crt sslkey=$CERT_PATH/redgatemonitor.key sslrootcert=$CERT_PATH/ca.crt"

# Print connection information
echo "==========================================="
echo "Connecting to PostgreSQL $NODE"
echo "==========================================="
echo "Hostname: $HOSTNAME"
echo "Port: $PORT"
echo "Database: $DATABASE"
echo "User: $USER"
echo "Certificates: $CERT_PATH"
echo ""
echo "Full psql command:"
echo "psql \"$CONNECTION_STRING\" -c \"$COMMAND\""
echo ""
echo "Connection output:"
echo "-------------------------------------------"

# Execute psql command
psql "$CONNECTION_STRING" -c "$COMMAND"
