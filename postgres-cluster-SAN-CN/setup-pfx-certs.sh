#!/bin/bash
# Setup script for generating PFX certificates for PostgreSQL cluster

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

print_color() {
    echo -e "${1}${2}${NC}"
}

print_color "$GREEN" "🔐 PostgreSQL Cluster PFX Certificate Setup"
print_color "$GREEN" "============================================="

# Step 1: Generate CA certificates with both PFX versions
print_color "$CYAN" "📋 Step 1: Generating CA and client certificates..."
cd ca
bash generate-ca.sh
cd ..

# Step 2: Copy certificates to client-certs directory
print_color "$CYAN" "📋 Step 2: Setting up consolidated client-certs directory..."
mkdir -p client-certs
cp ca/ca.crt client-certs/
cp ca/redgatemonitor.crt client-certs/
cp ca/redgatemonitor.key client-certs/
cp ca/redgatemonitor.pfx client-certs/ 2>/dev/null || true
cp ca/redgatemonitor-nopass.pfx client-certs/ 2>/dev/null || true

# Step 3: Rebuild cluster
print_color "$CYAN" "📋 Step 3: Rebuilding Docker cluster with new certificates..."
docker-compose down
docker-compose up --build -d

# Step 4: Show results
print_color "$GREEN" ""
print_color "$GREEN" "✅ Setup Complete!"
print_color "$YELLOW" "📁 Available certificate files:"
for file in client-certs/*; do
    if [[ -f "$file" ]]; then
        print_color "$WHITE" "   📄 $(basename "$file")"
    fi
done

print_color "$YELLOW" ""
print_color "$YELLOW" "🔧 Import PFX to Windows Certificate Store (if on Windows):"
print_color "$GRAY" "   # Using PowerShell (if available):"
print_color "$WHITE" "   Import-PfxCertificate -FilePath \"./client-certs/redgatemonitor-nopass.pfx\" -CertStoreLocation \"Cert:\\CurrentUser\\My\""
print_color "$GRAY" ""
print_color "$GRAY" "   # With password (changeme):"
print_color "$WHITE" "   \$pwd = ConvertTo-SecureString -String \"changeme\" -Force -AsPlainText"
print_color "$WHITE" "   Import-PfxCertificate -FilePath \"./client-certs/redgatemonitor.pfx\" -CertStoreLocation \"Cert:\\CurrentUser\\My\" -Password \$pwd"

print_color "$YELLOW" ""
print_color "$YELLOW" "🌐 Multi-SAN certificate benefits:"
print_color "$GREEN" "   ✓ Single client certificate works with ALL nodes"
print_color "$GREEN" "   ✓ Can connect to any hostname (postgres-node1.local, postgres-node2.local, postgres-node3.local)"
print_color "$GREEN" "   ✓ Automatic Windows integration with PFX files"
print_color "$GREEN" "   ✓ No need to manage multiple certificate bundles"

print_color "$CYAN" ""
print_color "$CYAN" "📖 See SSL_CERTIFICATE_GUIDE.md for detailed usage instructions"
