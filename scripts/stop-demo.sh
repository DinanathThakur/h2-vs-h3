#!/bin/bash

# HTTP/2 vs HTTP/3 Demo Stop Script
# This script gracefully stops the demo containers and services

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="${LOG_DIR:-/tmp/h2-h3-demo-logs}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_DIR/stop_$TIMESTAMP.log"

# Default configuration
DEFAULT_COMPOSE_FILE="docker-compose.yml"
DEFAULT_TIMEOUT="30"

# Environment variables with defaults
COMPOSE_FILE="${COMPOSE_FILE:-$DEFAULT_COMPOSE_FILE}"
STOP_TIMEOUT="${STOP_TIMEOUT:-$DEFAULT_TIMEOUT}"
FORCE_STOP="${FORCE_STOP:-false}"
REMOVE_VOLUMES="${REMOVE_VOLUMES:-false}"
REMOVE_IMAGES="${REMOVE_IMAGES:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${GREEN}$message${NC}"
    echo "$message" >> "$LOG_FILE" 2>/dev/null || true
}

error() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1"
    echo -e "${RED}$message${NC}" >&2
    echo "$message" >> "$LOG_FILE" 2>/dev/null || true
}

warn() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1"
    echo -e "${YELLOW}$message${NC}"
    echo "$message" >> "$LOG_FILE" 2>/dev/null || true
}

info() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1"
    echo -e "${BLUE}$message${NC}"
    echo "$message" >> "$LOG_FILE" 2>/dev/null || true
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

HTTP/2 vs HTTP/3 Demo Stop Script

OPTIONS:
    -h, --help              Show this help message
    -f, --compose-file FILE Docker compose file (default: $DEFAULT_COMPOSE_FILE)
    -t, --timeout SECONDS   Stop timeout in seconds (default: $DEFAULT_TIMEOUT)
    --force                 Force stop containers (kill instead of graceful stop)
    --remove-volumes        Remove associated volumes
    --remove-images         Remove built images
    --cleanup-all           Remove containers, volumes, images, and networks

ENVIRONMENT VARIABLES:
    COMPOSE_FILE            Docker compose file path
    STOP_TIMEOUT            Container stop timeout
    FORCE_STOP              Force stop containers (true/false)
    REMOVE_VOLUMES          Remove volumes (true/false)
    REMOVE_IMAGES           Remove images (true/false)

EXAMPLES:
    $0                              # Graceful stop with defaults
    $0 --force --timeout 10         # Force stop with 10s timeout
    $0 --cleanup-all                # Stop and remove everything
    $0 --remove-volumes             # Stop and remove volumes

EOF
}

# Setup logging directory
setup_logging() {
    mkdir -p "$LOG_DIR"
    log "Starting HTTP/2 vs HTTP/3 demo stop"
    log "Log file: $LOG_FILE"
    log "Project root: $PROJECT_ROOT"
}

# Check if containers are running
check_running_containers() {
    info "Checking for running demo containers..."
    
    cd "$PROJECT_ROOT"
    
    local compose_cmd
    if command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker-compose"
    else
        compose_cmd="docker compose"
    fi
    
    local running_containers
    running_containers=$($compose_cmd -f "$COMPOSE_FILE" ps -q 2>/dev/null || true)
    
    if [ -n "$running_containers" ]; then
        log "Found running demo containers:"
        $compose_cmd -f "$COMPOSE_FILE" ps 2>&1 | tee -a "$LOG_FILE"
        return 0
    else
        info "No running demo containers found"
        return 1
    fi
}

# Stop containers gracefully
stop_containers() {
    info "Stopping demo containers..."
    
    cd "$PROJECT_ROOT"
    
    local compose_cmd
    if command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker-compose"
    else
        compose_cmd="docker compose"
    fi
    
    if [ "$FORCE_STOP" = "true" ]; then
        info "Force stopping containers..."
        $compose_cmd -f "$COMPOSE_FILE" kill 2>&1 | tee -a "$LOG_FILE"
    else
        info "Gracefully stopping containers (timeout: ${STOP_TIMEOUT}s)..."
        $compose_cmd -f "$COMPOSE_FILE" down --timeout "$STOP_TIMEOUT" 2>&1 | tee -a "$LOG_FILE"
    fi
    
    log "✓ Containers stopped"
}

# Remove volumes if requested
remove_volumes() {
    if [ "$REMOVE_VOLUMES" = "true" ]; then
        info "Removing associated volumes..."
        
        cd "$PROJECT_ROOT"
        
        local compose_cmd
        if command -v docker-compose >/dev/null 2>&1; then
            compose_cmd="docker-compose"
        else
            compose_cmd="docker compose"
        fi
        
        $compose_cmd -f "$COMPOSE_FILE" down -v 2>&1 | tee -a "$LOG_FILE"
        
        log "✓ Volumes removed"
    fi
}

