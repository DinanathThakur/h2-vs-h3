#!/bin/bash

# HTTP/2 vs HTTP/3 Demo Management Script
# Main entry point for all demo operations

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR: $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO: $1${NC}"
}

title() {
    echo -e "${MAGENTA}$1${NC}"
}

# Show main usage information
show_usage() {
    title "HTTP/2 vs HTTP/3 Demo Management Script"
    echo
    cat << EOF
Usage: $0 <COMMAND> [OPTIONS]

A comprehensive management script for the HTTP/2 vs HTTP/3 demonstration.

COMMANDS:
    start           Start the demo (containers and services)
    stop            Stop the demo gracefully
    restart         Restart the demo (stop + start)
    status          Show current status of all services
    logs            Show container logs
    cleanup         Clean up all demo resources
    configure       Configure demo settings
    debug           Debug and troubleshooting utilities
    monitor         Run monitoring and health checks
    help            Show this help message

QUICK START:
    $0 start        # Start the demo
    $0 status       # Check if everything is running
    $0 logs         # View container logs
    $0 stop         # Stop the demo

MANAGEMENT:
    $0 configure    # Configure settings interactively
    $0 monitor      # Run health checks and monitoring
    $0 debug        # Troubleshoot issues
    $0 cleanup      # Clean up all resources

ACCESS URLS (after starting):
    HTTP/2 Demo: https://localhost:8443
    HTTP/3 Demo: https://localhost:8444

For detailed help on any command, use:
    $0 <COMMAND> --help

EXAMPLES:
    $0 start --build-mode rebuild   # Start with fresh container builds
    $0 logs --follow                # Follow logs in real-time
    $0 debug troubleshoot           # Run comprehensive troubleshooting
    $0 cleanup --keep-certs         # Clean up but keep SSL certificates

EOF
}

# Show command-specific help
show_command_help() {
    local command="$1"
    
    case "$command" in
        start)
            title "Start Command Help"
            echo
            echo "Starts the HTTP/2 vs HTTP/3 demo with all containers and services."
            echo
            echo "Usage: $0 start [OPTIONS]"
            echo
            echo "This command will:"
            echo "  - Validate prerequisites (Docker, Docker Compose)"
            echo "  - Check port availability"
            echo "  - Generate SSL certificates if needed"
            echo "  - Build or pull container images"
            echo "  - Start all demo containers"
            echo "  - Run health checks"
            echo "  - Display access information"
            echo
            echo "For all available options, run:"
            echo "  $SCRIPT_DIR/start-demo.sh --help"
            ;;
        stop)
            title "Stop Command Help"
            echo
            echo "Gracefully stops all demo containers and services."
            echo
            echo "Usage: $0 stop [OPTIONS]"
            echo
            echo "This command will:"
            echo "  - Stop all running demo containers"
            echo "  - Clean up networks"
            echo "  - Optionally remove volumes and images"
            echo "  - Verify all containers are stopped"
            echo
            echo "For all available options, run:"
            echo "  $SCRIPT_DIR/stop-demo.sh --help"
            ;;
        cleanup)
            title "Cleanup Command Help"
            echo
            echo "Performs comprehensive cleanup of all demo resources."
            echo
            echo "Usage: $0 cleanup [OPTIONS]"
            echo
            echo "This command will:"
            echo "  - Stop and remove all containers"
            echo "  - Remove Docker images and volumes"
            echo "  - Clean up networks"
            echo "  - Remove SSL certificates (optional)"
            echo "  - Remove log files (optional)"
            echo "  - Clean up build artifacts"
            echo
            echo "For all available options, run:"
            echo "  $SCRIPT_DIR/cleanup-demo.sh --help"
            ;;
        configure)
            title "Configure Command Help"
            echo
            echo "Configure demo settings and environment variables."
            echo
            echo "Usage: $0 configure [OPTIONS]"
            echo
            echo "This command allows you to:"
            echo "  - Set custom ports for HTTP/2 and HTTP/3"
            echo "  - Configure logging levels"
            echo "  - Set build modes and timeouts"
            echo "  - Enable/disable features"
            echo "  - Validate configuration"
            echo
            echo "For all available options, run:"
            echo "  $SCRIPT_DIR/configure-demo.sh --help"
            ;;
        debug)
            title "Debug Command Help"
            echo
            echo "Debug and troubleshooting utilities."
            echo
            echo "Usage: $0 debug <SUBCOMMAND> [OPTIONS]"
            echo
            echo "Available subcommands:"
            echo "  logs            Show container logs"
            echo "  status          Show detailed status information"
            echo "  network         Show network connectivity information"
            echo "  certificates    Show SSL certificate information"
            echo "  performance     Run performance diagnostics"
            echo "  troubleshoot    Run comprehensive troubleshooting"
            echo "  collect         Collect all debug information"
            echo
            echo "For all available options, run:"
            echo "  $SCRIPT_DIR/debug-demo.sh --help"
            ;;
        monitor)
            title "Monitor Command Help"
            echo
            echo "Run monitoring and health checks for the demo."
            echo
            echo "Usage: $0 monitor [OPTIONS]"
            echo
            echo "This command will:"
            echo "  - Check Docker environment"
            echo "  - Verify port availability"
            echo "  - Validate SSL certificates"
            echo "  - Test HTTP/2 and HTTP/3 connectivity"
            echo "  - Check QUIC/UDP connectivity"
            echo "  - Monitor system resources"
            echo "  - Generate monitoring reports"
            echo
            echo "For all available options, run:"
            echo "  $SCRIPT_DIR/monitor.sh --help"
            ;;
        *)
            error "Unknown command: $command"
            echo
            show_usage
            return 1
            ;;
    esac
}

