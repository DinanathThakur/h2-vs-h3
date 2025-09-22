#!/bin/bash

# HTTP/2 vs HTTP/3 Demo Debug and Logging Utility
# This script provides comprehensive debugging and logging capabilities

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="${LOG_DIR:-/tmp/h2-h3-demo-logs}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DEBUG_LOG="$LOG_DIR/debug_$TIMESTAMP.log"

# Default configuration
DEFAULT_COMPOSE_FILE="docker-compose.yml"
DEFAULT_LOG_LINES="100"
DEFAULT_FOLLOW_LOGS="false"

# Environment variables with defaults
COMPOSE_FILE="${COMPOSE_FILE:-$DEFAULT_COMPOSE_FILE}"
LOG_LINES="${LOG_LINES:-$DEFAULT_LOG_LINES}"
FOLLOW_LOGS="${FOLLOW_LOGS:-$DEFAULT_FOLLOW_LOGS}"
DEBUG_LEVEL="${DEBUG_LEVEL:-info}"
COLLECT_SYSTEM_INFO="${COLLECT_SYSTEM_INFO:-true}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${GREEN}$message${NC}"
    echo "$message" >> "$DEBUG_LOG" 2>/dev/null || true
}

error() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1"
    echo -e "${RED}$message${NC}" >&2
    echo "$message" >> "$DEBUG_LOG" 2>/dev/null || true
}

warn() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1"
    echo -e "${YELLOW}$message${NC}"
    echo "$message" >> "$DEBUG_LOG" 2>/dev/null || true
}

info() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1"
    echo -e "${BLUE}$message${NC}"
    echo "$message" >> "$DEBUG_LOG" 2>/dev/null || true
}

debug() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] DEBUG: $1"
    echo -e "${CYAN}$message${NC}"
    echo "$message" >> "$DEBUG_LOG" 2>/dev/null || true
}

section() {
    local title="$1"
    local separator="$(printf '=%.0s' {1..60})"
    echo -e "${MAGENTA}$separator${NC}"
    echo -e "${MAGENTA}$title${NC}"
    echo -e "${MAGENTA}$separator${NC}"
    echo "$separator" >> "$DEBUG_LOG" 2>/dev/null || true
    echo "$title" >> "$DEBUG_LOG" 2>/dev/null || true
    echo "$separator" >> "$DEBUG_LOG" 2>/dev/null || true
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] [COMMAND]

HTTP/2 vs HTTP/3 Demo Debug and Logging Utility

COMMANDS:
    logs                    Show container logs
    status                  Show container and service status
    network                 Show network information and connectivity
    certificates            Show SSL certificate information
    performance             Run performance diagnostics
    system                  Show system information
    troubleshoot            Run comprehensive troubleshooting
    collect                 Collect all debug information to file

OPTIONS:
    -h, --help              Show this help message
    -f, --compose-file FILE Docker compose file (default: $DEFAULT_COMPOSE_FILE)
    -l, --lines NUMBER      Number of log lines to show (default: $DEFAULT_LOG_LINES)
    -F, --follow            Follow log output (tail -f behavior)
    -d, --debug-level LEVEL Debug level: info, debug, trace (default: info)
    --no-system-info        Skip system information collection
    --output-file FILE      Save debug output to specific file

EXAMPLES:
    $0 logs                 # Show container logs
    $0 status               # Show service status
    $0 troubleshoot         # Run full troubleshooting
    $0 collect              # Collect all debug info
    $0 logs --follow        # Follow logs in real-time
    $0 network --debug-level debug  # Detailed network debugging

EOF
}

# Setup logging directory
setup_logging() {
    mkdir -p "$LOG_DIR"
    log "Starting debug session"
    log "Debug log: $DEBUG_LOG"
    log "Project root: $PROJECT_ROOT"
}

