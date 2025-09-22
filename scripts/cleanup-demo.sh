#!/bin/bash

# HTTP/2 vs HTTP/3 Demo Cleanup Script
# This script performs comprehensive cleanup of all demo resources

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="${LOG_DIR:-/tmp/h2-h3-demo-logs}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_DIR/cleanup_$TIMESTAMP.log"

# Default configuration
DEFAULT_COMPOSE_FILE="docker-compose.yml"

# Environment variables with defaults
COMPOSE_FILE="${COMPOSE_FILE:-$DEFAULT_COMPOSE_FILE}"
FORCE_CLEANUP="${FORCE_CLEANUP:-false}"
KEEP_LOGS="${KEEP_LOGS:-false}"
KEEP_CERTS="${KEEP_CERTS:-false}"
DRY_RUN="${DRY_RUN:-false}"

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

dry_run() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] DRY RUN: $1"
    echo -e "${CYAN}$message${NC}"
    echo "$message" >> "$LOG_FILE" 2>/dev/null || true
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

HTTP/2 vs HTTP/3 Demo Cleanup Script

This script performs comprehensive cleanup of all demo resources including:
- Docker containers, images, volumes, and networks
- Generated SSL certificates
- Log files and temporary data
- Build artifacts and caches

OPTIONS:
    -h, --help              Show this help message
    -f, --compose-file FILE Docker compose file (default: $DEFAULT_COMPOSE_FILE)
    --force                 Force cleanup without confirmation prompts
    --keep-logs             Keep log files
    --keep-certs            Keep generated SSL certificates
    --dry-run               Show what would be cleaned up without doing it
    --nuclear               Remove everything including Docker system resources

ENVIRONMENT VARIABLES:
    COMPOSE_FILE            Docker compose file path
    FORCE_CLEANUP           Force cleanup without prompts (true/false)
    KEEP_LOGS               Keep log files (true/false)
    KEEP_CERTS              Keep certificates (true/false)
    DRY_RUN                 Dry run mode (true/false)

EXAMPLES:
    $0                      # Interactive cleanup with confirmations
    $0 --force              # Force cleanup without prompts
    $0 --dry-run            # Show what would be cleaned up
    $0 --keep-logs --keep-certs  # Cleanup but keep logs and certificates
    $0 --nuclear            # Complete system cleanup (use with caution)

WARNING: This script will remove containers, images, volumes, and files.
Use --dry-run first to see what will be removed.

EOF
}

# Setup logging directory
setup_logging() {
    mkdir -p "$LOG_DIR"
    log "Starting HTTP/2 vs HTTP/3 demo cleanup"
    log "Log file: $LOG_FILE"
    log "Project root: $PROJECT_ROOT"
    
    if [ "$DRY_RUN" = "true" ]; then
        warn "DRY RUN MODE - No actual cleanup will be performed"
    fi
}

# Confirm cleanup action
confirm_action() {
    local action="$1"
    local details="$2"
    
    if [ "$FORCE_CLEANUP" = "true" ] || [ "$DRY_RUN" = "true" ]; then
        return 0
    fi
    
    echo -e "${YELLOW}About to: $action${NC}"
    if [ -n "$details" ]; then
        echo -e "${BLUE}Details: $details${NC}"
    fi
    
    read -p "Continue? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        info "Skipped: $action"
        return 1
    fi
}

# Stop and remove containers
cleanup_containers() {
    info "Cleaning up demo containers..."
    
    cd "$PROJECT_ROOT"
    
    local compose_cmd
    if command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker-compose"
    else
        compose_cmd="docker compose"
    fi
    
    # Check if containers exist
    local containers
    containers=$($compose_cmd -f "$COMPOSE_FILE" ps -a -q 2>/dev/null || true)
    
    if [ -n "$containers" ]; then
        if confirm_action "Stop and remove all demo containers" "$(echo "$containers" | wc -l) containers found"; then
            if [ "$DRY_RUN" = "true" ]; then
                dry_run "Would stop and remove containers"
                $compose_cmd -f "$COMPOSE_FILE" ps -a 2>&1 | tee -a "$LOG_FILE"
            else
                info "Stopping and removing containers..."
                $compose_cmd -f "$COMPOSE_FILE" down --remove-orphans --timeout 30 2>&1 | tee -a "$LOG_FILE"
                log "✓ Containers cleaned up"
            fi
        fi
    else
        info "No demo containers found"
    fi
}

