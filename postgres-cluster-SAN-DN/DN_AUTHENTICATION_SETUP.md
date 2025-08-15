# PostgreSQL Cluster - DN Authentication with Identity Mapping

## How It Works

PostgreSQL authenticates users using **Distinguished Name (DN) mapping** from client certificates. Instead of creating users with complex DN names, we use `pg_ident.conf` to map certificate DNs to simple PostgreSQL usernames.

**Certificate DN**: `CN=alien,OU=Client,O=PostgreSQLCluster,L=City,ST=State,C=US`  
**PostgreSQL User**: `redgatemonitor` (simple username)

## Configuration

### Identity Mapping (`pg_ident.conf`)

```conf
# MAPNAME             SYSTEM-USERNAME      PG-USERNAME  
cert_map   "CN=alien,OU=Client,O=PostgreSQLCluster,L=City,ST=State,C=US"    redgatemonitor
```

### Database Users

- `redgatemonitor` - Single user for both SSL and password authentication

### PostgreSQL Settings

- `pg_hba.conf`: Uses `map=redgatemonitor_map` for SSL connections
- Client certificates mapped to PostgreSQL roles via identity mapping

## Quick Start

```bash
# Start the cluster  
./setup-cluster.sh start
```

## Connection Examples

**SSL with Certificate Authentication:**

```bash
psql "host=localhost port=5432 dbname=redgatemonitor user=redgatemonitor sslmode=require sslcert=./node1/certs/redgatemonitor.crt sslkey=./node1/certs/redgatemonitor.key sslrootcert=./node1/certs/ca.crt"
```

**Non-SSL with Password Authentication:**

```bash
psql "host=localhost port=5432 dbname=redgatemonitor user=redgatemonitor password=changeme sslmode=disable"
```

## Benefits

- Clean usernames (no DN strings in database)
- Standard PostgreSQL identity mapping approach
- Flexible certificate-to-user mapping
