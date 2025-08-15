# PostgreSQL Cluster SSL Connection Guide - Distinguished Name Authentication

## Overview

This PostgreSQL cluster uses Docker containers with SSL/TLS encryption and Distinguished Name (DN) based certificate authentication. The cluster consists of three PostgreSQL 17 nodes with a centralized Certificate Authority (CA) approach for secure communications.

## Authentication Method

This cluster is configured to use **Distinguished Name (DN) authentication** instead of the default Common Name (CN) authentication. PostgreSQL validates the entire certificate's Distinguished Name against the username using the `clientname=DN` option in `pg_hba.conf`.

**DN Format**: `redgatemonitor`

## Architecture

### Certificate Structure
- **Root CA**: Single Certificate Authority for the entire cluster (`ca/ca.crt`, `ca/ca.key`)
- **Shared Client Certificate**: One client certificate used across all nodes (`ca/redgatemonitor.crt`, `ca/redgatemonitor.key`)
- **Individual Server Certificates**: Each node has its own server certificate signed by the root CA
- **PKCS#12 Bundle**: Windows-compatible certificate bundle (`ca/redgatemonitor.pfx`)

### Node Configuration
| Node | Container Name | PostgreSQL Port | SSH Port | Hostname |
|------|----------------|-----------------|----------|----------|
| Node 1 | postgres-node1 | 5432 | 2201 | postgres-node1.local |
| Node 2 | postgres-node2 | 5433 | 2202 | postgres-node2.local |
| Node 3 | postgres-node3 | 5434 | 2203 | postgres-node3.local |

## Quick Start

### 1. Start the Cluster

```bash
# Using setup script (Recommended)
./setup-cluster.sh start

# Or using Docker Compose
docker-compose up -d --build
```

### 2. Copy Client Certificates

```bash
# Certificates are automatically copied to client-certs/ directory
ls client-certs/
```

## Connection Methods

### SSL Connections (Recommended)

#### From Windows (using DN authentication):
```bash
# Node 1
psql "host=localhost port=5432 dbname=redgatemonitor user=CN=redgatemonitor sslmode=require sslcert=client-certs/redgatemonitor.crt sslkey=client-certs/redgatemonitor.key sslrootcert=client-certs/ca.crt"

# Node 2
psql "host=localhost port=5433 dbname=redgatemonitor user=CN=redgatemonitor sslmode=require sslcert=client-certs/redgatemonitor.crt sslkey=client-certs/redgatemonitor.key sslrootcert=client-certs/ca.crt"

# Node 3
psql "host=localhost port=5434 dbname=redgatemonitor user=CN=redgatemonitor sslmode=require sslcert=client-certs/redgatemonitor.crt sslkey=client-certs/redgatemonitor.key sslrootcert=client-certs/ca.crt"
```

#### From inside containers:
```bash
# Connect from Node 1 to itself using DN authentication
docker exec postgres-node1 psql "host=postgres-node1 dbname=redgatemonitor user=CN=redgatemonitor sslmode=require sslcert=/tmp/certs/redgatemonitor.crt sslkey=/tmp/certs/redgatemonitor.key sslrootcert=/tmp/certs/ca.crt"
```

### Non-SSL Connections (for testing):
```bash
# Node 1
psql "host=localhost port=5432 dbname=redgatemonitor user=redgatemonitor password=changeme sslmode=disable"

# Node 2
psql "host=localhost port=5433 dbname=redgatemonitor user=redgatemonitor password=changeme sslmode=disable"

# Node 3
psql "host=localhost port=5434 dbname=redgatemonitor user=redgatemonitor password=changeme sslmode=disable"
```

## SSL Configuration Details

### PostgreSQL SSL Settings (pg_hba.conf)
```
# SSL connections with certificate authentication
hostssl all all 0.0.0.0/0 cert clientcert=verify-full
hostssl all all ::/0 cert clientcert=verify-full

# Non-SSL connections (fallback)
hostnossl all all 0.0.0.0/0 scram-sha-256
hostnossl all all ::/0 scram-sha-256
```

### Certificate Verification
The cluster uses `clientcert=verify-full` which requires:
1. Valid client certificate signed by the trusted CA
2. Client certificate CN must match the PostgreSQL username (`redgatemonitor`)
3. Server certificate must be trusted by the client

## Troubleshooting

### Common SSL Connection Issues

#### Permission Errors
If you get "private key file has group or world access" error:
```bash
# On Linux/macOS
chmod 600 client-certs/redgatemonitor.key

# On Windows (in WSL or Git Bash)
chmod 600 client-certs/redgatemonitor.key
```

