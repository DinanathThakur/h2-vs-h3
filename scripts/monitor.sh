#!/bin/bash

# Comprehensive monitoring script for HTTP/2 vs HTTP/3 demo
# This script runs all health checks and monitoring tasks

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/tmp/h2-h3-demo-logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_DIR/monitor_$TIMESTAMP.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log messages
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

# Setup logging
setup_logging() {
    mkdir -p "$LOG_DIR"
    log "Starting comprehensive monitoring for HTTP/2 vs HTTP/3 demo"
    log "Log file: $LOG_FILE"
}

# Run a monitoring script and capture results
run_monitoring_script() {
    local script_name=$1
    local script_path="$SCRIPT_DIR/$script_name"
    local description=$2
    
    info "Running $description..."
    
    if [ ! -f "$script_path" ]; then
        error "Monitoring script not found: $script_path"
        return 1
    fi
    
    if [ ! -x "$script_path" ]; then
        warn "Making script executable: $script_path"
        chmod +x "$script_path"
    fi
    
    # Run the script and capture output
    local output exit_code
    output=$("$script_path" 2>&1)
    exit_code=$?
    
    # Log the output
    echo "$output" >> "$LOG_FILE" 2>/dev/null || true
    
    if [ $exit_code -eq 0 ]; then
        log "✓ $description completed successfully"
    else
        error "✗ $description failed (exit code: $exit_code)"
    fi
    
    return $exit_code
}

# Check Docker environment
check_docker_environment() {
    info "Checking Docker environment..."
    
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker is not installed or not in PATH"
        return 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        error "Docker daemon is not running"
        return 1
    fi
    
    log "✓ Docker environment is ready"
    
    # Check if demo containers are running
    local running_containers
    running_containers=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(http2-server|http3-server)" || true)
    
    if [ -n "$running_containers" ]; then
        log "Demo containers status:"
        echo "$running_containers" | while read line; do
            log "  $line"
        done
    else
        warn "No demo containers are currently running"
    fi
    
    return 0
}

# System resource monitoring
monitor_system_resources() {
    info "Monitoring system resources..."
    
    # CPU usage
    if command -v top >/dev/null 2>&1; then
        local cpu_usage
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS top command
            cpu_usage=$(top -l 1 -n 0 | grep "CPU usage" | awk '{print $3}' | cut -d'%' -f1 || echo "unknown")
        else
            # Linux top command
            cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 || echo "unknown")
        fi
        log "CPU usage: ${cpu_usage}%"
    fi
    
    # Memory usage
    if command -v free >/dev/null 2>&1; then
        local memory_info
        memory_info=$(free -h | grep "Mem:" | awk '{print "Used: " $3 "/" $2 " (" $3/$2*100 "%)"}' || echo "unknown")
        log "Memory usage: $memory_info"
    fi
    
    # Disk usage
    if command -v df >/dev/null 2>&1; then
        local disk_usage
        disk_usage=$(df -h / | tail -1 | awk '{print "Used: " $3 "/" $2 " (" $5 ")"}' || echo "unknown")
        log "Disk usage: $disk_usage"
    fi
    
    # Network connections
    if command -v netstat >/dev/null 2>&1; then
        local tcp_connections udp_connections
        tcp_connections=$(netstat -tn | grep ESTABLISHED | wc -l || echo "unknown")
        udp_connections=$(netstat -un | wc -l || echo "unknown")
        log "Network connections: TCP=$tcp_connections, UDP=$udp_connections"
    fi
    
    return 0
}

# Generate monitoring report
generate_report() {
    local overall_status=$1
    local report_file="$LOG_DIR/monitoring_report_$TIMESTAMP.txt"
    
    info "Generating monitoring report..."
    
    cat > "$report_file" << EOF
HTTP/2 vs HTTP/3 Demo - Monitoring Report
Generated: $(date)
Overall Status: $overall_status

=== System Information ===
Hostname: $(hostname)
OS: $(uname -s) $(uname -r)
Architecture: $(uname -m)
Uptime: $(uptime)

=== Docker Information ===
Docker Version: $(docker --version 2>/dev/null || echo "Not available")
Docker Compose Version: $(docker-compose --version 2>/dev/null || echo "Not available")

=== Container Status ===
EOF
    
    # Add container information if Docker is available
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        echo "Running Containers:" >> "$report_file"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" >> "$report_file" 2>/dev/null || echo "Could not retrieve container information" >> "$report_file"
        echo "" >> "$report_file"
        
        echo "All Containers:" >> "$report_file"
        docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" >> "$report_file" 2>/dev/null || echo "Could not retrieve container information" >> "$report_file"
    else
        echo "Docker not available or not running" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

=== Network Ports ===
Listening Ports:
$(netstat -tuln 2>/dev/null | grep -E ":(8443|8444) " || echo "Demo ports not found")

=== Log File Location ===
Detailed logs: $LOG_FILE
Report file: $report_file

=== Summary ===
Monitoring completed at: $(date)
Check the detailed log file for complete output from all monitoring scripts.
EOF
    
    log "✓ Monitoring report generated: $report_file"
    
    # Display summary
    info "=== MONITORING SUMMARY ==="
    info "Overall Status: $overall_status"
    info "Detailed logs: $LOG_FILE"
    info "Report file: $report_file"
}

# Main monitoring function
main() {
    local overall_exit_code=0
    local failed_checks=0
    local total_checks=0
    
    # Setup
    setup_logging
    
    # System checks
    check_docker_environment || overall_exit_code=1
    monitor_system_resources || true  # Don't fail on resource monitoring
    
    # Run all monitoring scripts
    local monitoring_scripts=(
        "port-check.sh:Port Availability Check"
        "cert-validation.sh:SSL Certificate Validation"
        "health-check-http2.sh:HTTP/2 Server Health Check"
        "health-check-http3.sh:HTTP/3 Server Health Check"
        "quic-connectivity-test.sh:QUIC/UDP Connectivity Test"
    )
    
    for script_info in "${monitoring_scripts[@]}"; do
        local script_name="${script_info%%:*}"
        local description="${script_info##*:}"
        
        total_checks=$((total_checks + 1))
        
        if ! run_monitoring_script "$script_name" "$description"; then
            failed_checks=$((failed_checks + 1))
            overall_exit_code=1
        fi
        
        # Add separator between checks
        echo "" >> "$LOG_FILE" 2>/dev/null || true
    done
    
    # Determine overall status
    local overall_status
    if [ $overall_exit_code -eq 0 ]; then
        overall_status="HEALTHY"
        log "✓ All monitoring checks passed ($total_checks/$total_checks)"
    else
        overall_status="ISSUES_DETECTED"
        error "✗ Some monitoring checks failed ($failed_checks/$total_checks failed)"
    fi
    
    # Generate report
    generate_report "$overall_status"
    
    return $overall_exit_code
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Comprehensive monitoring script for HTTP/2 vs HTTP/3 demo"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --quiet, -q    Suppress output (logs only)"
        echo "  --verbose, -v  Verbose output"
        echo ""
        echo "The script runs all monitoring checks and generates a report."
        echo "Logs are saved to: $LOG_DIR/"
        exit 0
        ;;
    --quiet|-q)
        # Redirect stdout to log file only
        exec 1>>"$LOG_FILE"
        ;;
    --verbose|-v)
        # Enable verbose output
        set -x
        ;;
esac

# Make all scripts executable
chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true

# Run main function
main "$@"