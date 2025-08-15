#!/bin/bash
set -e

echo "Generating Root CA and shared client certificates..."

# Create CA private key
openssl genrsa -out ca.key 4096
chmod 600 ca.key

# Create CA certificate config
cat > ca.conf << 'EOF'
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_ca
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = PostgreSQLCluster
OU = CA
CN = PostgreSQL-Cluster-CA

[v3_ca]
basicConstraints = CA:true
keyUsage = keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF

# Create CA certificate
openssl req -new -x509 -days 365 -key ca.key -out ca.crt -config ca.conf -extensions v3_ca
chmod 644 ca.crt

# Generate shared client private key for redgatemonitor user
openssl genrsa -out redgatemonitor.key 4096
chmod 600 redgatemonitor.key

# Create client certificate config
cat > redgatemonitor.conf << 'EOF'
[req]
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = PostgreSQLCluster
OU = Client
CN = redgatemonitor
EOF

# Generate client certificate signing request using config file
openssl req -new -key redgatemonitor.key -out redgatemonitor.csr -config redgatemonitor.conf

# Generate client certificate signed by CA
openssl x509 -req -days 365 -in redgatemonitor.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out redgatemonitor.crt
chmod 644 redgatemonitor.crt

# Generate PFX files combining client certificate and private key (for Windows import)
# Version 1: Password protected
openssl pkcs12 -export -out redgatemonitor.pfx -inkey redgatemonitor.key -in redgatemonitor.crt -certfile ca.crt -password pass:changeme
chmod 644 redgatemonitor.pfx

# Version 2: No password (easier for automated imports)
openssl pkcs12 -export -out redgatemonitor-nopass.pfx -inkey redgatemonitor.key -in redgatemonitor.crt -certfile ca.crt -password pass:
chmod 644 redgatemonitor-nopass.pfx

# Clean up temporary files
rm -f redgatemonitor.csr ca.srl ca.conf redgatemonitor.conf

echo "✓ Root CA and shared client certificates generated successfully!"
echo "Files created:"
echo "  - ca.crt (Root CA certificate)"
echo "  - ca.key (Root CA private key)"
echo "  - redgatemonitor.crt (Shared client certificate)"
echo "  - redgatemonitor.key (Shared client private key)"
echo "  - redgatemonitor.pfx (Client certificate bundle for Windows - password: changeme)"
echo "  - redgatemonitor-nopass.pfx (Client certificate bundle for Windows - no password)"