#### Certificate Verification Failed
- Ensure `sslrootcert` points to the correct CA certificate (`ca.crt`)
- Verify the server certificate is signed by the same CA
- Check that the client certificate CN matches the username

#### Connection Refused
- Verify the container is running: `docker ps`
- Check if the port is mapped correctly
- Ensure PostgreSQL is listening on all interfaces in `postgresql.conf`

### Debugging Commands

```bash
# Check container status
docker ps

# View container logs
docker logs postgres-node1

# Connect to container shell
docker exec -it postgres-node1 bash

# Check PostgreSQL configuration
docker exec postgres-node1 cat /etc/postgresql/17/main/postgresql.conf | grep ssl
docker exec postgres-node1 cat /etc/postgresql/17/main/pg_hba.conf

# Verify certificate information
openssl x509 -in client-certs/redgatemonitor.crt -text -noout
openssl x509 -in client-certs/ca.crt -text -noout
```

## Certificate Management

### Viewing Certificate Information
```bash
# View client certificate details
openssl x509 -in client-certs/redgatemonitor.crt -text -noout

# View CA certificate details  
openssl x509 -in client-certs/ca.crt -text -noout

# Verify certificate chain
openssl verify -CAfile client-certs/ca.crt client-certs/redgatemonitor.crt
```

### Regenerating Certificates
If you need to regenerate certificates:
```powershell
# Remove existing CA
Remove-Item ca\* -Force

# Regenerate everything
./setup-cluster.sh rebuild
```

## Windows Integration

### Using PKCS#12 Certificate Bundle
For applications that require PKCS#12 format:
```bash
# The bundle is already created at: ca/redgatemonitor.pfx
# Password: changeme
```

### PowerShell Connection Function
```powershell
function Connect-PostgreSQLNode {
    param(
        [int]$NodeNumber = 1,
        [string]$Database = "redgatemonitor",
        [switch]$UseSSL
    )
    
    $port = 5431 + $NodeNumber
    
    if ($UseSSL) {
        $connectionString = "host=localhost port=$port dbname=$Database user=redgatemonitor sslmode=require sslcert=client-certs/redgatemonitor.crt sslkey=client-certs/redgatemonitor.key sslrootcert=client-certs/ca.crt"
    } else {
        $connectionString = "host=localhost port=$port dbname=$Database user=redgatemonitor password=changeme sslmode=disable"
    }
    
    psql $connectionString
}

# Usage:
# Connect-PostgreSQLNode -NodeNumber 1 -UseSSL
# Connect-PostgreSQLNode -NodeNumber 2
```

## Security Best Practices

1. **Always use SSL in production**: Set `sslmode=require` or `sslmode=verify-full`
2. **Protect private keys**: Ensure proper file permissions (600)
3. **Regular certificate rotation**: Replace certificates before expiration
4. **Network isolation**: Use Docker networks to isolate database traffic
5. **Audit access**: Monitor PostgreSQL logs for authentication attempts

## File Structure
```
postgres-cluster/
├── ca/                           # Certificate Authority files
│   ├── ca.crt                   # Root CA certificate
│   ├── ca.key                   # Root CA private key
│   ├── redgatemonitor.crt       # Shared client certificate
│   ├── redgatemonitor.key       # Shared client private key
│   └── redgatemonitor.pfx       # PKCS#12 bundle
├── client-certs/                # Client certificates for Windows
│   ├── ca.crt                   # Copy of CA certificate
│   ├── redgatemonitor.crt       # Copy of client certificate
│   └── redgatemonitor.key       # Copy of client private key
├── node1/certs/                 # Node 1 certificates
├── node2/certs/                 # Node 2 certificates
├── node3/certs/                 # Node 3 certificates
├── shared/                      # Shared Docker configuration
├── docker-compose.yml           # Docker Compose configuration
├── setup-cluster.sh            # Main setup script
```

## Supported SSL Modes

| Mode | Description | Security Level |
|------|-------------|----------------|
| `disable` | No SSL encryption | Low ❌ |
| `allow` | SSL if available, plaintext otherwise | Low ❌ |
| `prefer` | SSL preferred, plaintext fallback | Medium ⚠️ |
| `require` | SSL required, no certificate verification | Medium ⚠️ |
| `verify-ca` | SSL required, verify CA | High ✅ |
| `verify-full` | SSL required, verify CA and hostname | Highest ✅ |

**Recommendation**: Use `require` for development, `verify-full` for production.