# Remove images if requested
remove_images() {
    if [ "$REMOVE_IMAGES" = "true" ]; then
        info "Removing built images..."
        
        cd "$PROJECT_ROOT"
        
        local compose_cmd
        if command -v docker-compose >/dev/null 2>&1; then
            compose_cmd="docker-compose"
        else
            compose_cmd="docker compose"
        fi
        
        # Get image names from compose file
        local images
        images=$($compose_cmd -f "$COMPOSE_FILE" config --services 2>/dev/null | while read service; do
            $compose_cmd -f "$COMPOSE_FILE" config | grep -A 10 "^  $service:" | grep "image:" | awk '{print $2}' || true
        done)
        
        # Remove images
        if [ -n "$images" ]; then
            echo "$images" | while read image; do
                if [ -n "$image" ] && docker images -q "$image" >/dev/null 2>&1; then
                    info "Removing image: $image"
                    docker rmi "$image" 2>&1 | tee -a "$LOG_FILE" || warn "Failed to remove image: $image"
                fi
            done
        fi
        
        # Also remove any dangling images from our build
        local dangling_images
        dangling_images=$(docker images -f "dangling=true" -q | head -10)
        if [ -n "$dangling_images" ]; then
            info "Removing dangling images..."
            echo "$dangling_images" | xargs docker rmi 2>&1 | tee -a "$LOG_FILE" || warn "Failed to remove some dangling images"
        fi
        
        log "✓ Images removed"
    fi
}

# Clean up networks
cleanup_networks() {
    info "Cleaning up demo networks..."
    
    cd "$PROJECT_ROOT"
    
    local compose_cmd
    if command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker-compose"
    else
        compose_cmd="docker compose"
    fi
    
    # Remove networks created by compose
    $compose_cmd -f "$COMPOSE_FILE" down --remove-orphans 2>&1 | tee -a "$LOG_FILE" || true
    
    # Clean up any orphaned networks
    local orphaned_networks
    orphaned_networks=$(docker network ls --filter "name=h2-h3" --format "{{.ID}}" 2>/dev/null || true)
    
    if [ -n "$orphaned_networks" ]; then
        info "Removing orphaned demo networks..."
        echo "$orphaned_networks" | while read network_id; do
            docker network rm "$network_id" 2>&1 | tee -a "$LOG_FILE" || warn "Failed to remove network: $network_id"
        done
    fi
    
    log "✓ Networks cleaned up"
}

# Verify containers are stopped
verify_stop() {
    info "Verifying containers are stopped..."
    
    cd "$PROJECT_ROOT"
    
    local compose_cmd
    if command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker-compose"
    else
        compose_cmd="docker compose"
    fi
    
    local remaining_containers
    remaining_containers=$($compose_cmd -f "$COMPOSE_FILE" ps -q 2>/dev/null || true)
    
    if [ -n "$remaining_containers" ]; then
        warn "Some containers are still running:"
        $compose_cmd -f "$COMPOSE_FILE" ps 2>&1 | tee -a "$LOG_FILE"
        return 1
    else
        log "✓ All demo containers are stopped"
        return 0
    fi
}

# Check port availability after stop
check_ports_freed() {
    info "Checking if demo ports are freed..."
    
    local ports_in_use=false
    
    # Check common demo ports
    for port in 8443 8444; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            warn "Port $port is still in use"
            ports_in_use=true
        else
            log "✓ Port $port is available"
        fi
    done
    
    if [ "$ports_in_use" = "false" ]; then
        log "✓ All demo ports are freed"
    else
        warn "Some ports are still in use - may be by other services"
    fi
}

# Show stop summary
show_stop_summary() {
    info "=== STOP SUMMARY ==="
    log "✓ HTTP/2 vs HTTP/3 demo stopped"
    log ""
    log "Actions performed:"
    log "  - Containers stopped: Yes"
    log "  - Volumes removed: $REMOVE_VOLUMES"
    log "  - Images removed: $REMOVE_IMAGES"
    log "  - Networks cleaned: Yes"
    log ""
    log "Logs:"
    log "  Stop log: $LOG_FILE"
    log ""
    log "To restart the demo:"
    log "  $SCRIPT_DIR/start-demo.sh"
    log ""
    log "For complete cleanup:"
    log "  $SCRIPT_DIR/cleanup-demo.sh"
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -f|--compose-file)
                COMPOSE_FILE="$2"
                shift 2
                ;;
            -t|--timeout)
                STOP_TIMEOUT="$2"
                shift 2
                ;;
            --force)
                FORCE_STOP="true"
                shift
                ;;
            --remove-volumes)
                REMOVE_VOLUMES="true"
                shift
                ;;
            --remove-images)
                REMOVE_IMAGES="true"
                shift
                ;;
            --cleanup-all)
                REMOVE_VOLUMES="true"
                REMOVE_IMAGES="true"
                shift
                ;;
            *)
                error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Main stop function
main() {
    local exit_code=0
    
    # Parse arguments
    parse_arguments "$@"
    
    # Setup logging
    setup_logging
    
    # Check if Docker is available
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker is not installed or not available"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        error "Docker daemon is not running"
        exit 1
    fi
    
    # Check for running containers
    if ! check_running_containers; then
        info "No containers to stop"
        exit 0
    fi
    
    # Stop containers
    stop_containers || exit_code=1
    
    # Remove volumes if requested
    remove_volumes || exit_code=1
    
    # Remove images if requested
    remove_images || exit_code=1
    
    # Clean up networks
    cleanup_networks || exit_code=1
    
    # Verify stop
    verify_stop || exit_code=1
    
    # Check ports
    check_ports_freed || true  # Don't fail on port check
    
    # Show summary
    show_stop_summary
    
    if [ $exit_code -eq 0 ]; then
        log "✓ Demo stop completed successfully"
    else
        error "✗ Demo stop completed with issues"
    fi
    
    return $exit_code
}

# Handle script interruption
trap 'error "Stop interrupted"; exit 130' INT TERM

# Run main function
main "$@"