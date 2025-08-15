#!/bin/bash
# PostgreSQL Cluster Management Script
# Enhanced bash version with full functionality equivalent to the original PowerShell script

set -e

ACTION=${1:-start}
NODES=${2:-"node1,node2,node3"}

# Configuration for each node
declare -A NODE_CONFIGS
NODE_CONFIGS[node1]="postgres-node1|5432|2201|postgres-node1.local|1"
NODE_CONFIGS[node2]="postgres-node2|5433|2202|postgres-node2.local|2"
NODE_CONFIGS[node3]="postgres-node3|5434|2203|postgres-node3.local|3"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;37m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

print_color() {
    echo -e "${1}${2}${NC}"
}

stop_all_nodes() {
    print_color "$YELLOW" "Stopping all PostgreSQL nodes..."
    IFS=',' read -ra NODE_ARRAY <<< "$NODES"
    for node in "${NODE_ARRAY[@]}"; do
        if [[ -n "${NODE_CONFIGS[$node]}" ]]; then
            IFS='|' read -ra config <<< "${NODE_CONFIGS[$node]}"
            container_name="${config[0]}"
            print_color "$GRAY" "Stopping $node..."
            docker rm -f "$container_name" 2>/dev/null || true
        fi
    done
    print_color "$GREEN" "All nodes stopped."
}

generate_ca() {
    print_color "$CYAN" "Generating Root CA and shared client certificates..."
    
    cd ca
    
    # Check if CA already exists
    if [[ -f "ca.crt" ]]; then
        print_color "$GREEN" "✓ Root CA already exists, skipping generation"
        cd ..
        return
    fi
    
    # Run the CA generation script
    bash ./generate-ca.sh
    
    print_color "$GREEN" "✓ Root CA and shared client certificates generated successfully!"
    cd ..
}

build_all_nodes() {
    print_color "$CYAN" "Building shared Docker image for all nodes..."
    
    # Ensure CA is generated
    generate_ca
    
    docker build --no-cache --network=host -t postgres-cluster -f ./shared/Dockerfile .
}

start_node() {
    local node_name=$1
    
    if [[ -z "${NODE_CONFIGS[$node_name]}" ]]; then
        print_color "$RED" "Error: Unknown node $node_name"
        return 1
    fi
    
    IFS='|' read -ra config <<< "${NODE_CONFIGS[$node_name]}"
    local container_name="${config[0]}"
    local postgres_port="${config[1]}"
    local ssh_port="${config[2]}"
    local server_name="${config[3]}"
    local node_id="${config[4]}"
    
    print_color "$CYAN" "Starting $node_name..."
    
    # Create node-specific certs directory
    local certs_dir="./$node_name/certs"
    mkdir -p "$certs_dir"
    print_color "$GREEN" "Created certs directory for $node_name"
    
    # Get current directory in format compatible with Docker on Windows
    local current_dir
    if [[ "$OSTYPE" == "msys" ]] || [[ -n "$MSYSTEM" ]]; then
        # Running in Git Bash on Windows - use pwd -W to get Windows path
        current_dir="$(pwd -W | sed 's|\\|/|g')"
    else
        # Running on Linux/macOS
        current_dir="$(pwd)"
    fi
    
    # Start container with node-specific parameters
    docker run -dit --shm-size=256m --name "$container_name" \
        --cap-add SYS_CHROOT --cap-add AUDIT_WRITE --cap-add CAP_NET_RAW \
        -p "$postgres_port:5432" -p "$ssh_port:22" \
        -v "${current_dir}/${node_name}/certs:/tmp/certs" \
        -v "${current_dir}/ca:/tmp/ca" \
        -e SERVER_NAME="$server_name" \
        -e NODE_ID="$node_id" \
        postgres-cluster
    
    # Wait for container to start
    print_color "$GRAY" "Waiting for $node_name to start..."
    sleep 15
    
    # Copy SSH key
    print_color "$GRAY" "Copying SSH key for $node_name..."
    if ! docker cp "$container_name:/root/.ssh/id_rsa" "./$node_name/root.key"; then
        print_color "$RED" "✗ Error copying SSH key for $node_name"
        exit 1
    fi
    print_color "$GREEN" "✓ SSH key copied for $node_name"
    
    # Copy SSL certificates
    print_color "$GRAY" "Copying SSL certificates for $node_name..."
    
    # Copy server certificate (required)
    if ! docker cp "$container_name:/tmp/certs/server.crt" "$certs_dir/server.crt"; then
        print_color "$RED" "✗ Error copying server certificate for $node_name"
        exit 1
    fi
    
    # Copy server private key (required)
    if ! docker cp "$container_name:/tmp/certs/server.key" "$certs_dir/server.key"; then
        print_color "$RED" "✗ Error copying server private key for $node_name"
        exit 1
    fi
    
    # Copy CA certificate (required)
    if ! docker cp "$container_name:/tmp/certs/ca.crt" "$certs_dir/ca.crt"; then
        print_color "$RED" "✗ Error copying CA certificate for $node_name"
        exit 1
    fi
    
    # Copy shared client certificates (required)
    if ! docker cp "$container_name:/tmp/certs/redgatemonitor.crt" "$certs_dir/redgatemonitor.crt"; then
        print_color "$RED" "✗ Error copying client certificate for $node_name"
        exit 1
    fi
    
    if ! docker cp "$container_name:/tmp/certs/redgatemonitor.key" "$certs_dir/redgatemonitor.key"; then
        print_color "$RED" "✗ Error copying client key for $node_name"
        exit 1
    fi
    
    if ! docker cp "$container_name:/tmp/certs/redgatemonitor.pfx" "$certs_dir/redgatemonitor.pfx"; then
        print_color "$RED" "✗ Error copying client PFX for $node_name"
        exit 1
    fi
    
    print_color "$GREEN" "✓ SSL certificates copied for $node_name"
}

