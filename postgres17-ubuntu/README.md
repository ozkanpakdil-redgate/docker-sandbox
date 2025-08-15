# PostgreSQL 17 SSL Container Setup

A simplified, all-in-one PostgreSQL 17 container with SSL support, SSH access, and monitoring extensions.

## Features

- **PostgreSQL 17** with SSL/TLS encryption
- **SSH access** for administration
- **Self-signed certificates** for development
- **Client certificate authentication** (password-less)
- **Monitoring extensions** (pg_stat_statements, auto_explain)
- **Cross-platform** PowerShell and Bash scripts

## File Structure

```
postgres17-ubuntu/
├── postgres-setup.sh       # Consolidated container setup script
├── README.md               # This documentation
└── certs/                  # SSL certificates (created automatically)
    ├── ca.crt              # Certificate Authority
    ├── server.crt          # Server certificate
    ├── server.key          # Server private key
    ├── client.crt          # Client certificate
    └── client.key          # Client private key
```

### Direct Bash (Linux/macOS)

```bash
# Build and run
chmod +x postgres-setup.sh
podman build -t postgres17-ssl .
podman run -dit --name postgres17-ssl -p 5432:5432 -p 22:22 postgres17-ssl

# Connect via SSH
ssh -i root.key -o StrictHostKeyChecking=no root@localhost
```

## Connection Examples

### Password Authentication
```bash
psql "host=localhost port=5432 dbname=redgatemonitor user=redgatemonitor password=changeme sslmode=require"
```

### Certificate Authentication (No Password)
```bash
psql "host=localhost port=5432 dbname=redgatemonitor user=redgatemonitor sslmode=require sslcert=./certs/redgatemonitor.crt sslkey=./certs/redgatemonitor.key sslrootcert=./certs/server.crt"
```

### .NET Connection Strings

**Password-based:**
```csharp
Host=localhost;Port=5432;Database=redgatemonitor;Username=redgatemonitor;Password=changeme;SSL Mode=Require;Trust Server Certificate=true
```

**Certificate-based:**

```csharp
Host=localhost;Port=5432;Database=redgatemonitor;Username=redgatemonitor;SSL Mode=Require;SSL Cert=certs/client.crt;SSL Key=certs/client.key;SSL CA=certs/ca.crt
```

## Default Credentials

- **PostgreSQL**: `redgatemonitor` / `changeme`
- **SSH**: `root` / `changeme`

## SSL Configuration

The container automatically generates:

- **CA Certificate** (`ca.crt`) - Certificate Authority
- **Server Certificate** (`server.crt`) - For PostgreSQL SSL
- **Client Certificate** (`client.crt`) - For client authentication

### Authentication Methods

1. **Password Authentication** - Standard username/password with SSL encryption
2. **Certificate Authentication** - Password-less using client certificates

Both methods use SSL encryption (TLS 1.3) for secure connections.

## Monitoring Features

Pre-installed extensions:

- `pg_stat_statements` - Query statistics tracking
- `auto_explain` - Automatic query plan logging
- Standard PostgreSQL system views

Example monitoring queries:

```sql
-- Top 10 slowest queries
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Current connections
SELECT datname, usename, client_addr, state
FROM pg_stat_activity
WHERE state = 'active';
```

## Requirements

### Windows

- PowerShell 5.1+ or PowerShell Core 7+
- Podman or Docker
- psql client (optional, for testing)

### Linux/macOS

- Bash
- Podman or Docker
- psql client (optional, for testing)

## Troubleshooting

### SSL connection fails

```powershell
# Verify certificates exist
ls certs/

# Test with trust server certificate
psql "host=localhost port=5432 dbname=redgatemonitor user=redgatemonitor password=changeme sslmode=require Trust Server Certificate=true"
```

### SSH connection fails

```powershell
# Ensure SSH key exists
ls root.key

```

## Security Notes

⚠️ **For Development Only**: This setup uses self-signed certificates and default passwords.

For production:

1. Use proper CA-signed certificates
2. Change default passwords
3. Configure proper firewall rules
4. Use secret management for credentials
5. Enable audit logging

