#!/bin/bash

# Health check script for HTTP/2 server
# This script verifies that the nginx process is running and responding correctly

set -e

# Configuration
HOST="localhost"
PORT="443"
HEALTH_ENDPOINT="/health"
STATUS_ENDPOINT="/status"
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

# Check if port is listening
check_port() {
    log "Checking if port $PORT is listening..."
    if netstat -tuln | grep -q ":$PORT "; then
        log "✓ Port $PORT is listening"
        return 0
    else
        error "✗ Port $PORT is not listening"
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
    
    if [ $? -eq 0 ] && [[ "$response" == *"HTTP/2 Server OK"* ]]; then
        log "✓ Health endpoint is responding correctly"
        log "  Response: $response"
        return 0
    else
        error "✗ Health endpoint check failed"
        error "  Response: $response"
        return 1
    fi
}

# Check status endpoint and verify HTTP/2
check_status_endpoint() {
    log "Checking status endpoint and HTTP/2 protocol..."
    local response headers
    
    # Get response with headers
    response=$(curl -k -s --max-time $TIMEOUT -D /tmp/http2_headers "https://$HOST:$PORT$STATUS_ENDPOINT" 2>/dev/null)
    headers=$(cat /tmp/http2_headers 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        # Check if response contains expected JSON
        if echo "$response" | grep -q '"protocol":"HTTP/2"'; then
            log "✓ Status endpoint confirms HTTP/2 protocol"
            log "  Response: $response"
            
            # Check for HTTP/2 in headers
            if echo "$headers" | grep -q "HTTP/2"; then
                log "✓ HTTP/2 protocol confirmed in headers"
            else
                warn "HTTP/2 not detected in response headers"
            fi
            
            # Check for protocol header
            if echo "$headers" | grep -q "X-Protocol: HTTP/2"; then
                log "✓ X-Protocol header confirms HTTP/2"
            else
                warn "X-Protocol header not found or incorrect"
            fi
            
            return 0
        else
            error "✗ Status endpoint response doesn't confirm HTTP/2"
            error "  Response: $response"
            return 1
        fi
    else
        error "✗ Status endpoint check failed"
        return 1
    fi
}

# Main health check function
main() {
    log "Starting HTTP/2 server health check..."
    local exit_code=0
    
    # Run all checks
    check_nginx_process || exit_code=1
    check_port || exit_code=1
    check_ssl_certificate || exit_code=1
    check_health_endpoint || exit_code=1
    check_status_endpoint || exit_code=1
    
    # Cleanup
    rm -f /tmp/http2_headers
    
    if [ $exit_code -eq 0 ]; then
        log "✓ All HTTP/2 server health checks passed"
    else
        error "✗ Some HTTP/2 server health checks failed"
    fi
    
    return $exit_code
}

# Run main function
main "$@"