show_connection_info() {
    print_color "$MAGENTA" ""
    print_color "$MAGENTA" "================================================================================"
    print_color "$MAGENTA" "PostgreSQL Cluster Connection Information"
    print_color "$MAGENTA" "================================================================================"
    
    IFS=',' read -ra NODE_ARRAY <<< "$NODES"
    for node in "${NODE_ARRAY[@]}"; do
        if [[ -n "${NODE_CONFIGS[$node]}" ]]; then
            IFS='|' read -ra config <<< "${NODE_CONFIGS[$node]}"
            local container_name="${config[0]}"
            local postgres_port="${config[1]}"
            local ssh_port="${config[2]}"
            
            print_color "$YELLOW" ""
            print_color "$YELLOW" "$node ($container_name):"
            print_color "$WHITE" "  PostgreSQL Port: $postgres_port"
            print_color "$WHITE" "  SSH Port: $ssh_port"
            print_color "$CYAN" "  SSL Connection: psql \"host=localhost port=$postgres_port dbname=redgatemonitor user=redgatemonitor sslmode=verify-full sslcert=./$node/certs/redgatemonitor.crt sslkey=./$node/certs/redgatemonitor.key sslrootcert=./$node/certs/ca.crt\""
            print_color "$CYAN" "  Non-SSL Connection: psql \"host=localhost port=$postgres_port dbname=redgatemonitor user=redgatemonitor password=changeme sslmode=disable\""
            print_color "$CYAN" "  SSH Connection: ssh -i $node/root.key -p $ssh_port -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@localhost"
        fi
    done
}

# Main execution
case $ACTION in
    "stop")
        stop_all_nodes
        ;;
    "build")
        build_all_nodes
        ;;
    "rebuild")
        stop_all_nodes
        build_all_nodes
        IFS=',' read -ra NODE_ARRAY <<< "$NODES"
        for node in "${NODE_ARRAY[@]}"; do
            start_node "$node"
        done
        show_connection_info
        ;;
    "start")
        # Check if containers are already running
        running_containers=$(docker ps --format "{{.Names}}" 2>/dev/null || echo "")
        needs_rebuild=false
        
        IFS=',' read -ra NODE_ARRAY <<< "$NODES"
        for node in "${NODE_ARRAY[@]}"; do
            if [[ -n "${NODE_CONFIGS[$node]}" ]]; then
                IFS='|' read -ra config <<< "${NODE_CONFIGS[$node]}"
                container_name="${config[0]}"
                if ! echo "$running_containers" | grep -q "^$container_name$"; then
                    # Check if image exists
                    if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "postgres-cluster:latest"; then
                        needs_rebuild=true
                        break
                    fi
                fi
            fi
        done
        
        if $needs_rebuild; then
            print_color "$YELLOW" "Some nodes need to be built. Building all nodes..."
            stop_all_nodes
            build_all_nodes
            for node in "${NODE_ARRAY[@]}"; do
                start_node "$node"
            done
        else
            for node in "${NODE_ARRAY[@]}"; do
                if [[ -n "${NODE_CONFIGS[$node]}" ]]; then
                    IFS='|' read -ra config <<< "${NODE_CONFIGS[$node]}"
                    container_name="${config[0]}"
                    if ! echo "$running_containers" | grep -q "^$container_name$"; then
                        start_node "$node"
                    fi
                fi
            done
        fi
        
        # Copy client certificates for easy access
        print_color "$GRAY" "Copying shared client certificates to ./client-certs/..."
        mkdir -p ./client-certs
        if ! docker cp postgres-node1:/tmp/ca/redgatemonitor.crt ./client-certs/; then
            print_color "$RED" "✗ Error copying shared client certificate"
            exit 1
        fi
        if ! docker cp postgres-node1:/tmp/ca/redgatemonitor.key ./client-certs/; then
            print_color "$RED" "✗ Error copying shared client key"
            exit 1
        fi
        if ! docker cp postgres-node1:/tmp/ca/ca.crt ./client-certs/; then
            print_color "$RED" "✗ Error copying CA certificate"
            exit 1
        fi
        if ! docker cp postgres-node1:/tmp/ca/redgatemonitor.pfx ./client-certs/; then
            print_color "$RED" "✗ Error copying shared client PFX"
            exit 1
        fi
        print_color "$GREEN" "✓ Shared client certificates copied to ./client-certs/"
        
        show_connection_info
        ;;
    *)
        print_color "$RED" "Usage: $0 {start|stop|build|rebuild} [node1,node2,node3]"
        print_color "$YELLOW" "Actions:"
        print_color "$WHITE" "  start   - Start all nodes (build if necessary)"
        print_color "$WHITE" "  stop    - Stop all nodes"
        print_color "$WHITE" "  build   - Build Docker image only"
        print_color "$WHITE" "  rebuild - Stop, rebuild, and start all nodes"
        exit 1
        ;;
esac