# Collect system information
collect_system_info() {
    if [ "$COLLECT_SYSTEM_INFO" != "true" ]; then
        return 0
    fi
    
    section "SYSTEM INFORMATION"
    
    info "Collecting system information..."
    
    # Basic system info
    debug "Hostname: $(hostname)"
    debug "OS: $(uname -s) $(uname -r) $(uname -m)"
    debug "Date: $(date)"
    debug "Uptime: $(uptime)"
    
    # Docker information
    if command -v docker >/dev/null 2>&1; then
        debug "Docker version: $(docker --version)"
        
        if docker info >/dev/null 2>&1; then
            debug "Docker info:"
            docker info 2>&1 | head -20 | while read line; do
                debug "  $line"
            done
        else
            warn "Docker daemon not running"
        fi
        
        # Docker Compose version
        if command -v docker-compose >/dev/null 2>&1; then
            debug "Docker Compose version: $(docker-compose --version)"
        elif docker compose version >/dev/null 2>&1; then
            debug "Docker Compose version: $(docker compose version)"
        else
            warn "Docker Compose not available"
        fi
    else
        error "Docker not installed"
    fi
    
    # Network tools
    debug "Available network tools:"
    for tool in curl wget nc netstat ss lsof; do
        if command -v $tool >/dev/null 2>&1; then
            debug "  $tool: available"
        else
            debug "  $tool: not available"
        fi
    done
    
    # System resources
    if command -v free >/dev/null 2>&1; then
        debug "Memory usage:"
        free -h | while read line; do
            debug "  $line"
        done
    fi
    
    if command -v df >/dev/null 2>&1; then
        debug "Disk usage:"
        df -h / | while read line; do
            debug "  $line"
        done
    fi
    
    log "✓ System information collected"
}

# Show container logs
show_container_logs() {
    section "CONTAINER LOGS"
    
    cd "$PROJECT_ROOT"
    
    local compose_cmd
    if command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker-compose"
    else
        compose_cmd="docker compose"
    fi
    
    info "Showing container logs (last $LOG_LINES lines)..."
    
    # Check if containers exist
    local containers
    containers=$($compose_cmd -f "$COMPOSE_FILE" ps -q 2>/dev/null || true)
    
    if [ -z "$containers" ]; then
        warn "No containers found"
        return 1
    fi
    
    # Show logs for each service
    local services
    services=$($compose_cmd -f "$COMPOSE_FILE" config --services 2>/dev/null || true)
    
    for service in $services; do
        debug "=== Logs for $service ==="
        
        if [ "$FOLLOW_LOGS" = "true" ]; then
            info "Following logs for $service (press Ctrl+C to stop)..."
            $compose_cmd -f "$COMPOSE_FILE" logs -f "$service" 2>&1 | tee -a "$DEBUG_LOG"
        else
            $compose_cmd -f "$COMPOSE_FILE" logs --tail "$LOG_LINES" "$service" 2>&1 | tee -a "$DEBUG_LOG"
        fi
        
        echo "" | tee -a "$DEBUG_LOG"
    done
    
    log "✓ Container logs displayed"
}

# Show container and service status
show_status() {
    section "CONTAINER AND SERVICE STATUS"
    
    cd "$PROJECT_ROOT"
    
    local compose_cmd
    if command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker-compose"
    else
        compose_cmd="docker compose"
    fi
    
    info "Checking container status..."
    
    # Show compose services
    debug "=== Docker Compose Services ==="
    $compose_cmd -f "$COMPOSE_FILE" ps 2>&1 | tee -a "$DEBUG_LOG"
    
    # Show all containers
    debug "=== All Docker Containers ==="
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}" | tee -a "$DEBUG_LOG"
    
    # Show container resource usage
    debug "=== Container Resource Usage ==="
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" 2>/dev/null | tee -a "$DEBUG_LOG" || warn "Could not get container stats"
    
    # Show container health
    debug "=== Container Health Status ==="
    local containers
    containers=$(docker ps --format "{{.Names}}" | grep -E "(http2-server|http3-server)" || true)
    
    for container in $containers; do
        local health_status
        health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no-healthcheck")
        debug "$container: $health_status"
        
        if [ "$health_status" = "unhealthy" ]; then
            warn "Container $container is unhealthy"
            docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' "$container" 2>/dev/null | tail -5 | while read line; do
                debug "  Health log: $line"
            done
        fi
    done
    
    log "✓ Status information collected"
}

