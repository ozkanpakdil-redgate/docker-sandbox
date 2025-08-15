#!/bin/bash
set -e

# Get server name and node ID from environment variables
SERVER_NAME=${SERVER_NAME:-postgres-node1.local}
NODE_ID=${NODE_ID:-1}

echo "Setting up PostgreSQL Node with SERVER_NAME: $SERVER_NAME, NODE_ID: $NODE_ID"

# Update and install necessary packages
apt-get update
apt-get install -y wget gnupg lsb-release openssh-server nano less net-tools iptables rsyslog iputils-ping openssl

# Set up PostgreSQL repository
sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

# Update package list and install PostgreSQL 17
apt-get update
apt-get install -y postgresql-17

# Configure SSH
mkdir -p /var/run/sshd
echo 'root:changeme' | chpasswd
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Configure PostgreSQL
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/17/main/postgresql.conf
sed -i "s/#log_destination = 'stderr'/log_destination = 'csvlog'/" /etc/postgresql/17/main/postgresql.conf
sed -i "s/#logging_collector = off/logging_collector = on/" /etc/postgresql/17/main/postgresql.conf
sed -i "s/#track_io_timing = off/track_io_timing = on/" /etc/postgresql/17/main/postgresql.conf
sed -i "s/#shared_preload_libraries = ''/shared_preload_libraries = 'pg_stat_statements, auto_explain'/" /etc/postgresql/17/main/postgresql.conf
sed -i "s/local   all             postgres                                peer/local   all             postgres                                trust/" /etc/postgresql/17/main/pg_hba.conf
echo "host    all             all             0.0.0.0/0               scram-sha-256" >> /etc/postgresql/17/main/pg_hba.conf
echo "host    all             all             ::/0                    scram-sha-256" >> /etc/postgresql/17/main/pg_hba.conf

# Configure auto_explain
echo "
auto_explain.log_format = 'json'
auto_explain.log_level = 'log'
auto_explain.log_verbose = 'on'
auto_explain.log_analyze = 'on'
auto_explain.log_buffers = 'on'
auto_explain.log_wal = 'on'
auto_explain.log_timing = 'on'
auto_explain.log_triggers = 'on'
auto_explain.sample_rate = 0.01
auto_explain.log_min_duration = 30000
auto_explain.log_nested_statements = 'on'
" >> /etc/postgresql/17/main/postgresql.conf

echo "
shared_buffers = '128MB'  # Adjust based on your shm size
work_mem = '4MB'
maintenance_work_mem = '64MB'
" >> /etc/postgresql/17/main/postgresql.conf

# Generate SSL certificates using the CA
echo "SSL certificate generation will be done at container startup with proper SERVER_NAME"

# Prepare SSL directory structure
mkdir -p /var/lib/postgresql/17/main/ssl
chown postgres:postgres /var/lib/postgresql/17/main/ssl
chmod 700 /var/lib/postgresql/17/main/ssl

# Prepare SSL directory structure but don't enable SSL yet
mkdir -p /var/lib/postgresql/17/main/ssl
chown postgres:postgres /var/lib/postgresql/17/main/ssl
chmod 700 /var/lib/postgresql/17/main/ssl

# Note: SSL configuration will be added at runtime after certificates are generated

# Update pg_hba.conf to configure SSL and non-SSL authentication
sed -i '/host.*all.*all.*0.0.0.0\/0.*scram-sha-256/d' /etc/postgresql/17/main/pg_hba.conf
sed -i '/host.*all.*all.*::\/0.*scram-sha-256/d' /etc/postgresql/17/main/pg_hba.conf

# SSL connections require client certificate authentication (cert method) using Distinguished Name (DN) mapping
echo "hostssl all             all             0.0.0.0/0               cert clientcert=verify-full clientname=DN map=cert_map" >> /etc/postgresql/17/main/pg_hba.conf
echo "hostssl all             all             ::/0                    cert clientcert=verify-full clientname=DN map=cert_map" >> /etc/postgresql/17/main/pg_hba.conf

# Non-SSL connections require password authentication
echo "hostnossl all           all             0.0.0.0/0               scram-sha-256" >> /etc/postgresql/17/main/pg_hba.conf
echo "hostnossl all           all             ::/0                    scram-sha-256" >> /etc/postgresql/17/main/pg_hba.conf

# Local connections (localhost) use password authentication
echo "host    all             all             127.0.0.1/32            scram-sha-256" >> /etc/postgresql/17/main/pg_hba.conf
echo "host    all             all             ::1/128                 scram-sha-256" >> /etc/postgresql/17/main/pg_hba.conf

# Generate SSH keys
ssh-keygen -q -m PEM -t rsa -b 4096 -f /root/.ssh/id_rsa -N ''
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys

# Start PostgreSQL and configure it
service postgresql start
su - postgres -c "psql <<EOF
    ALTER USER postgres WITH PASSWORD 'changeme';
    CREATE DATABASE redgatemonitor;
    -- Create simple username for both password-based and certificate-based connections
    CREATE USER redgatemonitor WITH PASSWORD 'changeme';
    GRANT pg_monitor TO redgatemonitor;
    GRANT ALL PRIVILEGES ON DATABASE redgatemonitor TO redgatemonitor;
EOF"

su - postgres -c "psql -d redgatemonitor <<EOF
    DO \\\$\\\$
    DECLARE
        pg_version integer;
    BEGIN
        SELECT current_setting('server_version_num')::integer INTO pg_version;
        IF pg_version >= 140000 THEN
            EXECUTE 'GRANT ALL PRIVILEGES ON SCHEMA public TO redgatemonitor';
        END IF;
    END
    \\\$\\\$;
    CREATE EXTENSION pg_stat_statements;
    CREATE EXTENSION IF NOT EXISTS file_fdw;
    CREATE SERVER sqlmonitor_file_server FOREIGN DATA WRAPPER file_fdw;
    GRANT pg_read_server_files TO redgatemonitor;
    GRANT EXECUTE ON FUNCTION pg_catalog.pg_current_logfile(text) TO redgatemonitor;
    GRANT USAGE ON FOREIGN SERVER sqlmonitor_file_server TO redgatemonitor;
    GRANT pg_read_all_data TO redgatemonitor;
    
    -- Add node identification
    CREATE TABLE IF NOT EXISTS cluster_info (
        node_name TEXT PRIMARY KEY,
        server_name TEXT,
        setup_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    INSERT INTO cluster_info (node_name, server_name) VALUES ('node${NODE_ID}', '${SERVER_NAME}') 
    ON CONFLICT (node_name) DO UPDATE SET 
        server_name = EXCLUDED.server_name,
        setup_timestamp = CURRENT_TIMESTAMP;
EOF"

# Revert PostgreSQL authentication method
sed -i "s/local   all             postgres                                trust/local   all             postgres                                peer/" /etc/postgresql/17/main/pg_hba.conf

# Stop PostgreSQL (it will be started by the entrypoint script)
service postgresql stop

echo "PostgreSQL Node $SERVER_NAME (Node $NODE_ID) setup completed successfully!"
