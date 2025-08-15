# Certificate Authority Directory

This directory contains the centralized Certificate Authority (CA) files for the PostgreSQL cluster.

## Generated Files (Not in Git)

The following files are generated automatically when you run the cluster setup and are **NOT** committed to git for security reasons:

- `ca.crt` - Root Certificate Authority certificate
- `ca.key` - Root CA private key (**HIGHLY SENSITIVE**)
- `redgatemonitor.crt` - Shared client certificate for all nodes
- `redgatemonitor.key` - Shared client private key (**SENSITIVE**)
- `redgatemonitor.pfx` - Client certificate bundle for Windows (**SENSITIVE**)

## Scripts (In Git)

- `generate-ca.sh` - Script to generate the root CA and shared client certificates
- `generate-server-cert.sh` - Script to generate server certificates for each node

## Security Notes

⚠️ **IMPORTANT**: The private key files (`*.key`, `*.pfx`) contain sensitive cryptographic material and should NEVER be committed to version control or shared publicly.

The cluster setup automatically generates these certificates when needed, so there's no need to manually create or distribute them.
