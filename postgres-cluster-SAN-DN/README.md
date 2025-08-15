# PostgreSQL Cluster with SSL/TLS and DN Authentication

A Docker-based PostgreSQL 17 cluster with SSL/TLS encryption and Distinguished Name (DN) certificate authentication. Uses a centralized Certificate Authority (CA) with shared client certificates.

## 🔐 Authentication

**DN Format**: `CN=redgatemonitor`

- **SSL with DN Authentication**: `user=CN=redgatemonitor` + client certificates
- **Password Authentication**: `user=redgatemonitor` + `sslmode=disable`

## 🚀 Quick Start

### Prerequisites

- Docker
- PostgreSQL client (psql) - optional

### Start the Cluster

```bash
# Start all nodes
./setup-cluster.sh start

# Rebuild from scratch  
./setup-cluster.sh rebuild

# Stop all nodes
./setup-cluster.sh stop
```

## 🏗️ Cluster Configuration

| Node | Port | SSH | Container |
|------|------|-----|-----------|
| Node 1 | 5432 | 2201 | postgres-node1 |
| Node 2 | 5433 | 2202 | postgres-node2 |
| Node 3 | 5434 | 2203 | postgres-node3 |

## 🔐 Connections

### SSL with DN Authentication

```bash
# Use user=CN=redgatemonitor for SSL connections
psql "host=localhost port=5432 dbname=redgatemonitor user=CN=redgatemonitor sslmode=verify-full sslcert=node1/certs/redgatemonitor.crt sslkey=node1/certs/redgatemonitor.key sslrootcert=node1/certs/ca.crt"

# Change port and node for different nodes: 
# node1: port=5432, certs in node1/certs/
# node2: port=5433, certs in node2/certs/  
# node3: port=5434, certs in node3/certs/
```

### Password Authentication

```bash
# Use user=redgatemonitor for password connections
psql "host=localhost port=5432 dbname=redgatemonitor user=redgatemonitor password=changeme sslmode=disable"
```

## 📁 Directory Structure

```text
├── ca/                         # Certificate Authority
│   ├── ca.crt                 # Root CA certificate  
│   ├── redgatemonitor.crt     # Client certificate
│   ├── redgatemonitor.key     # Client private key
│   └── redgatemonitor.pfx     # Windows PKCS#12 bundle
├── node1-3/certs/             # Node-specific certificates (includes client certs)
├── shared/                    # Docker configuration
├── docker-compose.yml         # Docker Compose setup
├── setup-cluster.sh          # Main setup script
```

## � Testing

```bash
# Manual certificate verification (use any node's certs)
openssl verify -CAfile node1/certs/ca.crt node1/certs/redgatemonitor.crt

# Check container status
docker ps
```

## 🐛 Troubleshooting

### Common Issues

- **SSL Authentication**: Use `user=CN=redgatemonitor` for SSL, `user=redgatemonitor` for password
- **Certificate errors**: Check `chmod 600` on private keys
- **Port conflicts**: Ensure ports 5432-5434 are available
- **Container issues**: Try `docker system prune` and rebuild

### Debug Commands

```bash
# Check PostgreSQL authentication config
docker exec postgres-node1 grep -E "(hostssl|clientname)" /etc/postgresql/17/main/pg_hba.conf

# View container logs
docker logs postgres-node1
```

## 📋 Features

- ✅ **Docker-based**: Easy deployment and scaling
- ✅ **SSL/TLS Encryption**: All connections encrypted by default  
- ✅ **DN Authentication**: Certificate-based authentication
- ✅ **Shared Certificates**: One client certificate works for all nodes
- ✅ **Multi-Platform**: Works on Windows, Linux, macOS

## 📖 Additional Documentation

- [SSL Connection Guide](SSL_CONNECTION_GUIDE.md): Detailed SSL setup
- [DN Authentication Setup](DN_AUTHENTICATION_SETUP.md): DN configuration details
