Remove-Item -Path "certs" -Recurse -Force -ErrorAction SilentlyContinue
podman rm -f postgresubuntu17
podman build --no-cache --network=host -t postgresubuntu17 .

# Create certs directory if it doesn't exist
if (-not (Test-Path "certs")) {
    New-Item -ItemType Directory -Name "certs" -Force
    Write-Host "Created certs directory" -ForegroundColor Green
}

podman run -dit  --shm-size=256m --name postgresubuntu17 --cap-add SYS_CHROOT --cap-add AUDIT_WRITE --cap-add CAP_NET_RAW -p 5432:5432 -p 22:22 -v ${PWD}\certs:/tmp/certs postgresubuntu17

# Wait for container to fully start
Write-Host "Waiting for container to start..."
Start-Sleep -Seconds 10

# Copy SSH key
podman cp postgresubuntu17:/root/.ssh/id_rsa ./root.key

# Copy SSL certificates
Write-Host "Copying SSL certificates..."

# Copy server certificate (this one usually works)
try {
    podman cp postgresubuntu17:/tmp/certs/server.crt ./certs/server.crt
    Write-Host "✓ Server certificate copied successfully"
} catch {
    Write-Host "⚠ Error copying server certificate: $_"
}

# Copy client certificate and key, with fallback if they're not in /tmp/certs yet
podman cp postgresubuntu17:/var/lib/postgresql/17/main/ssl/redgatemonitor.crt .\certs\redgatemonitor.crt 2>&1
podman cp postgresubuntu17:/var/lib/postgresql/17/main/ssl/redgatemonitor.key .\certs\redgatemonitor.key 2>&1
podman cp postgresubuntu17:/var/lib/postgresql/17/main/ssl/redgatemonitor.pfx .\certs\redgatemonitor.pfx 2>&1

if (Test-Path ".\certs\server.crt") {
    Write-Host ""
    Write-Host "SSL certificates available at: .\certs\"
    Write-Host "  - Server certificate: .\certs\server.crt"
    if (Test-Path ".\certs\redgatemonitor.crt") {
        Write-Host "  - Client certificate: .\certs\redgatemonitor.crt"
    }
    if (Test-Path ".\certs\redgatemonitor.key") {
        Write-Host "  - Client private key: .\certs\redgatemonitor.key"
    }
} else {
    Write-Host "Warning: SSL certificates not found. Container might still be starting."
}

Write-Host "Container is ready!"
Write-Host "PostgreSQL SSL connection with client cert (passwordless): psql `"host=localhost port=5432 dbname=redgatemonitor user=redgatemonitor sslmode=require sslcert=./certs/redgatemonitor.crt sslkey=./certs/redgatemonitor.key sslrootcert=./certs/server.crt`""
Write-Host "PostgreSQL non-SSL connection (password required): psql `"host=localhost port=5432 dbname=redgatemonitor user=redgatemonitor password=changeme sslmode=disable`""
Write-Host "PostgreSQL SSL with full cert verification: psql `"host=localhost port=5432 dbname=redgatemonitor user=redgatemonitor sslmode=verify-ca sslcert=./certs/redgatemonitor.crt sslkey=./certs/redgatemonitor.key sslrootcert=./certs/server.crt`""
Write-Host "SSH connection: ssh -i root.key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@localhost"
Write-Host ""
Write-Host "To connect via SSH, run:"
Write-Host "ssh -i root.key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@localhost"
Write-Host ""
Write-Host "In case of SSH issues, run:"
Write-Host "podman exec -it postgresubuntu17 bash"