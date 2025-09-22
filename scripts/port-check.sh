#!/bin/bash

# Port availability verification script
# This script checks if the required ports are available and not conflicting

set -e

# Configuration
HTTP2_PORT="8443"
HTTP3_PORT="8444"
HTTP3_UDP_PORT="8444"
TIMEOUT=5

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to log messages
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Check if a TCP port is available
check_tcp_port_available() {
    local port=$1
    local service_name=$2
    
    log "Checking if TCP port $port is available for $service_name..."
    
    # Check if port is in use
    if netstat -tuln | grep -q ":$port "; then
        local process_info
        process_info=$(lsof -i :$port 2>/dev/null | tail -n +2 | head -1)
        
        if [ -n "$process_info" ]; then
            error "✗ TCP port $port is already in use by: $process_info"
        else
            error "✗ TCP port $port is already in use"
        fi
        return 1
    else
        log "✓ TCP port $port is available for $service_name"
        return 0
    fi
}

# Check if a UDP port is available
check_udp_port_available() {
    local port=$1
    local service_name=$2
    
    log "Checking if UDP port $port is available for $service_name..."
    
    # Check if port is in use
    if netstat -uln | grep -q ":$port "; then
        local process_info
        process_info=$(lsof -i UDP:$port 2>/dev/null | tail -n +2 | head -1)
        
        if [ -n "$process_info" ]; then
            error "✗ UDP port $port is already in use by: $process_info"
        else
            error "✗ UDP port $port is already in use"
        fi
        return 1
    else
        log "✓ UDP port $port is available for $service_name"
        return 0
    fi
}

# Test port connectivity
test_port_connectivity() {
    local host=$1
    local port=$2
    local protocol=$3
    local service_name=$4
    
    log "Testing $protocol connectivity to $host:$port for $service_name..."
    
    if [ "$protocol" = "tcp" ]; then
        if timeout $TIMEOUT bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
            log "✓ TCP connection to $host:$port successful"
            return 0
        else
            error "✗ TCP connection to $host:$port failed"
            return 1
        fi
    elif [ "$protocol" = "udp" ]; then
        # UDP connectivity test is more complex, we'll use nc if available
        if command -v nc >/dev/null 2>&1; then
            if timeout $TIMEOUT nc -u -z $host $port 2>/dev/null; then
                log "✓ UDP connection to $host:$port successful"
                return 0
            else
                warn "UDP connection test to $host:$port inconclusive (UDP is connectionless)"
                return 0  # Don't fail on UDP test as it's connectionless
            fi
        else
            warn "netcat (nc) not available, skipping UDP connectivity test"
            return 0
        fi
    fi
}

# Check Docker port mappings
check_docker_port_mappings() {
    log "Checking Docker port mappings..."
    
    if command -v docker >/dev/null 2>&1; then
        # Check if Docker is running
        if ! docker info >/dev/null 2>&1; then
            warn "Docker is not running, skipping Docker port mapping check"
            return 0
        fi
        
        # Check for conflicting containers
        local conflicting_containers
        conflicting_containers=$(docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -E ":($HTTP2_PORT|$HTTP3_PORT)->" || true)
        
        if [ -n "$conflicting_containers" ]; then
            error "✗ Found Docker containers using required ports:"
            echo "$conflicting_containers"
            return 1
        else
            log "✓ No conflicting Docker containers found"
            return 0
        fi
    else
        warn "Docker not available, skipping Docker port mapping check"
        return 0
    fi
}

# Check system firewall rules
check_firewall_rules() {
    log "Checking firewall rules..."
    
    # Check if ufw is active (Ubuntu/Debian)
    if command -v ufw >/dev/null 2>&1; then
        local ufw_status
        ufw_status=$(ufw status 2>/dev/null | head -1)
        
        if echo "$ufw_status" | grep -q "Status: active"; then
            log "UFW firewall is active, checking rules..."
            
            # Check if ports are allowed
            if ufw status | grep -q "$HTTP2_PORT"; then
                log "✓ HTTP/2 port $HTTP2_PORT found in UFW rules"
            else
                warn "HTTP/2 port $HTTP2_PORT not found in UFW rules"
            fi
            
            if ufw status | grep -q "$HTTP3_PORT"; then
                log "✓ HTTP/3 port $HTTP3_PORT found in UFW rules"
            else
                warn "HTTP/3 port $HTTP3_PORT not found in UFW rules"
            fi
        else
            log "✓ UFW firewall is inactive"
        fi
    fi
    
    # Check if iptables has rules (basic check)
    if command -v iptables >/dev/null 2>&1; then
        local iptables_rules
        iptables_rules=$(iptables -L INPUT -n 2>/dev/null | grep -E "dpt:($HTTP2_PORT|$HTTP3_PORT)" || true)
        
        if [ -n "$iptables_rules" ]; then
            log "✓ Found iptables rules for demo ports"
        else
            log "No specific iptables rules found for demo ports (may use default policy)"
        fi
    fi
    
    return 0
}

# Main port check function
main() {
    log "Starting port availability verification..."
    local exit_code=0
    
    # Check port availability
    check_tcp_port_available $HTTP2_PORT "HTTP/2 server" || exit_code=1
    check_tcp_port_available $HTTP3_PORT "HTTP/3 server" || exit_code=1
    check_udp_port_available $HTTP3_UDP_PORT "HTTP/3 QUIC" || exit_code=1
    
    # Check Docker port mappings
    check_docker_port_mappings || exit_code=1
    
    # Check firewall rules
    check_firewall_rules || true  # Don't fail on firewall checks
    
    # Test connectivity to localhost (if ports are in use by our services)
    if [ $exit_code -ne 0 ]; then
        log "Some ports are in use, testing if they're our services..."
        test_port_connectivity "localhost" $HTTP2_PORT "tcp" "HTTP/2 server" || true
        test_port_connectivity "localhost" $HTTP3_PORT "tcp" "HTTP/3 server" || true
        test_port_connectivity "localhost" $HTTP3_UDP_PORT "udp" "HTTP/3 QUIC" || true
    fi
    
    if [ $exit_code -eq 0 ]; then
        log "✓ All port availability checks passed"
    else
        error "✗ Some port availability checks failed"
    fi
    
    return $exit_code
}

# Run main function
main "$@"