# Show network information and connectivity
show_network_info() {
    section "NETWORK INFORMATION AND CONNECTIVITY"
    
    info "Collecting network information..."
    
    # Show listening ports
    debug "=== Listening Ports ==="
    if command -v netstat >/dev/null 2>&1; then
        netstat -tuln | grep -E ":(8443|8444) " | while read line; do
            debug "$line"
        done
    elif command -v ss >/dev/null 2>&1; then
        ss -tuln | grep -E ":(8443|8444) " | while read line; do
            debug "$line"
        done
    else
        warn "No network tools available (netstat/ss)"
    fi
    
    # Show Docker networks
    debug "=== Docker Networks ==="
    docker network ls | tee -a "$DEBUG_LOG"
    
    # Show network details for demo
    local demo_networks
    demo_networks=$(docker network ls --format "{{.Name}}" | grep -E "(h2-h3|demo)" || true)
    
    for network in $demo_networks; do
        debug "=== Network Details: $network ==="
        docker network inspect "$network" 2>/dev/null | tee -a "$DEBUG_LOG" || warn "Could not inspect network: $network"
    done
    
    # Test connectivity
    debug "=== Connectivity Tests ==="
    
    local ports=("8443" "8444")
    for port in "${ports[@]}"; do
        debug "Testing connectivity to localhost:$port..."
        
        if command -v curl >/dev/null 2>&1; then
            if curl -k -s --max-time 5 --connect-timeout 3 "https://localhost:$port" >/dev/null 2>&1; then
                debug "✓ HTTPS connection to port $port successful"
            else
                warn "✗ HTTPS connection to port $port failed"
            fi
        elif command -v wget >/dev/null 2>&1; then
            if wget -q --no-check-certificate --timeout=5 --tries=1 "https://localhost:$port" -O /dev/null 2>/dev/null; then
                debug "✓ HTTPS connection to port $port successful"
            else
                warn "✗ HTTPS connection to port $port failed"
            fi
        else
            warn "No HTTP client available (curl/wget)"
        fi
        
        # Test TCP connectivity
        if command -v nc >/dev/null 2>&1; then
            if timeout 3 nc -z localhost "$port" 2>/dev/null; then
                debug "✓ TCP connection to port $port successful"
            else
                warn "✗ TCP connection to port $port failed"
            fi
        fi
    done
    
    # Test UDP connectivity for HTTP/3
    debug "Testing UDP connectivity for HTTP/3 (port 8444)..."
    if command -v nc >/dev/null 2>&1; then
        if timeout 3 nc -u -z localhost 8444 2>/dev/null; then
            debug "✓ UDP connection to port 8444 successful"
        else
            warn "✗ UDP connection to port 8444 failed (normal for QUIC)"
        fi
    fi
    
    log "✓ Network information collected"
}

