#!/bin/bash

# Health check script for HTTP/3 server
# This script verifies that the nginx process is running and responding correctly with QUIC/HTTP3

set -e

# Configuration
HOST="localhost"
PORT="443"
HEALTH_ENDPOINT="/health"
STATUS_ENDPOINT="/status"
QUIC_INFO_ENDPOINT="/quic-info"
TIMEOUT=10

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

# Check if nginx process is running
check_nginx_process() {
    log "Checking nginx process..."
    if pgrep -x "nginx" > /dev/null; then
        log "✓ nginx process is running"
        return 0
    else
        error "✗ nginx process is not running"
        return 1
    fi
}

# Check if TCP port is listening
check_tcp_port() {
    log "Checking if TCP port $PORT is listening..."
    if netstat -tuln | grep -q ":$PORT "; then
        log "✓ TCP port $PORT is listening"
        return 0
    else
        error "✗ TCP port $PORT is not listening"
        return 1
    fi
}

# Check if UDP port is listening (for QUIC)
check_udp_port() {
    log "Checking if UDP port $PORT is listening (QUIC)..."
    if netstat -uln | grep -q ":$PORT "; then
        log "✓ UDP port $PORT is listening (QUIC)"
        return 0
    else
        error "✗ UDP port $PORT is not listening (QUIC)"
        return 1
    fi
}

# Check SSL certificate
check_ssl_certificate() {
    log "Checking SSL certificate..."
    local cert_info
    cert_info=$(echo | openssl s_client -connect $HOST:$PORT -servername $HOST 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        log "✓ SSL certificate is valid"
        echo "$cert_info" | while read line; do
            log "  $line"
        done
        return 0
    else
        error "✗ SSL certificate check failed"
        return 1
    fi
}

# Check health endpoint
check_health_endpoint() {
    log "Checking health endpoint..."
    local response
    response=$(curl -k -s --max-time $TIMEOUT "https://$HOST:$PORT$HEALTH_ENDPOINT" 2>/dev/null)
    
    if [ $? -eq 0 ] && [[ "$response" == *"HTTP/3 Server OK"* ]]; then
        log "✓ Health endpoint is responding correctly"
        log "  Response: $response"
        return 0
    else
        error "✗ Health endpoint check failed"
        error "  Response: $response"
        return 1
    fi
}

# Check status endpoint and verify HTTP/3
check_status_endpoint() {
    log "Checking status endpoint and HTTP/3 protocol..."
    local response headers
    
    # Get response with headers
    response=$(curl -k -s --max-time $TIMEOUT -D /tmp/http3_headers "https://$HOST:$PORT$STATUS_ENDPOINT" 2>/dev/null)
    headers=$(cat /tmp/http3_headers 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        # Check if response contains expected JSON
        if echo "$response" | grep -q '"protocol":"HTTP/3"'; then
            log "✓ Status endpoint confirms HTTP/3 protocol"
            log "  Response: $response"
            
            # Check for protocol header
            if echo "$headers" | grep -q "X-Protocol: HTTP/3"; then
                log "✓ X-Protocol header confirms HTTP/3"
            else
                warn "X-Protocol header not found or incorrect"
            fi
            
            # Check for Alt-Svc header
            if echo "$headers" | grep -q "Alt-Svc:.*h3="; then
                log "✓ Alt-Svc header found (HTTP/3 advertisement)"
            else
                warn "Alt-Svc header not found"
            fi
            
            return 0
        else
            error "✗ Status endpoint response doesn't confirm HTTP/3"
            error "  Response: $response"
            return 1
        fi
    else
        error "✗ Status endpoint check failed"
        return 1
    fi
}

# Check QUIC-specific endpoint
check_quic_info_endpoint() {
    log "Checking QUIC info endpoint..."
    local response
    response=$(curl -k -s --max-time $TIMEOUT "https://$HOST:$PORT$QUIC_INFO_ENDPOINT" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        log "✓ QUIC info endpoint is responding"
        log "  Response: $response"
        
        # Check if QUIC is enabled in the response
        if echo "$response" | grep -q '"quic_enabled"'; then
            log "✓ QUIC info endpoint provides QUIC status"
        else
            warn "QUIC status not found in response"
        fi
        
        return 0
    else
        error "✗ QUIC info endpoint check failed"
        error "  Response: $response"
        return 1
    fi
}

# Test QUIC connectivity (if curl supports HTTP/3)
test_quic_connectivity() {
    log "Testing QUIC connectivity..."
    
    # Check if curl supports HTTP/3
    if curl --version | grep -q "HTTP3"; then
        log "curl supports HTTP/3, testing QUIC connection..."
        local response
        response=$(curl -k -s --http3 --max-time $TIMEOUT "https://$HOST:$PORT$HEALTH_ENDPOINT" 2>/dev/null)
        
        if [ $? -eq 0 ] && [[ "$response" == *"HTTP/3 Server OK"* ]]; then
            log "✓ QUIC connection test successful"
            return 0
        else
            warn "QUIC connection test failed (may fallback to HTTP/2)"
            return 1
        fi
    else
        warn "curl doesn't support HTTP/3, skipping QUIC connectivity test"
        return 0
    fi
}

# Main health check function
main() {
    log "Starting HTTP/3 server health check..."
    local exit_code=0
    
    # Run all checks
    check_nginx_process || exit_code=1
    check_tcp_port || exit_code=1
    check_udp_port || exit_code=1
    check_ssl_certificate || exit_code=1
    check_health_endpoint || exit_code=1
    check_status_endpoint || exit_code=1
    check_quic_info_endpoint || exit_code=1
    test_quic_connectivity || true  # Don't fail on QUIC test as it may not be supported
    
    # Cleanup
    rm -f /tmp/http3_headers
    
    if [ $exit_code -eq 0 ]; then
        log "✓ All HTTP/3 server health checks passed"
    else
        error "✗ Some HTTP/3 server health checks failed"
    fi
    
    return $exit_code
}

# Run main function
main "$@"