# Remove Docker images
cleanup_images() {
    info "Cleaning up demo images..."
    
    cd "$PROJECT_ROOT"
    
    local compose_cmd
    if command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker-compose"
    else
        compose_cmd="docker compose"
    fi
    
    # Get image names from compose file
    local images
    images=$($compose_cmd -f "$COMPOSE_FILE" config 2>/dev/null | grep "image:" | awk '{print $2}' | sort -u || true)
    
    # Also check for built images
    local built_images
    built_images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "(http2-server|http3-server|h2-h3)" || true)
    
    local all_images="$images $built_images"
    
    if [ -n "$all_images" ]; then
        if confirm_action "Remove demo Docker images" "$all_images"; then
            if [ "$DRY_RUN" = "true" ]; then
                dry_run "Would remove images: $all_images"
            else
                echo "$all_images" | tr ' ' '\n' | while read image; do
                    if [ -n "$image" ] && docker images -q "$image" >/dev/null 2>&1; then
                        info "Removing image: $image"
                        docker rmi "$image" 2>&1 | tee -a "$LOG_FILE" || warn "Failed to remove image: $image"
                    fi
                done
                log "✓ Images cleaned up"
            fi
        fi
    else
        info "No demo images found"
    fi
    
    # Clean up dangling images
    local dangling_images
    dangling_images=$(docker images -f "dangling=true" -q)
    
    if [ -n "$dangling_images" ]; then
        if confirm_action "Remove dangling Docker images" "$(echo "$dangling_images" | wc -l) dangling images"; then
            if [ "$DRY_RUN" = "true" ]; then
                dry_run "Would remove $(echo "$dangling_images" | wc -l) dangling images"
            else
                info "Removing dangling images..."
                echo "$dangling_images" | xargs docker rmi 2>&1 | tee -a "$LOG_FILE" || warn "Failed to remove some dangling images"
                log "✓ Dangling images cleaned up"
            fi
        fi
    fi
}

# Remove Docker volumes
cleanup_volumes() {
    info "Cleaning up demo volumes..."
    
    cd "$PROJECT_ROOT"
    
    local compose_cmd
    if command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker-compose"
    else
        compose_cmd="docker compose"
    fi
    
    # Get volume names from compose file
    local volumes
    volumes=$($compose_cmd -f "$COMPOSE_FILE" config --volumes 2>/dev/null || true)
    
    if [ -n "$volumes" ]; then
        if confirm_action "Remove demo Docker volumes" "$volumes"; then
            if [ "$DRY_RUN" = "true" ]; then
                dry_run "Would remove volumes: $volumes"
            else
                $compose_cmd -f "$COMPOSE_FILE" down -v 2>&1 | tee -a "$LOG_FILE"
                log "✓ Volumes cleaned up"
            fi
        fi
    else
        info "No demo volumes found"
    fi
    
    # Clean up orphaned volumes
    local orphaned_volumes
    orphaned_volumes=$(docker volume ls -f "dangling=true" -q)
    
    if [ -n "$orphaned_volumes" ]; then
        if confirm_action "Remove orphaned Docker volumes" "$(echo "$orphaned_volumes" | wc -l) orphaned volumes"; then
            if [ "$DRY_RUN" = "true" ]; then
                dry_run "Would remove $(echo "$orphaned_volumes" | wc -l) orphaned volumes"
            else
                info "Removing orphaned volumes..."
                echo "$orphaned_volumes" | xargs docker volume rm 2>&1 | tee -a "$LOG_FILE" || warn "Failed to remove some orphaned volumes"
                log "✓ Orphaned volumes cleaned up"
            fi
        fi
    fi
}

