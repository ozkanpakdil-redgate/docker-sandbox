# PostgreSQL Cluster with SSL/TLS Support

A Docker-based PostgreSQL 17 cluster with SSL/TLS encryption and certificate-based authentication. This cluster uses a centralized Certificate Authority (CA) approach with shared client certificates for secure connections across all nodes.

## 🚀 Quick Start

### Prerequisites

- Docker
- Bash (Git Bash on Windows, or native bash on Linux/macOS)
- PostgreSQL client (psql) - optional for testing connections

### Start the Cluster

#### Option 1: Bash Script (Recommended)

```bash
# Start all nodes with SSL support
./setup-cluster.sh start

# Or rebuild everything from scratch
./setup-cluster.sh rebuild

# Stop all nodes
./setup-cluster.sh stop
```

#### Option 2: Docker Compose

```bash
# Build and start all nodes
docker-compose up -d --build

# Stop all nodes
docker-compose down
```

## 🏗️ Architecture

### Cluster Configuration

| Node | Container | PostgreSQL Port | SSH Port | Hostname |
|------|-----------|-----------------|----------|----------|
| Node 1 | postgres-node1 | 5432 | 2201 | postgres-node1.local |
| Node 2 | postgres-node2 | 5433 | 2202 | postgres-node2.local |
| Node 3 | postgres-node3 | 5434 | 2203 | postgres-node3.local |

### SSL Certificate Structure

- **Root CA**: Single Certificate Authority (`ca/ca.crt`, `ca/ca.key`)
- **Shared Client Certificate**: One certificate for all nodes (`ca/redgatemonitor.crt`, `ca/redgatemonitor.key`)
- **Individual Server Certificates**: Each node has its own server certificate
- **PKCS#12 Bundle**: Windows-compatible bundle (`ca/redgatemonitor.pfx`)

## 🔐 SSL Connections

### From Windows Host

```bash
# Node 1 (Port 5432)
psql "host=localhost port=5432 dbname=redgatemonitor user=redgatemonitor sslmode=require sslcert=client-certs/redgatemonitor.crt sslkey=client-certs/redgatemonitor.key sslrootcert=client-certs/ca.crt"

# Node 2 (Port 5433)
psql "host=localhost port=5433 dbname=redgatemonitor user=redgatemonitor sslmode=require sslcert=client-certs/redgatemonitor.crt sslkey=client-certs/redgatemonitor.key sslrootcert=client-certs/ca.crt"

# Node 3 (Port 5434)
psql "host=localhost port=5434 dbname=redgatemonitor user=redgatemonitor sslmode=require sslcert=client-certs/redgatemonitor.crt sslkey=client-certs/redgatemonitor.key sslrootcert=client-certs/ca.crt"
```

### Non-SSL Connections (Testing Only)

```bash
# Node 1
psql "host=localhost port=5432 dbname=redgatemonitor user=redgatemonitor password=changeme sslmode=disable"

# Node 2
psql "host=localhost port=5433 dbname=redgatemonitor user=redgatemonitor password=changeme sslmode=disable"

# Node 3
psql "host=localhost port=5434 dbname=redgatemonitor user=redgatemonitor password=changeme sslmode=disable"
```

## 📁 Directory Structure

```text
postgres-cluster/
├── ca/                          # Certificate Authority
│   ├── ca.crt                  # Root CA certificate
│   ├── ca.key                  # Root CA private key
│   ├── redgatemonitor.crt      # Shared client certificate
│   ├── redgatemonitor.key      # Shared client private key
│   ├── redgatemonitor.pfx      # PKCS#12 bundle
│   ├── generate-ca.sh          # CA generation script
│   └── generate-server-cert.sh # Server certificate script
├── client-certs/               # Client certificates for Windows
├── node1/certs/                # Node 1 specific certificates
├── node2/certs/                # Node 2 specific certificates
├── node3/certs/                # Node 3 specific certificates
├── shared/                     # Shared Docker configuration
│   ├── Dockerfile              # PostgreSQL container image
│   ├── setup.sh                # Container setup script
│   └── start-services.sh       # Container startup script
├── docker-compose.yml          # Docker Compose configuration
├── setup-cluster.sh           # Main bash setup script
├── setup-pfx-certs.sh         # PFX certificate setup script
├── test-connections.sh        # Connection testing script
└── SSL_CONNECTION_GUIDE.md    # Detailed SSL documentation
```

