#!/bin/bash
set -e

# Use Redhat subscription to register container
subscription-manager register --username changeme --password changeme

# Update and install necessary packages
dnf update -y
dnf install -y info wget gnupg openssh-server less

# Set up PostgreSQL repository
dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm

# Update package list and install PostgreSQL 17 and NFS
dnf install -y postgresql17-server postgresql17-contrib
dnf -y install nfs-utils

# Configure SSH
mkdir -p /var/run/sshd
echo 'root:changeme' | chpasswd

# Configure PostgreSQL
su - postgres -c "/usr/pgsql-17/bin/initdb -D /var/lib/pgsql/17/data"
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /var/lib/pgsql/17/data/postgresql.conf
sed -i "s/#log_destination = 'stderr'/log_destination = 'csvlog'/" /var/lib/pgsql/17/data/postgresql.conf
sed -i "s/#logging_collector = off/logging_collector = on/" /var/lib/pgsql/17/data/postgresql.conf
sed -i "s/#track_io_timing = off/track_io_timing = on/" /var/lib/pgsql/17/data/postgresql.conf
sed -i "s/#shared_preload_libraries = ''/shared_preload_libraries = 'pg_stat_statements, auto_explain'/" /var/lib/pgsql/17/data/postgresql.conf
sed -i "s/local   all             postgres                                peer/local   all             postgres                                trust/" /var/lib/pgsql/17/data/pg_hba.conf
echo "host    all             all             0.0.0.0/0               scram-sha-256" >> /var/lib/pgsql/17/data/pg_hba.conf
echo "host    all             all             ::/0                    scram-sha-256" >> /var/lib/pgsql/17/data/pg_hba.conf

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
" >> /var/lib/pgsql/17/data/postgresql.conf

# Generate SSH keys
ssh-keygen -q -m PEM -t rsa -b 4096 -f /root/.ssh/id_rsa -N ''
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys

# Start PostgreSQL and configure it
su - postgres -c "/usr/pgsql-17/bin/pg_ctl -D /var/lib/pgsql/17/data/ -l logfile start"
su - postgres -c "psql -c \"ALTER USER postgres WITH PASSWORD 'changeme';\""
su - postgres -c "psql -c \"CREATE EXTENSION pg_stat_statements;\""

# Revert PostgreSQL authentication method
sed -i "s/local   all             postgres                                trust/local   all             postgres                                peer/" /var/lib/pgsql/17/data/pg_hba.conf

# Stop PostgreSQL (it will be started by the entrypoint script)
su - postgres -c "/usr/pgsql-17/bin/pg_ctl -D /var/lib/pgsql/17/data/ stop"