# Remove Docker networks
cleanup_networks() {
    info "Cleaning up demo networks..."
    
    cd "$PROJECT_ROOT"
    
    local compose_cmd
    if command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker-compose"
    else
        compose_cmd="docker compose"
    fi
    
    # Remove compose networks
    if confirm_action "Remove demo Docker networks" "Networks created by docker-compose"; then
        if [ "$DRY_RUN" = "true" ]; then
            dry_run "Would remove compose networks"
        else
            $compose_cmd -f "$COMPOSE_FILE" down --remove-orphans 2>&1 | tee -a "$LOG_FILE" || true
            log "✓ Compose networks cleaned up"
        fi
    fi
    
    # Clean up orphaned networks
    local orphaned_networks
    orphaned_networks=$(docker network ls --filter "name=h2-h3" --format "{{.Name}}" 2>/dev/null || true)
    
    if [ -n "$orphaned_networks" ]; then
        if confirm_action "Remove orphaned demo networks" "$orphaned_networks"; then
            if [ "$DRY_RUN" = "true" ]; then
                dry_run "Would remove networks: $orphaned_networks"
            else
                echo "$orphaned_networks" | while read network; do
                    if [ -n "$network" ]; then
                        info "Removing network: $network"
                        docker network rm "$network" 2>&1 | tee -a "$LOG_FILE" || warn "Failed to remove network: $network"
                    fi
                done
                log "✓ Orphaned networks cleaned up"
            fi
        fi
    fi
}

# Clean up SSL certificates
cleanup_certificates() {
    if [ "$KEEP_CERTS" = "true" ]; then
        info "Keeping SSL certificates as requested"
        return 0
    fi
    
    info "Cleaning up SSL certificates..."
    
    local cert_dir="$PROJECT_ROOT/certs"
    
    if [ -d "$cert_dir" ]; then
        local cert_files
        cert_files=$(find "$cert_dir" -type f \( -name "*.crt" -o -name "*.key" -o -name "*.pem" \) 2>/dev/null || true)
        
        if [ -n "$cert_files" ]; then
            if confirm_action "Remove SSL certificates" "$cert_dir"; then
                if [ "$DRY_RUN" = "true" ]; then
                    dry_run "Would remove certificate files:"
                    echo "$cert_files" | while read file; do
                        dry_run "  $file"
                    done
                else
                    info "Removing certificate files..."
                    echo "$cert_files" | while read file; do
                        if [ -f "$file" ]; then
                            rm -f "$file"
                            info "Removed: $file"
                        fi
                    done
                    
                    # Remove .gitkeep if it's the only file left
                    if [ "$(find "$cert_dir" -type f | wc -l)" -eq 1 ] && [ -f "$cert_dir/.gitkeep" ]; then
                        info "Certificate directory is empty except for .gitkeep"
                    fi
                    
                    log "✓ SSL certificates cleaned up"
                fi
            fi
        else
            info "No SSL certificate files found"
        fi
    else
        info "Certificate directory not found"
    fi
}

# Clean up log files
cleanup_logs() {
    if [ "$KEEP_LOGS" = "true" ]; then
        info "Keeping log files as requested"
        return 0
    fi
    
    info "Cleaning up log files..."
    
    if [ -d "$LOG_DIR" ]; then
        local log_files
        log_files=$(find "$LOG_DIR" -name "*.log" -o -name "*_*.txt" 2>/dev/null || true)
        
        if [ -n "$log_files" ]; then
            if confirm_action "Remove log files" "$LOG_DIR ($(echo "$log_files" | wc -l) files)"; then
                if [ "$DRY_RUN" = "true" ]; then
                    dry_run "Would remove log files:"
                    echo "$log_files" | while read file; do
                        dry_run "  $file"
                    done
                else
                    info "Removing log files..."
                    echo "$log_files" | while read file; do
                        if [ -f "$file" ] && [ "$file" != "$LOG_FILE" ]; then
                            rm -f "$file"
                            info "Removed: $file"
                        fi
                    done
                    
                    # Remove empty log directory
                    if [ "$(find "$LOG_DIR" -type f | wc -l)" -eq 1 ]; then
                        info "Log directory will be empty after this cleanup"
                    fi
                    
                    log "✓ Log files cleaned up"
                fi
            fi
        else
            info "No log files found"
        fi
    else
        info "Log directory not found"
    fi
}