# Show SSL certificate information
show_certificate_info() {
    section "SSL CERTIFICATE INFORMATION"
    
    info "Collecting SSL certificate information..."
    
    local cert_dir="$PROJECT_ROOT/certs"
    
    if [ -d "$cert_dir" ]; then
        debug "=== Certificate Directory Contents ==="
        ls -la "$cert_dir" | while read line; do
            debug "$line"
        done
        
        # Show certificate details
        local cert_file="$cert_dir/server.crt"
        local key_file="$cert_dir/server.key"
        
        if [ -f "$cert_file" ]; then
            debug "=== Certificate Details ==="
            openssl x509 -in "$cert_file" -text -noout 2>/dev/null | head -30 | while read line; do
                debug "$line"
            done
            
            debug "=== Certificate Validity ==="
            local not_before not_after
            not_before=$(openssl x509 -in "$cert_file" -noout -startdate 2>/dev/null | cut -d= -f2)
            not_after=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2)
            
            debug "Valid from: $not_before"
            debug "Valid until: $not_after"
            
            # Check if certificate is expired
            if openssl x509 -in "$cert_file" -checkend 0 >/dev/null 2>&1; then
                debug "✓ Certificate is valid"
            else
                warn "✗ Certificate is expired"
            fi
        else
            warn "Certificate file not found: $cert_file"
        fi
        
        if [ -f "$key_file" ]; then
            debug "=== Private Key Information ==="
            local key_size
            key_size=$(openssl rsa -in "$key_file" -text -noout 2>/dev/null | grep "Private-Key:" | awk '{print $2}' || echo "unknown")
            debug "Key size: $key_size"
            
            # Verify key matches certificate
            if [ -f "$cert_file" ]; then
                local cert_hash key_hash
                cert_hash=$(openssl x509 -in "$cert_file" -noout -modulus 2>/dev/null | openssl md5)
                key_hash=$(openssl rsa -in "$key_file" -noout -modulus 2>/dev/null | openssl md5)
                
                if [ "$cert_hash" = "$key_hash" ]; then
                    debug "✓ Certificate and key match"
                else
                    warn "✗ Certificate and key do not match"
                fi
            fi
        else
            warn "Private key file not found: $key_file"
        fi
    else
        warn "Certificate directory not found: $cert_dir"
    fi
    
    # Test certificate from server
    debug "=== Server Certificate Test ==="
    for port in 8443 8444; do
        debug "Testing certificate on port $port..."
        
        if command -v openssl >/dev/null 2>&1; then
            local cert_info
            cert_info=$(echo | timeout 5 openssl s_client -connect "localhost:$port" -servername localhost 2>/dev/null | openssl x509 -noout -subject -dates 2>/dev/null || echo "Connection failed")
            
            if [ "$cert_info" != "Connection failed" ]; then
                debug "✓ Certificate retrieved from port $port"
                echo "$cert_info" | while read line; do
                    debug "  $line"
                done
            else
                warn "✗ Could not retrieve certificate from port $port"
            fi
        fi
    done
    
    log "✓ Certificate information collected"
}

# Run performance diagnostics
run_performance_diagnostics() {
    section "PERFORMANCE DIAGNOSTICS"
    
    info "Running performance diagnostics..."
    
    # Container performance
    debug "=== Container Performance ==="
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" 2>/dev/null | tee -a "$DEBUG_LOG" || warn "Could not get container stats"
    
    # Load testing with curl
    debug "=== Basic Load Test ==="
    
    local test_urls=("https://localhost:8443" "https://localhost:8444")
    
    for url in "${test_urls[@]}"; do
        debug "Testing $url..."
        
        if command -v curl >/dev/null 2>&1; then
            local response_time
            response_time=$(curl -k -s -w "%{time_total}" -o /dev/null --max-time 10 "$url" 2>/dev/null || echo "failed")
            
            if [ "$response_time" != "failed" ]; then
                debug "✓ Response time: ${response_time}s"
            else
                warn "✗ Request failed"
            fi
        fi
    done
    
    # Check for resource constraints
    debug "=== Resource Constraints Check ==="
    
    # Memory usage
    if command -v free >/dev/null 2>&1; then
        local mem_usage
        mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
        debug "System memory usage: ${mem_usage}%"
        
        if (( $(echo "$mem_usage > 90" | bc -l) )); then
            warn "High memory usage detected"
        fi
    fi
    
    # Disk usage
    if command -v df >/dev/null 2>&1; then
        local disk_usage
        disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
        debug "Disk usage: ${disk_usage}%"
        
        if [ "$disk_usage" -gt 90 ]; then
            warn "High disk usage detected"
        fi
    fi
    
    log "✓ Performance diagnostics completed"
}

