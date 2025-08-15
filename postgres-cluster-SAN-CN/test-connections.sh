#!/bin/bash

# PostgreSQL Cluster Connection Test Script

echo "PostgreSQL Multi-Node Cluster Connection Test"
echo "=============================================="

# Test each node
for i in 1 2 3; do
    port=$((5431 + i))
    ssh_port=$((2200 + i))
    
    echo ""
    echo "Testing Node$i (Port: $port, SSH: $ssh_port):"
    echo "---------------------------------------------"
    
    # Test basic connection
    echo "Testing non-SSL connection..."
    if timeout 10 docker exec postgres-node$i psql -h localhost -p 5432 -U redgatemonitor -d redgatemonitor -c "SELECT 'Node$i connection successful' as result, current_timestamp;" <<< "changeme" 2>/dev/null; then
        echo "✓ Non-SSL connection successful"
    else
        echo "✗ Non-SSL connection failed"
    fi
    
    # Test SSL certificate existence
    if [ -f "./node$i/certs/server.crt" ]; then
        echo "✓ Server certificate exists"
    else
        echo "✗ Server certificate missing"
    fi
    
    if [ -f "./node$i/certs/redgatemonitor.crt" ]; then
        echo "✓ Client certificate exists"
    else
        echo "✗ Client certificate missing"
    fi
    
    # Test SSH key
    if [ -f "./node$i/root.key" ]; then
        echo "✓ SSH key exists"
    else
        echo "✗ SSH key missing"
    fi
done

echo ""
echo "Connection Examples:"
echo "--------------------"
echo "Node1 (Port 5432): psql \"host=localhost port=5432 dbname=redgatemonitor user=redgatemonitor password=changeme sslmode=disable\""
echo "Node2 (Port 5433): psql \"host=localhost port=5433 dbname=redgatemonitor user=redgatemonitor password=changeme sslmode=disable\""  
echo "Node3 (Port 5434): psql \"host=localhost port=5434 dbname=redgatemonitor user=redgatemonitor password=changeme sslmode=disable\""
echo ""
echo "SSL Examples (using shared client certificate and CA):"
echo "Node1 SSL: psql \"host=localhost port=5432 dbname=redgatemonitor user=redgatemonitor sslmode=require sslcert=./client-certs/redgatemonitor.crt sslkey=./client-certs/redgatemonitor.key sslrootcert=./client-certs/ca.crt\""
echo "Node2 SSL: psql \"host=localhost port=5433 dbname=redgatemonitor user=redgatemonitor sslmode=require sslcert=./client-certs/redgatemonitor.crt sslkey=./client-certs/redgatemonitor.key sslrootcert=./client-certs/ca.crt\""
echo "Node3 SSL: psql \"host=localhost port=5434 dbname=redgatemonitor user=redgatemonitor sslmode=require sslcert=./client-certs/redgatemonitor.crt sslkey=./client-certs/redgatemonitor.key sslrootcert=./client-certs/ca.crt\""
