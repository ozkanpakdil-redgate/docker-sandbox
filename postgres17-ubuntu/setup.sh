#!/bin/bash
set -e

# Update and install necessary packages
apt-get update
apt-get install -y wget gnupg lsb-release openssh-server nano less  net-tools iptables rsyslog iputils-ping openssl

# Set up PostgreSQL repository
sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

# Update package list and install PostgreSQL 17 and NFS
apt-get update
apt-get install -y postgresql-17 nfs-kernel-server nfs-common

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

# Generate SSL certificates for PostgreSQL
mkdir -p /var/lib/postgresql/17/main/ssl
cd /var/lib/postgresql/17/main/ssl

# Generate server private key
openssl genrsa -out server.key 4096
chmod 600 server.key

# Generate server certificate signing request
openssl req -new -key server.key -out server.csr -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=127.0.0.1"

# Generate self-signed server certificate (valid for 365 days)
openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt

# Generate client private key for redgatemonitor user
openssl genrsa -out redgatemonitor.key 4096
chmod 600 redgatemonitor.key

# Generate client certificate signing request
openssl req -new -key redgatemonitor.key -out redgatemonitor.csr -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=redgatemonitor"

# Generate client certificate signed by server certificate (acting as CA)
openssl x509 -req -days 365 -in redgatemonitor.csr -CA server.crt -CAkey server.key -CAcreateserial -out redgatemonitor.crt

# Generate PFX file combining client certificate and private key (for Windows import)
openssl pkcs12 -export -out redgatemonitor.pfx -inkey redgatemonitor.key -in redgatemonitor.crt -certfile server.crt -password pass:changeme

# Set proper ownership and permissions
chown postgres:postgres server.key server.crt server.csr redgatemonitor.key redgatemonitor.crt redgatemonitor.csr redgatemonitor.pfx
chmod 600 server.key redgatemonitor.key redgatemonitor.pfx
chmod 644 server.crt redgatemonitor.crt

# Enable SSL in PostgreSQL configuration
echo "
# SSL Configuration
ssl = on
ssl_cert_file = '/var/lib/postgresql/17/main/ssl/server.crt'
ssl_key_file = '/var/lib/postgresql/17/main/ssl/server.key'
ssl_ca_file = '/var/lib/postgresql/17/main/ssl/server.crt'
ssl_crl_file = ''
ssl_prefer_server_ciphers = on
ssl_ecdh_curve = 'prime256v1'
ssl_min_protocol_version = 'TLSv1.2'
ssl_max_protocol_version = ''
" >> /etc/postgresql/17/main/postgresql.conf

# Update pg_hba.conf to configure SSL and non-SSL authentication
sed -i '/host.*all.*all.*0.0.0.0\/0.*scram-sha-256/d' /etc/postgresql/17/main/pg_hba.conf
sed -i '/host.*all.*all.*::\/0.*scram-sha-256/d' /etc/postgresql/17/main/pg_hba.conf

# SSL connections require client certificate authentication (cert method)
echo "hostssl all             all             0.0.0.0/0               cert clientcert=verify-full" >> /etc/postgresql/17/main/pg_hba.conf
echo "hostssl all             all             ::/0                    cert clientcert=verify-full" >> /etc/postgresql/17/main/pg_hba.conf

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
EOF"

# Revert PostgreSQL authentication method
sed -i "s/local   all             postgres                                trust/local   all             postgres                                peer/" /etc/postgresql/17/main/pg_hba.conf

# Stop PostgreSQL (it will be started by the entrypoint script)
service postgresql stop