# Clean up build artifacts
cleanup_build_artifacts() {
    info "Cleaning up build artifacts..."
    
    local build_dirs=("$PROJECT_ROOT/.docker" "$PROJECT_ROOT/node_modules" "$PROJECT_ROOT/.cache")
    local found_artifacts=false
    
    for dir in "${build_dirs[@]}"; do
        if [ -d "$dir" ]; then
            found_artifacts=true
            if confirm_action "Remove build directory" "$dir"; then
                if [ "$DRY_RUN" = "true" ]; then
                    dry_run "Would remove directory: $dir"
                else
                    info "Removing build directory: $dir"
                    rm -rf "$dir"
                    log "✓ Removed: $dir"
                fi
            fi
        fi
    done
    
    # Clean up temporary files
    local temp_files
    temp_files=$(find "$PROJECT_ROOT" -name "*.tmp" -o -name "*.temp" -o -name ".DS_Store" 2>/dev/null || true)
    
    if [ -n "$temp_files" ]; then
        found_artifacts=true
        if confirm_action "Remove temporary files" "$(echo "$temp_files" | wc -l) files"; then
            if [ "$DRY_RUN" = "true" ]; then
                dry_run "Would remove temporary files:"
                echo "$temp_files" | while read file; do
                    dry_run "  $file"
                done
            else
                echo "$temp_files" | while read file; do
                    if [ -f "$file" ]; then
                        rm -f "$file"
                        info "Removed: $file"
                    fi
                done
                log "✓ Temporary files cleaned up"
            fi
        fi
    fi
    
    if [ "$found_artifacts" = "false" ]; then
        info "No build artifacts found"
    fi
}

# Nuclear cleanup - system-wide Docker cleanup
nuclear_cleanup() {
    if [ "$NUCLEAR_MODE" != "true" ]; then
        return 0
    fi
    
    warn "NUCLEAR CLEANUP MODE - This will remove ALL Docker resources"
    
    if confirm_action "NUCLEAR: Remove all Docker containers, images, volumes, and networks" "THIS AFFECTS YOUR ENTIRE DOCKER SYSTEM"; then
        if [ "$DRY_RUN" = "true" ]; then
            dry_run "Would perform Docker system prune --all --volumes --force"
        else
            warn "Performing nuclear Docker cleanup..."
            docker system prune --all --volumes --force 2>&1 | tee -a "$LOG_FILE"
            log "✓ Nuclear cleanup completed"
        fi
    fi
}

# Show cleanup summary
show_cleanup_summary() {
    info "=== CLEANUP SUMMARY ==="
    
    if [ "$DRY_RUN" = "true" ]; then
        log "✓ Dry run completed - no actual cleanup performed"
    else
        log "✓ HTTP/2 vs HTTP/3 demo cleanup completed"
    fi
    
    log ""
    log "Cleanup actions:"
    log "  - Containers: Removed"
    log "  - Images: Removed"
    log "  - Volumes: Removed"
    log "  - Networks: Removed"
    log "  - Certificates: $([ "$KEEP_CERTS" = "true" ] && echo "Kept" || echo "Removed")"
    log "  - Logs: $([ "$KEEP_LOGS" = "true" ] && echo "Kept" || echo "Removed")"
    log "  - Build artifacts: Removed"
    log ""
    log "Current cleanup log: $LOG_FILE"
    log ""
    log "To restart the demo:"
    log "  $SCRIPT_DIR/start-demo.sh"
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
            --force)
                FORCE_CLEANUP="true"
                shift
                ;;
            --keep-logs)
                KEEP_LOGS="true"
                shift
                ;;
            --keep-certs)
                KEEP_CERTS="true"
                shift
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --nuclear)
                NUCLEAR_MODE="true"
                FORCE_CLEANUP="true"
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

# Main cleanup function
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
    
    # Perform cleanup steps
    cleanup_containers || exit_code=1
    cleanup_images || exit_code=1
    cleanup_volumes || exit_code=1
    cleanup_networks || exit_code=1
    cleanup_certificates || exit_code=1
    cleanup_logs || exit_code=1
    cleanup_build_artifacts || exit_code=1
    nuclear_cleanup || exit_code=1
    
    # Show summary
    show_cleanup_summary
    
    if [ $exit_code -eq 0 ]; then
        if [ "$DRY_RUN" = "true" ]; then
            log "✓ Dry run completed successfully"
        else
            log "✓ Cleanup completed successfully"
        fi
    else
        error "✗ Cleanup completed with issues"
    fi
    
    return $exit_code
}

# Handle script interruption
trap 'error "Cleanup interrupted"; exit 130' INT TERM

# Run main function
main "$@"