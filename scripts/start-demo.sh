#!/bin/bash

# HTTP/2 vs HTTP/3 Demo Startup Script
# This script provides easy startup with configuration options and logging

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="${LOG_DIR:-/tmp/h2-h3-demo-logs}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_DIR/startup_$TIMESTAMP.log"

# Default configuration
DEFAULT_HTTP2_PORT="8443"
DEFAULT_HTTP3_PORT="8444"
DEFAULT_COMPOSE_FILE="docker-compose.yml"
DEFAULT_BUILD_MODE="pull"
DEFAULT_LOG_LEVEL="info"

# Environment variables with defaults
HTTP2_PORT="${HTTP2_PORT:-$DEFAULT_HTTP2_PORT}"
HTTP3_PORT="${HTTP3_PORT:-$DEFAULT_HTTP3_PORT}"
COMPOSE_FILE="${COMPOSE_FILE:-$DEFAULT_COMPOSE_FILE}"
BUILD_MODE="${BUILD_MODE:-$DEFAULT_BUILD_MODE}"
LOG_LEVEL="${LOG_LEVEL:-$DEFAULT_LOG_LEVEL}"
DEMO_ENV="${DEMO_ENV:-development}"
SKIP_HEALTH_CHECK="${SKIP_HEALTH_CHECK:-false}"
FORCE_REBUILD="${FORCE_REBUILD:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

debug() {
    if [ "$LOG_LEVEL" = "debug" ]; then
        local message="[$(date +'%Y-%m-%d %H:%M:%S')] DEBUG: $1"
        echo -e "${CYAN}$message${NC}"
        echo "$message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

HTTP/2 vs HTTP/3 Demo Startup Script

OPTIONS:
    -h, --help              Show this help message
    -p, --http2-port PORT   HTTP/2 server port (default: $DEFAULT_HTTP2_PORT)
    -q, --http3-port PORT   HTTP/3 server port (default: $DEFAULT_HTTP3_PORT)
    -f, --compose-file FILE Docker compose file (default: $DEFAULT_COMPOSE_FILE)
    -b, --build-mode MODE   Build mode: pull, build, or rebuild (default: $DEFAULT_BUILD_MODE)
    -e, --env ENV           Environment: development, staging, production (default: development)
    -l, --log-level LEVEL   Log level: debug, info, warn, error (default: $DEFAULT_LOG_LEVEL)
    --force-rebuild         Force rebuild of all containers
    --skip-health-check     Skip health checks after startup
    --detach                Run in detached mode (background)
    --no-logs               Don't show container logs after startup

ENVIRONMENT VARIABLES:
    HTTP2_PORT              HTTP/2 server port
    HTTP3_PORT              HTTP/3 server port  
    COMPOSE_FILE            Docker compose file path
    BUILD_MODE              Container build mode
    LOG_LEVEL               Logging verbosity
    DEMO_ENV                Demo environment
    SKIP_HEALTH_CHECK       Skip health checks (true/false)
    FORCE_REBUILD           Force container rebuild (true/false)

EXAMPLES:
    $0                                          # Start with defaults
    $0 --http2-port 9443 --http3-port 9444     # Custom ports
    $0 --build-mode rebuild --log-level debug  # Rebuild with debug logging
    $0 --env production --skip-health-check    # Production mode, skip health checks

EOF
}

# Setup logging directory
setup_logging() {
    mkdir -p "$LOG_DIR"
    log "Starting HTTP/2 vs HTTP/3 demo startup"
    log "Log file: $LOG_FILE"
    log "Project root: $PROJECT_ROOT"
    
    # Log configuration
    debug "Configuration:"
    debug "  HTTP2_PORT=$HTTP2_PORT"
    debug "  HTTP3_PORT=$HTTP3_PORT"
    debug "  COMPOSE_FILE=$COMPOSE_FILE"
    debug "  BUILD_MODE=$BUILD_MODE"
    debug "  LOG_LEVEL=$LOG_LEVEL"
    debug "  DEMO_ENV=$DEMO_ENV"
    debug "  SKIP_HEALTH_CHECK=$SKIP_HEALTH_CHECK"
    debug "  FORCE_REBUILD=$FORCE_REBUILD"
}

