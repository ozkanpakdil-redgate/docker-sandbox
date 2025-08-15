#!/bin/bash
# PostgreSQL Cluster Setup Script with DN Authentication
# Converts all PowerShell functionality to pure bash

set -e

# Configuration
ACTION="${1:-start}"
NODES=("node1" "node2" "node3")

# Node configurations
declare -A NODE_CONFIGS
NODE_CONFIGS[node1,container]="postgres-node1"
NODE_CONFIGS[node1,pg_port]="5432"
NODE_CONFIGS[node1,ssh_port]="2201"
NODE_CONFIGS[node1,server_name]="postgres-node1.local"
NODE_CONFIGS[node1,node_id]="1"

NODE_CONFIGS[node2,container]="postgres-node2"
NODE_CONFIGS[node2,pg_port]="5433"
NODE_CONFIGS[node2,ssh_port]="2202"
NODE_CONFIGS[node2,server_name]="postgres-node2.local"
NODE_CONFIGS[node2,node_id]="2"

NODE_CONFIGS[node3,container]="postgres-node3"
NODE_CONFIGS[node3,pg_port]="5434"
NODE_CONFIGS[node3,ssh_port]="2203"
NODE_CONFIGS[node3,server_name]="postgres-node3.local"
NODE_CONFIGS[node3,node_id]="3"

IMAGE_TAG="postgres-cluster"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color output functions
print_color() {
    local message="$1"
    local color="$2"
    case $color in
        "red") echo -e "\033[31m$message\033[0m" ;;
        "green") echo -e "\033[32m$message\033[0m" ;;
        "yellow") echo -e "\033[33m$message\033[0m" ;;
        "blue") echo -e "\033[34m$message\033[0m" ;;
        "magenta") echo -e "\033[35m$message\033[0m" ;;
        "cyan") echo -e "\033[36m$message\033[0m" ;;
        "gray") echo -e "\033[37m$message\033[0m" ;;
        *) echo "$message" ;;
    esac
}

stop_all_nodes() {
    print_color "Stopping all PostgreSQL nodes..." "yellow"
    for node in "${NODES[@]}"; do
        local container_name="${NODE_CONFIGS[$node,container]}"
        print_color "Stopping $node..." "gray"
        docker rm -f "$container_name" 2>/dev/null || true
    done
    print_color "All nodes stopped." "green"
}

generate_ca() {
    print_color "Generating Root CA and shared client certificates..." "cyan"
    
    cd "$SCRIPT_DIR/ca"
    
    # Check if CA already exists
    if [[ -f "ca.crt" ]]; then
        print_color "✓ Root CA already exists, skipping generation" "green"
        cd "$SCRIPT_DIR"
        return
    fi
    
    # Run the CA generation script
    ./generate-ca.sh
    
    print_color "✓ Root CA and shared client certificates generated successfully!" "green"
    cd "$SCRIPT_DIR"
}

build_all_nodes() {
    print_color "Building shared Docker image for all nodes..." "cyan"
    
    # Ensure CA is generated
    generate_ca
    
    cd "$SCRIPT_DIR"
    docker build --no-cache --network=host -t "$IMAGE_TAG" -f ./shared/Dockerfile .
}

start_node() {
    local node_name="$1"
    local container_name="${NODE_CONFIGS[$node_name,container]}"
    local pg_port="${NODE_CONFIGS[$node_name,pg_port]}"
    local ssh_port="${NODE_CONFIGS[$node_name,ssh_port]}"
    local server_name="${NODE_CONFIGS[$node_name,server_name]}"
    local node_id="${NODE_CONFIGS[$node_name,node_id]}"
    
    print_color "Starting $node_name..." "cyan"
    
    # Create node-specific certs directory
    local certs_dir="$SCRIPT_DIR/$node_name/certs"
    mkdir -p "$certs_dir"
    print_color "Created certs directory for $node_name" "green"
    
    # Convert paths to Windows format for Docker (Git Bash on Windows compatibility)
    local docker_certs_dir
    local docker_ca_dir
    if command -v cygpath >/dev/null 2>&1; then
        # Use cygpath to convert paths for Docker on Windows
        docker_certs_dir=$(cygpath -w "$certs_dir")
        docker_ca_dir=$(cygpath -w "$SCRIPT_DIR/ca")
    else
        # Fallback to direct paths for Linux/Mac
        docker_certs_dir="$certs_dir"
        docker_ca_dir="$SCRIPT_DIR/ca"
    fi
    
    print_color "Debug: docker_certs_dir = '$docker_certs_dir'" "gray"
    print_color "Debug: docker_ca_dir = '$docker_ca_dir'" "gray"
    
    # Start container with node-specific parameters
    docker run -dit --shm-size=256m --name "$container_name" \
        --cap-add SYS_CHROOT --cap-add AUDIT_WRITE --cap-add CAP_NET_RAW \
        -p "${pg_port}:5432" -p "${ssh_port}:22" \
        -v "${docker_certs_dir}:/tmp/certs" \
        -v "${docker_ca_dir}:/tmp/ca:rw" \
        -e SERVER_NAME="$server_name" \
        -e NODE_ID="$node_id" \
        "$IMAGE_TAG"
    
    # Wait for container to start
    print_color "Waiting for $node_name to start..." "gray"
    sleep 15
    
    # Copy SSH key
    if docker cp "$container_name:/root/.ssh/id_rsa" "$SCRIPT_DIR/$node_name/root.key" 2>/dev/null; then
        print_color "✓ SSH key copied for $node_name" "green"
    else
        print_color "⚠ Error copying SSH key for $node_name" "red"
    fi
    
    # Copy SSL certificates
    print_color "Copying SSL certificates for $node_name..." "gray"
    
    local success=true
    # Copy server certificate
    if ! docker cp "$container_name:/tmp/certs/server.crt" "$certs_dir/server.crt" 2>/dev/null; then
        success=false
    fi
    # Copy CA certificate
    if ! docker cp "$container_name:/tmp/certs/ca.crt" "$certs_dir/ca.crt" 2>/dev/null; then
        success=false
    fi
    # Copy shared client certificates
    if ! docker cp "$container_name:/tmp/certs/redgatemonitor.crt" "$certs_dir/redgatemonitor.crt" 2>/dev/null; then
        success=false
    fi
    if ! docker cp "$container_name:/tmp/certs/redgatemonitor.key" "$certs_dir/redgatemonitor.key" 2>/dev/null; then
        success=false
    fi
    if ! docker cp "$container_name:/tmp/certs/redgatemonitor.pfx" "$certs_dir/redgatemonitor.pfx" 2>/dev/null; then
        success=false
    fi
    
    if $success; then
        print_color "✓ SSL certificates copied for $node_name" "green"
    else
        print_color "⚠ Some certificates may not have been copied for $node_name" "red"
    fi
    
    if [[ -f "$certs_dir/server.crt" ]]; then
        print_color "✓ SSL certificates available for $node_name at: ./$node_name/certs/" "green"
    fi
}

