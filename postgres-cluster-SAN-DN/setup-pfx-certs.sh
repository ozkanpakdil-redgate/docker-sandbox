#!/bin/bash
# Setup script for generating PFX certificates for PostgreSQL cluster with DN authentication

set -e

echo "🔐 PostgreSQL Cluster PFX Certificate Setup (DN Authentication)"
echo "================================================================="
echo "This cluster uses Distinguished Name (DN) authentication."
echo "DN Format: redgatemonitor"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Step 1: Generate CA certificates with both PFX versions
echo "📋 Step 1: Generating CA and client certificates..."
cd "$SCRIPT_DIR/ca"
./generate-ca.sh
cd "$SCRIPT_DIR"

# Step 2: Generate node certificates and build cluster
echo "📋 Step 2: Building Docker cluster with new certificates..."
docker-compose down 2>/dev/null || true
docker-compose up --build -d

# Step 4: Show results
echo ""
echo "✅ Setup Complete!"
echo "📁 Available certificate files in ca/ and node*/certs/:"
ls -la ca/ | grep -E '\.(crt|key|pfx)$' | awk '{print "   📄 " $9}'

echo ""
echo "🔧 Import PFX to Windows Certificate Store (if on Windows):"
echo "   # No password (recommended):"
echo "   Import-PfxCertificate -FilePath \"./ca/redgatemonitor-nopass.pfx\" -CertStoreLocation \"Cert:\\CurrentUser\\My\""
echo ""
echo "   # With password (changeme):"
echo "   \$pwd = ConvertTo-SecureString -String \"changeme\" -Force -AsPlainText"
echo "   Import-PfxCertificate -FilePath \"./ca/redgatemonitor.pfx\" -CertStoreLocation \"Cert:\\CurrentUser\\My\" -Password \$pwd"

echo ""
echo "🔐 DN Authentication Connection Examples:"
echo "   Node 1: psql \"host=localhost port=5432 dbname=redgatemonitor user=CN=redgatemonitor sslmode=require sslcert=node1/certs/redgatemonitor.crt sslkey=node1/certs/redgatemonitor.key sslrootcert=node1/certs/ca.crt\""
echo "   Node 2: psql \"host=localhost port=5433 dbname=redgatemonitor user=CN=redgatemonitor sslmode=require sslcert=node2/certs/redgatemonitor.crt sslkey=node2/certs/redgatemonitor.key sslrootcert=node2/certs/ca.crt\""

echo ""
echo "🌐 Multi-SAN certificate benefits:"
echo "   ✓ Single client certificate works with ALL nodes"
echo "   ✓ Can connect to any hostname (postgres-node1.local, postgres-node2.local, postgres-node3.local)"
echo "   ✓ DN-based authentication for enhanced security"
echo "   ✓ Automatic Windows integration with PFX files"
echo "   ✓ No need to manage multiple certificate bundles"

echo ""
echo "📖 See SSL_CERTIFICATE_GUIDE.md for detailed usage instructions"