# Validate prerequisites
validate_prerequisites() {
    info "Validating prerequisites..."
    
    # Check if Docker is installed
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker is not installed. Please install Docker first."
        error "Visit: https://docs.docker.com/get-docker/"
        return 1
    fi
    
    # Check if Docker Compose is available
    if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
        error "Docker Compose is not available. Please install Docker Compose."
        error "Visit: https://docs.docker.com/compose/install/"
        return 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        error "Docker daemon is not running. Please start Docker."
        return 1
    fi
    
    # Check if compose file exists
    local compose_path="$PROJECT_ROOT/$COMPOSE_FILE"
    if [ ! -f "$compose_path" ]; then
        error "Docker compose file not found: $compose_path"
        return 1
    fi
    
    # Check if required directories exist
    local required_dirs=("nginx" "web" "scripts" "certs")
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$PROJECT_ROOT/$dir" ]; then
            error "Required directory not found: $PROJECT_ROOT/$dir"
            return 1
        fi
    done
    
    log "✓ All prerequisites validated"
    return 0
}

# Check port availability
check_ports() {
    info "Checking port availability..."
    
    if [ -x "$SCRIPT_DIR/port-check.sh" ]; then
        debug "Running port check script..."
        if "$SCRIPT_DIR/port-check.sh"; then
            log "✓ Port availability check passed"
        else
            warn "Port availability check reported issues"
            warn "Continuing startup - ports may be in use by existing demo containers"
        fi
    else
        warn "Port check script not found or not executable, skipping port check"
    fi
}

# Stop existing containers
stop_existing_containers() {
    info "Stopping any existing demo containers..."
    
    cd "$PROJECT_ROOT"
    
    # Use docker-compose or docker compose based on availability
    local compose_cmd
    if command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker-compose"
    else
        compose_cmd="docker compose"
    fi
    
    debug "Using compose command: $compose_cmd"
    
    # Stop containers gracefully
    if $compose_cmd -f "$COMPOSE_FILE" ps -q | grep -q .; then
        log "Stopping existing containers..."
        $compose_cmd -f "$COMPOSE_FILE" down --timeout 30 2>&1 | tee -a "$LOG_FILE" || true
    else
        debug "No existing containers to stop"
    fi
}

# Build or pull container images
prepare_images() {
    info "Preparing container images..."
    
    cd "$PROJECT_ROOT"
    
    local compose_cmd
    if command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker-compose"
    else
        compose_cmd="docker compose"
    fi
    
    case "$BUILD_MODE" in
        "pull")
            info "Pulling latest images..."
            $compose_cmd -f "$COMPOSE_FILE" pull 2>&1 | tee -a "$LOG_FILE" || true
            ;;
        "build")
            info "Building images..."
            $compose_cmd -f "$COMPOSE_FILE" build 2>&1 | tee -a "$LOG_FILE"
            ;;
        "rebuild")
            info "Rebuilding images from scratch..."
            $compose_cmd -f "$COMPOSE_FILE" build --no-cache 2>&1 | tee -a "$LOG_FILE"
            ;;
        *)
            warn "Unknown build mode: $BUILD_MODE, defaulting to pull"
            $compose_cmd -f "$COMPOSE_FILE" pull 2>&1 | tee -a "$LOG_FILE" || true
            ;;
    esac
    
    log "✓ Image preparation completed"
}

# Start the demo containers
start_containers() {
    info "Starting demo containers..."
    
    cd "$PROJECT_ROOT"
    
    local compose_cmd
    if command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker-compose"
    else
        compose_cmd="docker compose"
    fi
    
    # Set environment variables for docker-compose
    export HTTP2_PORT
    export HTTP3_PORT
    export DEMO_ENV
    
    # Start containers
    local compose_args="-f $COMPOSE_FILE up"
    
    if [ "$DETACH_MODE" = "true" ]; then
        compose_args="$compose_args -d"
    fi
    
    debug "Starting containers with: $compose_cmd $compose_args"
    
    if [ "$DETACH_MODE" = "true" ]; then
        $compose_cmd $compose_args 2>&1 | tee -a "$LOG_FILE"
    else
        # In non-detached mode, we'll start in background and then show logs
        $compose_cmd $compose_args -d 2>&1 | tee -a "$LOG_FILE"
    fi
    
    log "✓ Containers started"
}