# Run comprehensive troubleshooting
run_troubleshooting() {
    section "COMPREHENSIVE TROUBLESHOOTING"
    
    info "Running comprehensive troubleshooting..."
    
    # Run all diagnostic functions
    collect_system_info
    show_status
    show_network_info
    show_certificate_info
    run_performance_diagnostics
    
    # Additional troubleshooting checks
    debug "=== Additional Checks ==="
    
    # Check for common issues
    debug "Checking for common issues..."
    
    # Port conflicts
    local port_conflicts=false
    for port in 8443 8444; do
        if netstat -tuln 2>/dev/null | grep -q ":$port " && ! docker ps --format "{{.Ports}}" | grep -q ":$port->"; then
            warn "Port $port is in use by non-Docker process"
            port_conflicts=true
        fi
    done
    
    if [ "$port_conflicts" = "false" ]; then
        debug "✓ No port conflicts detected"
    fi
    
    # Docker daemon issues
    if ! docker info >/dev/null 2>&1; then
        error "Docker daemon is not running or accessible"
    else
        debug "✓ Docker daemon is accessible"
    fi
    
    # File permissions
    local script_perms=true
    for script in "$SCRIPT_DIR"/*.sh; do
        if [ -f "$script" ] && [ ! -x "$script" ]; then
            warn "Script not executable: $script"
            script_perms=false
        fi
    done
    
    if [ "$script_perms" = "true" ]; then
        debug "✓ All scripts are executable"
    fi
    
    # Configuration validation
    if [ -f "$PROJECT_ROOT/.env" ]; then
        debug "✓ Configuration file exists"
    else
        info "No .env configuration file found (using defaults)"
    fi
    
    log "✓ Troubleshooting completed"
}

# Collect all debug information
collect_debug_info() {
    section "COLLECTING ALL DEBUG INFORMATION"
    
    local output_file="${OUTPUT_FILE:-$LOG_DIR/debug_collection_$TIMESTAMP.txt}"
    
    info "Collecting all debug information to: $output_file"
    
    # Redirect all output to the collection file
    {
        echo "HTTP/2 vs HTTP/3 Demo - Debug Information Collection"
        echo "Generated: $(date)"
        echo "Hostname: $(hostname)"
        echo "User: $(whoami)"
        echo ""
        
        collect_system_info
        show_status
        show_network_info
        show_certificate_info
        run_performance_diagnostics
        
        echo ""
        echo "=== CONFIGURATION FILES ==="
        
        if [ -f "$PROJECT_ROOT/.env" ]; then
            echo "--- .env ---"
            cat "$PROJECT_ROOT/.env"
            echo ""
        fi
        
        if [ -f "$PROJECT_ROOT/$COMPOSE_FILE" ]; then
            echo "--- $COMPOSE_FILE ---"
            cat "$PROJECT_ROOT/$COMPOSE_FILE"
            echo ""
        fi
        
        echo "=== RECENT LOG FILES ==="
        find "$LOG_DIR" -name "*.log" -mtime -1 2>/dev/null | head -5 | while read logfile; do
            echo "--- $(basename "$logfile") (last 50 lines) ---"
            tail -50 "$logfile" 2>/dev/null || echo "Could not read log file"
            echo ""
        done
        
    } > "$output_file" 2>&1
    
    log "✓ Debug information collected to: $output_file"
    
    # Show file size and location
    if [ -f "$output_file" ]; then
        local file_size
        file_size=$(du -h "$output_file" | cut -f1)
        info "Collection file size: $file_size"
        info "Location: $output_file"
    fi
}

# Parse command line arguments
parse_arguments() {
    local command=""
    
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
            -l|--lines)
                LOG_LINES="$2"
                shift 2
                ;;
            -F|--follow)
                FOLLOW_LOGS="true"
                shift
                ;;
            -d|--debug-level)
                DEBUG_LEVEL="$2"
                shift 2
                ;;
            --no-system-info)
                COLLECT_SYSTEM_INFO="false"
                shift
                ;;
            --output-file)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            logs|status|network|certificates|performance|system|troubleshoot|collect)
                command="$1"
                shift
                ;;
            *)
                error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Execute command
    case "$command" in
        logs)
            show_container_logs
            ;;
        status)
            show_status
            ;;
        network)
            show_network_info
            ;;
        certificates)
            show_certificate_info
            ;;
        performance)
            run_performance_diagnostics
            ;;
        system)
            collect_system_info
            ;;
        troubleshoot)
            run_troubleshooting
            ;;
        collect)
            collect_debug_info
            ;;
        "")
            # No command specified, show usage
            show_usage
            ;;
        *)
            error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Main function
main() {
    # Setup logging
    setup_logging
    
    # Check if Docker is available
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker is not installed or not available"
        exit 1
    fi
    
    # Parse arguments and execute
    parse_arguments "$@"
}

# Handle script interruption
trap 'error "Debug session interrupted"; exit 130' INT TERM

# Run main function
main "$@"