show_connection_info() {
    echo ""
    print_color "================================================================================" "magenta"
    print_color "PostgreSQL Cluster Connection Information (DN Authentication)" "magenta"
    print_color "================================================================================" "magenta"
    
    for node in "${NODES[@]}"; do
        local container_name="${NODE_CONFIGS[$node,container]}"
        local pg_port="${NODE_CONFIGS[$node,pg_port]}"
        local ssh_port="${NODE_CONFIGS[$node,ssh_port]}"
        
        echo ""
        print_color "$node ($container_name):" "yellow"
        print_color "  PostgreSQL Port: $pg_port" "white"
        print_color "  SSH Port: $ssh_port" "white"
        print_color "  SSL Connection (Certificate Auth with DN mapping):" "white"
        print_color "    psql \"host=localhost port=$pg_port dbname=redgatemonitor user=redgatemonitor sslmode=verify-full sslcert=./$node/certs/redgatemonitor.crt sslkey=./$node/certs/redgatemonitor.key sslrootcert=./$node/certs/ca.crt\"" "cyan"
        print_color "  Non-SSL Connection:" "white"
        print_color "    psql \"host=localhost port=$pg_port dbname=redgatemonitor user=redgatemonitor password=changeme sslmode=disable\"" "cyan"
        print_color "  SSH Connection:" "white"
        print_color "    ssh -i $node/root.key -p $ssh_port -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@localhost" "cyan"
    done
    
    echo ""
    print_color "Quick connect scripts:" "yellow"
}

copy_client_certs() {
    # Create client-certs directory for easy access
    local client_certs_dir="$SCRIPT_DIR/client-certs"
    mkdir -p "$client_certs_dir"
    
    if [[ -f "$SCRIPT_DIR/ca/ca.crt" ]]; then
        cp "$SCRIPT_DIR/ca/ca.crt" "$client_certs_dir/"
        cp "$SCRIPT_DIR/ca/redgatemonitor.crt" "$client_certs_dir/"
        cp "$SCRIPT_DIR/ca/redgatemonitor.key" "$client_certs_dir/"
        if [[ -f "$SCRIPT_DIR/ca/redgatemonitor.pfx" ]]; then
            cp "$SCRIPT_DIR/ca/redgatemonitor.pfx" "$client_certs_dir/"
        fi
        if [[ -f "$SCRIPT_DIR/ca/redgatemonitor-nopass.pfx" ]]; then
            cp "$SCRIPT_DIR/ca/redgatemonitor-nopass.pfx" "$client_certs_dir/"
        fi
        print_color "✓ Client certificates copied to ./client-certs/" "green"
    fi
}

# Main execution
case "${ACTION,,}" in
    "stop")
        stop_all_nodes
        ;;
    "rebuild")
        stop_all_nodes
        build_all_nodes
        for node in "${NODES[@]}"; do
            start_node "$node"
        done
        copy_client_certs
        show_connection_info
        ;;
    "start")
        # Check if containers are already running
        running_containers=$(docker ps --format "{{.Names}}" 2>/dev/null || echo "")
        needs_rebuild=false
        
        for node in "${NODES[@]}"; do
            container_name="${NODE_CONFIGS[$node,container]}"
            if ! echo "$running_containers" | grep -q "^${container_name}$"; then
                # Check if image exists
                if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${IMAGE_TAG}:latest$"; then
                    needs_rebuild=true
                    break
                fi
            fi
        done
        
        if $needs_rebuild; then
            print_color "Some nodes need to be built. Building all nodes..." "yellow"
            stop_all_nodes
            build_all_nodes
            for node in "${NODES[@]}"; do
                start_node "$node"
            done
        else
            for node in "${NODES[@]}"; do
                container_name="${NODE_CONFIGS[$node,container]}"
                if ! echo "$running_containers" | grep -q "^${container_name}$"; then
                    start_node "$node"
                fi
            done
        fi
        
        copy_client_certs
        show_connection_info
        ;;
    *)
        print_color "Usage: $0 {start|stop|rebuild}" "red"
        print_color "Actions:" "yellow"
        print_color "  start   - Start all nodes (build if necessary)" "white"
        print_color "  stop    - Stop all nodes" "white"
        print_color "  rebuild - Stop, rebuild, and start all nodes" "white"
        exit 1
        ;;
esac