# Wait for services to be ready
wait_for_services() {
    if [ "$SKIP_HEALTH_CHECK" = "true" ]; then
        info "Skipping health checks as requested"
        return 0
    fi
    
    info "Waiting for services to be ready..."
    
    local max_attempts=30
    local attempt=1
    local services_ready=false
    
    while [ $attempt -le $max_attempts ] && [ "$services_ready" = "false" ]; do
        debug "Health check attempt $attempt/$max_attempts"
        
        local http2_ready=false
        local http3_ready=false
        
        # Check HTTP/2 service
        if curl -k -s --max-time 5 "https://localhost:$HTTP2_PORT" >/dev/null 2>&1; then
            http2_ready=true
            debug "HTTP/2 service is ready"
        fi
        
        # Check HTTP/3 service (fallback to HTTP/2 check since HTTP/3 requires special client)
        if curl -k -s --max-time 5 "https://localhost:$HTTP3_PORT" >/dev/null 2>&1; then
            http3_ready=true
            debug "HTTP/3 service is ready"
        fi
        
        if [ "$http2_ready" = "true" ] && [ "$http3_ready" = "true" ]; then
            services_ready=true
            log "✓ All services are ready"
        else
            debug "Services not ready yet, waiting..."
            sleep 2
            attempt=$((attempt + 1))
        fi
    done
    
    if [ "$services_ready" = "false" ]; then
        warn "Services may not be fully ready after $max_attempts attempts"
        warn "Check container logs for issues"
        return 1
    fi
    
    return 0
}

# Show startup summary
show_startup_summary() {
    info "=== STARTUP SUMMARY ==="
    log "✓ HTTP/2 vs HTTP/3 demo started successfully"
    log ""
    log "Access URLs:"
    log "  HTTP/2 Demo: https://localhost:$HTTP2_PORT"
    log "  HTTP/3 Demo: https://localhost:$HTTP3_PORT"
    log ""
    log "Container Status:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(http2-server|http3-server|cert-generator)" || true
    log ""
    log "Logs:"
    log "  Startup log: $LOG_FILE"
    log "  Container logs: docker-compose -f $COMPOSE_FILE logs -f"
    log ""
    log "Management:"
    log "  Stop demo: $SCRIPT_DIR/stop-demo.sh"
    log "  Monitor: $SCRIPT_DIR/monitor.sh"
    log "  Cleanup: $SCRIPT_DIR/cleanup-demo.sh"
    
    if [ "$SHOW_LOGS" = "true" ] && [ "$DETACH_MODE" = "true" ]; then
        info ""
        info "Container logs (press Ctrl+C to exit):"
        cd "$PROJECT_ROOT"
        docker-compose -f "$COMPOSE_FILE" logs -f
    fi
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -p|--http2-port)
                HTTP2_PORT="$2"
                shift 2
                ;;
            -q|--http3-port)
                HTTP3_PORT="$2"
                shift 2
                ;;
            -f|--compose-file)
                COMPOSE_FILE="$2"
                shift 2
                ;;
            -b|--build-mode)
                BUILD_MODE="$2"
                shift 2
                ;;
            -e|--env)
                DEMO_ENV="$2"
                shift 2
                ;;
            -l|--log-level)
                LOG_LEVEL="$2"
                shift 2
                ;;
            --force-rebuild)
                FORCE_REBUILD="true"
                BUILD_MODE="rebuild"
                shift
                ;;
            --skip-health-check)
                SKIP_HEALTH_CHECK="true"
                shift
                ;;
            --detach)
                DETACH_MODE="true"
                shift
                ;;
            --no-logs)
                SHOW_LOGS="false"
                shift
                ;;
            *)
                error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Set defaults for unset variables
    DETACH_MODE="${DETACH_MODE:-false}"
    SHOW_LOGS="${SHOW_LOGS:-true}"
}

# Main startup function
main() {
    local exit_code=0
    
    # Parse arguments
    parse_arguments "$@"
    
    # Setup logging
    setup_logging
    
    # Validate prerequisites
    validate_prerequisites || exit 1
    
    # Check ports
    check_ports || true  # Don't fail on port check
    
    # Stop existing containers
    stop_existing_containers || exit_code=1
    
    # Prepare images
    prepare_images || exit_code=1
    
    # Start containers
    start_containers || exit_code=1
    
    # Wait for services
    wait_for_services || exit_code=1
    
    # Show summary
    show_startup_summary
    
    if [ $exit_code -eq 0 ]; then
        log "✓ Demo startup completed successfully"
    else
        error "✗ Demo startup completed with issues"
    fi
    
    return $exit_code
}

# Handle script interruption
trap 'error "Startup interrupted"; exit 130' INT TERM

# Run main function
main "$@"