## 🛠️ Management Scripts

### Bash Script (setup-cluster.sh)

- **Primary management tool** for all environments
- Handles CA generation, container building, and certificate distribution
- Provides detailed connection information
- Supports start, stop, build, and rebuild operations
- Cross-platform compatible (Windows with Git Bash, Linux, macOS)

### PFX Certificate Setup (setup-pfx-certs.sh)

- Generates PKCS#12 bundles for Windows integration
- Sets up consolidated client certificate directory
- Automatic cluster rebuild with new certificates

### Docker Compose

- Declarative infrastructure management
- Easy integration with CI/CD pipelines
- Volume mounts for certificate sharing
- **✅ Updated with CA certificate volume mounts**

## 🔍 Testing and Verification

### Run Connection Tests

```bash
# Test all nodes and certificate setup (updated for Docker)
bash test-connections.sh
```

### Manual SSL Verification

```bash
# Verify certificate chain
openssl verify -CAfile client-certs/ca.crt client-certs/redgatemonitor.crt

# View certificate details
openssl x509 -in client-certs/redgatemonitor.crt -text -noout
```

### Check Container Status

```bash
# View running containers
docker ps

# Check container logs
docker logs postgres-node1

# Connect to container shell
docker exec -it postgres-node1 bash
```

## 🐛 Troubleshooting

### Common Issues

#### SSL Connection Errors

- **Private key permissions**: `chmod 600 client-certs/redgatemonitor.key`
- **Certificate verification**: Ensure CA certificate is correct
- **Username mismatch**: Client certificate CN must be `redgatemonitor`

#### Container Issues

- **Port conflicts**: Check if ports 5432-5434 are available
- **Build failures**: Clear Docker cache with `docker system prune`
- **Volume mount issues**: Ensure certificate directories exist

#### Windows-Specific

- **Path separators**: Use forward slashes in connection strings
- **Git Bash**: Recommended terminal for Windows users

### Debug Commands

```bash
# Check PostgreSQL configuration
docker exec postgres-node1 cat /etc/postgresql/17/main/pg_hba.conf

# Verify SSL settings
docker exec postgres-node1 cat /etc/postgresql/17/main/postgresql.conf | grep ssl

# Test internal container connectivity
docker exec postgres-node1 psql "host=postgres-node1 dbname=postgres user=postgres" -c "SELECT version();"
```

## 📋 Features

- ✅ **Docker-based**: Easy deployment and scaling
- ✅ **SSL/TLS Encryption**: All connections encrypted by default
- ✅ **Certificate Authentication**: No password required for secure connections
- ✅ **Centralized CA**: Single root certificate authority
- ✅ **Shared Client Certificates**: One certificate works for all nodes
- ✅ **Windows Compatible**: PKCS#12 bundles and bash scripts
- ✅ **Multi-Platform**: Works with Docker on Windows, Linux, macOS
- ✅ **SSH Access**: SSH keys for container administration
- ✅ **Comprehensive Testing**: Built-in connection verification

## 🔧 Advanced Configuration

### Custom Node Configuration

Edit `setup-cluster.sh` to modify:

- Port assignments
- Container names
- SSL certificate parameters
- PostgreSQL settings

### Certificate Renewal

```bash
# Remove existing certificates
rm -f ca/*

# Regenerate everything
./setup-cluster.sh rebuild
```

### Performance Tuning

Container resources can be adjusted in:

- `docker-compose.yml`: Memory limits, CPU constraints
- `shared/setup.sh`: PostgreSQL configuration parameters

## 📖 Additional Documentation

- **[SSL Connection Guide](SSL_CONNECTION_GUIDE.md)**: Comprehensive SSL setup and troubleshooting
- **[Container Documentation](shared/README.md)**: Docker image details and customization
- **[Certificate Management](ca/README.md)**: CA operations and certificate lifecycle

## 🤝 Contributing

When making changes:

1. Test with bash scripts on different platforms
2. Verify SSL connections work on Windows and Linux
3. Update documentation if adding new features
4. Test certificate generation and renewal
5. Ensure Docker compatibility

## 📜 License

This project is for development and testing purposes. In production environments, ensure proper certificate management and security practices.
