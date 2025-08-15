#!/bin/bash
set -e

SERVER_NAME=$1
NODE_ID=$2
CA_DIR=$3

if [ -z "$SERVER_NAME" ] || [ -z "$NODE_ID" ] || [ -z "$CA_DIR" ]; then
    echo "Usage: $0 <SERVER_NAME> <NODE_ID> <CA_DIR>"
    echo "Example: $0 postgres-node1.local 1 /tmp/ca"
    exit 1
fi

echo "Generating server certificate for $SERVER_NAME (Node $NODE_ID)..."

# Create SSL directory
mkdir -p /var/lib/postgresql/17/main/ssl
cd /var/lib/postgresql/17/main/ssl

# Copy CA files
cp "$CA_DIR/ca.crt" ./
cp "$CA_DIR/ca.key" ./
cp "$CA_DIR/redgatemonitor.crt" ./
cp "$CA_DIR/redgatemonitor.key" ./
cp "$CA_DIR/redgatemonitor.pfx" ./
cp "$CA_DIR/redgatemonitor-nopass.pfx" ./

# Generate server private key
openssl genrsa -out server.key 4096
chmod 600 server.key

# Create server certificate config with ALL cluster hostnames in SAN
cat > server_cert.conf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C=US
ST=State
L=City
O=PostgreSQLCluster
OU=Node${NODE_ID}
CN=${SERVER_NAME}

[v3_req]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = postgres-node1.local
DNS.3 = postgres-node2.local
DNS.4 = postgres-node3.local
DNS.5 = 127.0.0.1
IP.1 = 127.0.0.1
IP.2 = ::1
EOF

# Generate server certificate signing request
openssl req -new -key server.key -out server.csr -config server_cert.conf

# Generate server certificate signed by CA
openssl x509 -req -days 365 -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -extensions v3_req -extfile server_cert.conf

# Set proper ownership and permissions
chown postgres:postgres *.crt *.key *.pfx
chmod 600 server.key redgatemonitor.key ca.key redgatemonitor.pfx redgatemonitor-nopass.pfx
chmod 644 server.crt redgatemonitor.crt ca.crt

# Clean up temporary files
rm -f server.csr server_cert.conf ca.key ca.srl

echo "✓ Server certificate for $SERVER_NAME generated and signed by CA"
