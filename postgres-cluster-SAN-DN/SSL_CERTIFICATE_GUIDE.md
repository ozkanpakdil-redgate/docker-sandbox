# PostgreSQL Cluster SSL Certificate Guide - Distinguished Name Authentication

## Certificate Structure and DN Authentication

This PostgreSQL cluster uses **Distinguished Name (DN) authentication** instead of Common Name (CN) authentication. Each PostgreSQL node has its own SSL server certificate with node-specific SAN entries:

- **Node 1**: Certificate contains `DNS:postgres-node1.local`
- **Node 2**: Certificate contains `DNS:postgres-node2.local`  
- **Node 3**: Certificate contains `DNS:postgres-node3.local`

All nodes share the same **CA certificate** for validation and use the same **client certificate** with DN: `redgatemonitor`

## Client Connection Options

### Option 1: Node-Specific Certificates (Current Setup)
Each node has its own certificate directory with:
```
nodeX/certs/
├── ca.crt              # Root CA certificate (same for all nodes)
├── redgatemonitor.crt  # Client certificate (same for all nodes, DN-based)
├── redgatemonitor.key  # Client private key (same for all nodes)
└── server.crt          # Server certificate (node-specific SAN)
```

**Connection Examples with DN Authentication:**
```bash
# Connect to Node 1
psql "host=postgres-node1.local port=5432 dbname=redgatemonitor user=redgatemonitor sslmode=verify-full sslcert=./node1/certs/redgatemonitor.crt sslkey=./node1/certs/redgatemonitor.key sslrootcert=./node1/certs/ca.crt"

# Connect to Node 2  
psql "host=postgres-node2.local port=5433 dbname=redgatemonitor user=redgatemonitor sslmode=verify-full sslcert=./node2/certs/redgatemonitor.crt sslkey=./node2/certs/redgatemonitor.key sslrootcert=./node2/certs/ca.crt"

# Connect to Node 3
psql "host=postgres-node3.local port=5434 dbname=redgatemonitor user=redgatemonitor sslmode=verify-full sslcert=./node3/certs/redgatemonitor.crt sslkey=./node3/certs/redgatemonitor.key sslrootcert=./node3/certs/ca.crt"
```

### Option 2: Consolidated Client Certificate Bundle
Create a single `client-certs/` directory with shared certificates:

```
client-certs/
├── ca.crt                      # Root CA certificate
├── redgatemonitor.crt          # Client certificate  
├── redgatemonitor.key          # Client private key
├── redgatemonitor.pfx          # PFX bundle (password: changeme)
└── redgatemonitor-nopass.pfx   # PFX bundle (no password)
```

**Important:** You must connect to the correct hostname that matches each server's certificate:
- Use `postgres-node1.local:5432` for Node 1
- Use `postgres-node2.local:5433` for Node 2  
- Use `postgres-node3.local:5434` for Node 3

### Option 3: Multi-SAN Server Certificates ✅ **IMPLEMENTED**

**Status: Successfully implemented and deployed!**

All server certificates now include ALL node hostnames in Subject Alternative Names:

```
DNS.1 = localhost
DNS.2 = postgres-node1.local
DNS.3 = postgres-node2.local
DNS.4 = postgres-node3.local
DNS.5 = 127.0.0.1
IP.1 = 127.0.0.1
IP.2 = ::1
```

**Benefits of this approach:**
- Single client certificate bundle can connect to any node using any hostname
- More flexible for load balancing and failover scenarios
- Easier certificate management

**How to use:**
```bash
# Use the consolidated client-certs/ directory for any node
psql "host=postgres-nodeX.local port=XXXX dbname=redgatemonitor user=redgatemonitor sslmode=verify-full sslcert=./client-certs/redgatemonitor.crt sslkey=./client-certs/redgatemonitor.key sslrootcert=./client-certs/ca.crt"
```

### Option 4: Windows Certificate Store Integration

**PFX Files for Windows Import:**

The `client-certs/` directory now includes PFX files for easy import into Windows Certificate Store:

- `redgatemonitor.pfx` - Password protected (password: `changeme`)
- `redgatemonitor-nopass.pfx` - No password required

**Automatic Generation:**

PFX files are automatically generated when you run:

```bash
# Rebuild cluster to pick up new certificates
docker-compose down && docker-compose up --build -d
```

**To import into Windows Certificate Store:**

1. **Using Certificate Manager (certmgr.msc):**

   ```cmd
   # Open Certificate Manager
   certmgr.msc
   
   # Navigate to Personal > Certificates
   # Right-click > All Tasks > Import
   # Select redgatemonitor-nopass.pfx (easier, no password needed)
   ```

2. **Using PowerShell (Windows):**

   ```powershell
   # Import without password
   Import-PfxCertificate -FilePath ".\client-certs\redgatemonitor-nopass.pfx" -CertStoreLocation "Cert:\CurrentUser\My"
   
   # Or with password
   $pwd = ConvertTo-SecureString -String "changeme" -Force -AsPlainText
   Import-PfxCertificate -FilePath ".\client-certs\redgatemonitor.pfx" -CertStoreLocation "Cert:\CurrentUser\My" -Password $pwd
   ```

**Benefits:**

- Certificate automatically available to all Windows applications
- No need to specify certificate paths in connection strings
- Integrated with Windows security model
- Automatic certificate chain validation

## Security Considerations

1. **Hostname Verification**: Always use `sslmode=verify-full` for production
2. **Certificate Rotation**: Plan for regular certificate renewal
3. **Private Key Security**: Protect `.key` files with appropriate permissions
4. **CA Trust**: Ensure CA certificate is distributed securely to all clients

## Current Status

✅ **Working**: SSL connections with hostname verification  
✅ **Implemented**: Node-specific certificates with proper SAN entries  
✅ **Verified**: Certificate chain validation  

Your cluster is correctly configured for secure SSL connections. Each node validates its specific hostname, providing strong security guarantees.
