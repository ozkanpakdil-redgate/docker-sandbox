#!/bin/bash
set -e

# Get server name and node ID from environment variables
SERVER_NAME=${SERVER_NAME:-postgres-node.local}
NODE_ID=${NODE_ID:-1}

echo "Starting services for PostgreSQL Node: $SERVER_NAME (Node $NODE_ID)"

# Copy pg_ident.conf for DN-to-username mapping
echo "Configuring PostgreSQL identity mapping..."
if [ -f "/tmp/ca/pg_ident.conf" ]; then
    cp /tmp/ca/pg_ident.conf /etc/postgresql/17/main/pg_ident.conf
    chown postgres:postgres /etc/postgresql/17/main/pg_ident.conf
    chmod 640 /etc/postgresql/17/main/pg_ident.conf
    echo "✓ pg_ident.conf configured for DN mapping"
else
    echo "Warning: pg_ident.conf not found"
fi

# Generate SSL certificates at runtime with correct SERVER_NAME
echo "Generating SSL certificates for $SERVER_NAME..."
if [ -d "/tmp/ca" ] && [ -f "/tmp/ca/generate-server-cert.sh" ]; then
    # Copy CA scripts locally and make them executable (Windows volume mounts lose execute permissions)
    echo "Copying CA scripts to local filesystem..."
    mkdir -p /usr/local/bin/ca
    cp -r /tmp/ca/* /usr/local/bin/ca/
    chmod +x /usr/local/bin/ca/*.sh 2>/dev/null || true
    /usr/local/bin/ca/generate-server-cert.sh "$SERVER_NAME" "$NODE_ID" "/usr/local/bin/ca"
    echo "✓ SSL certificates generated for $SERVER_NAME"
    
    # Enable SSL in PostgreSQL configuration now that certificates exist
    echo "Enabling SSL in PostgreSQL configuration..."
    echo "
# SSL Configuration for $SERVER_NAME (added at runtime)
ssl = on
ssl_cert_file = '/var/lib/postgresql/17/main/ssl/server.crt'
ssl_key_file = '/var/lib/postgresql/17/main/ssl/server.key'
ssl_ca_file = '/var/lib/postgresql/17/main/ssl/ca.crt'
ssl_crl_file = ''
ssl_prefer_server_ciphers = on
ssl_ecdh_curve = 'prime256v1'
ssl_min_protocol_version = 'TLSv1.2'
ssl_max_protocol_version = ''
" >> /etc/postgresql/17/main/postgresql.conf
    echo "✓ SSL configuration enabled"
else
    echo "Warning: CA directory or generation script not found. SSL certificates will not be generated."
fi

# Start SSH
echo "Starting SSH..."
service ssh start

# Start PostgreSQL
echo "Starting PostgreSQL..."
su postgres -c "/usr/lib/postgresql/17/bin/pg_ctl -D /var/lib/postgresql/17/main -o '-c config_file=/etc/postgresql/17/main/postgresql.conf' -l /var/log/postgresql/postgresql-17-main.log start"

# Copy SSL certificates to accessible location for client access
echo "Copying SSL certificates to /tmp/certs..."
mkdir -p /tmp/certs
if [ -f /var/lib/postgresql/17/main/ssl/server.crt ]; then
    cp /var/lib/postgresql/17/main/ssl/server.crt /tmp/certs/ 2>/dev/null || echo "Server certificate copy failed"
fi
if [ -f /var/lib/postgresql/17/main/ssl/ca.crt ]; then
    cp /var/lib/postgresql/17/main/ssl/ca.crt /tmp/certs/ 2>/dev/null || echo "CA certificate copy failed"
fi
if [ -f /var/lib/postgresql/17/main/ssl/redgatemonitor.crt ]; then
    cp /var/lib/postgresql/17/main/ssl/redgatemonitor.crt /tmp/certs/ 2>/dev/null || echo "Client certificate copy failed"
fi
if [ -f /var/lib/postgresql/17/main/ssl/redgatemonitor.key ]; then
    cp /var/lib/postgresql/17/main/ssl/redgatemonitor.key /tmp/certs/ 2>/dev/null || echo "Client key copy failed"
fi
if [ -f /var/lib/postgresql/17/main/ssl/redgatemonitor.pfx ]; then
    cp /var/lib/postgresql/17/main/ssl/redgatemonitor.pfx /tmp/certs/ 2>/dev/null || echo "Client PFX copy failed"
fi
if [ -f /var/lib/postgresql/17/main/ssl/redgatemonitor-nopass.pfx ]; then
    cp /var/lib/postgresql/17/main/ssl/redgatemonitor-nopass.pfx /tmp/certs/ 2>/dev/null || echo "Client no-password PFX copy failed"
fi
chmod 644 /tmp/certs/* 2>/dev/null || true

# Copy client certificates to consolidated client-certs directory (only from node1 to avoid conflicts)
if [ "$NODE_ID" = "1" ]; then
    echo "Copying consolidated client certificates to /tmp/client-certs (from node1)..."
    mkdir -p /tmp/client-certs
    if [ -f /var/lib/postgresql/17/main/ssl/ca.crt ]; then
        cp /var/lib/postgresql/17/main/ssl/ca.crt /tmp/client-certs/ 2>/dev/null || echo "CA certificate copy to client-certs failed"
    fi
    if [ -f /var/lib/postgresql/17/main/ssl/redgatemonitor.crt ]; then
        cp /var/lib/postgresql/17/main/ssl/redgatemonitor.crt /tmp/client-certs/ 2>/dev/null || echo "Client certificate copy to client-certs failed"
    fi
    if [ -f /var/lib/postgresql/17/main/ssl/redgatemonitor.key ]; then
        cp /var/lib/postgresql/17/main/ssl/redgatemonitor.key /tmp/client-certs/ 2>/dev/null || echo "Client key copy to client-certs failed"
    fi
    if [ -f /var/lib/postgresql/17/main/ssl/redgatemonitor.pfx ]; then
        cp /var/lib/postgresql/17/main/ssl/redgatemonitor.pfx /tmp/client-certs/ 2>/dev/null || echo "Client PFX copy to client-certs failed"
    fi
    if [ -f /var/lib/postgresql/17/main/ssl/redgatemonitor-nopass.pfx ]; then
        cp /var/lib/postgresql/17/main/ssl/redgatemonitor-nopass.pfx /tmp/client-certs/ 2>/dev/null || echo "Client no-password PFX copy to client-certs failed"
    fi
    chmod 644 /tmp/client-certs/* 2>/dev/null || true
    echo "✓ Consolidated client certificates available in client-certs/"
fi

# Check PostgreSQL status and log
if ! su postgres -c "/usr/lib/postgresql/17/bin/pg_ctl -D /var/lib/postgresql/17/main status"; then
    echo "PostgreSQL failed to start. Showing last 20 lines of log:"
    tail -n 20 /var/log/postgresql/postgresql-17-main.log
fi

echo "PostgreSQL Node $SERVER_NAME is ready!"

# Function to stop services gracefully
stop_services() {
    echo "Stopping services for $SERVER_NAME..."
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