# Check if required scripts exist
check_scripts() {
    local required_scripts=(
        "start-demo.sh"
        "stop-demo.sh"
        "cleanup-demo.sh"
        "configure-demo.sh"
        "debug-demo.sh"
        "monitor.sh"
    )
    
    local missing_scripts=()
    
    for script in "${required_scripts[@]}"; do
        if [ ! -f "$SCRIPT_DIR/$script" ]; then
            missing_scripts+=("$script")
        elif [ ! -x "$SCRIPT_DIR/$script" ]; then
            warn "Script not executable: $script (fixing...)"
            chmod +x "$SCRIPT_DIR/$script"
        fi
    done
    
    if [ ${#missing_scripts[@]} -gt 0 ]; then
        error "Missing required scripts:"
        for script in "${missing_scripts[@]}"; do
            error "  - $script"
        done
        return 1
    fi
    
    return 0
}

# Execute command with proper script
execute_command() {
    local command="$1"
    shift
    
    case "$command" in
        start)
            log "Starting HTTP/2 vs HTTP/3 demo..."
            "$SCRIPT_DIR/start-demo.sh" "$@"
            ;;
        stop)
            log "Stopping HTTP/2 vs HTTP/3 demo..."
            "$SCRIPT_DIR/stop-demo.sh" "$@"
            ;;
        restart)
            log "Restarting HTTP/2 vs HTTP/3 demo..."
            "$SCRIPT_DIR/stop-demo.sh" "$@"
            sleep 2
            "$SCRIPT_DIR/start-demo.sh" "$@"
            ;;
        status)
            log "Checking demo status..."
            "$SCRIPT_DIR/debug-demo.sh" status "$@"
            ;;
        logs)
            log "Showing container logs..."
            "$SCRIPT_DIR/debug-demo.sh" logs "$@"
            ;;
        cleanup)
            log "Cleaning up demo resources..."
            "$SCRIPT_DIR/cleanup-demo.sh" "$@"
            ;;
        configure)
            log "Configuring demo settings..."
            "$SCRIPT_DIR/configure-demo.sh" "$@"
            ;;
        debug)
            log "Running debug utilities..."
            "$SCRIPT_DIR/debug-demo.sh" "$@"
            ;;
        monitor)
            log "Running monitoring and health checks..."
            "$SCRIPT_DIR/monitor.sh" "$@"
            ;;
        help)
            if [ $# -gt 0 ]; then
                show_command_help "$1"
            else
                show_usage
            fi
            ;;
        *)
            error "Unknown command: $command"
            echo
            show_usage
            return 1
            ;;
    esac
}

# Show quick status
show_quick_status() {
    info "Quick Status Check:"
    
    # Check if Docker is running
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        log "✓ Docker is running"
        
        # Check for demo containers
        local running_containers
        running_containers=$(docker ps --format "{{.Names}}" | grep -E "(http2-server|http3-server)" | wc -l)
        
        if [ "$running_containers" -gt 0 ]; then
            log "✓ Demo containers are running ($running_containers/2)"
            
            # Quick connectivity test
            if command -v curl >/dev/null 2>&1; then
                if curl -k -s --max-time 3 "https://localhost:8443" >/dev/null 2>&1; then
                    log "✓ HTTP/2 server is responding"
                else
                    warn "✗ HTTP/2 server is not responding"
                fi
                
                if curl -k -s --max-time 3 "https://localhost:8444" >/dev/null 2>&1; then
                    log "✓ HTTP/3 server is responding"
                else
                    warn "✗ HTTP/3 server is not responding"
                fi
            fi
        else
            info "No demo containers are running"
            info "Use '$0 start' to start the demo"
        fi
    else
        warn "Docker is not running or not available"
    fi
    
    echo
    info "Access URLs:"
    info "  HTTP/2 Demo: https://localhost:8443"
    info "  HTTP/3 Demo: https://localhost:8444"
    echo
    info "Available commands: start, stop, status, logs, cleanup, configure, debug, monitor"
}

# Main function
main() {
    # Check if no arguments provided
    if [ $# -eq 0 ]; then
        show_usage
        echo
        show_quick_status
        return 0
    fi
    
    # Check if required scripts exist
    if ! check_scripts; then
        error "Cannot proceed without required scripts"
        return 1
    fi
    
    # Parse command
    local command="$1"
    shift
    
    # Handle help requests
    if [ "$command" = "--help" ] || [ "$command" = "-h" ]; then
        show_usage
        return 0
    fi
    
    # Execute command
    execute_command "$command" "$@"
}

# Handle script interruption
trap 'error "Operation interrupted"; exit 130' INT TERM

# Run main function
main "$@"