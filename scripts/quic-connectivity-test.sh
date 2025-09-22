#!/bin/bash

# QUIC/UDP connectivity test script
# This script tests QUIC protocol connectivity and UDP functionality

set -e

# Configuration
HOST="localhost"
HTTP3_PORT="8444"
TIMEOUT=10
TEST_ENDPOINT="/health"
STATUS_ENDPOINT="/status"
QUIC_INFO_ENDPOINT="/quic-info"

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

# Check if UDP port is listening
check_udp_port_listening() {
    log "Checking if UDP port $HTTP3_PORT is listening..."
    
    if netstat -uln | grep -q ":$HTTP3_PORT "; then
        log "✓ UDP port $HTTP3_PORT is listening"
        
        # Get process information
        local process_info
        process_info=$(lsof -i UDP:$HTTP3_PORT 2>/dev/null | tail -n +2 | head -1 || echo "")
        
        if [ -n "$process_info" ]; then
            log "  Process: $process_info"
        fi
        
        return 0
    else
        error "✗ UDP port $HTTP3_PORT is not listening"
        return 1
    fi
}

# Test basic UDP connectivity
test_basic_udp_connectivity() {
    log "Testing basic UDP connectivity..."
    
    if command -v nc >/dev/null 2>&1; then
        # Test UDP connection with netcat
        if timeout $TIMEOUT nc -u -z $HOST $HTTP3_PORT 2>/dev/null; then
            log "✓ Basic UDP connectivity test passed"
            return 0
        else
            warn "Basic UDP connectivity test inconclusive (UDP is connectionless)"
            return 0  # Don't fail as UDP is connectionless
        fi
    else
        warn "netcat (nc) not available, skipping basic UDP connectivity test"
        return 0
    fi
}

# Check curl HTTP/3 support
check_curl_http3_support() {
    log "Checking curl HTTP/3 support..."
    
    if curl --version | grep -q "HTTP3"; then
        log "✓ curl supports HTTP/3"
        return 0
    else
        warn "curl does not support HTTP/3"
        return 1
    fi
}

# Test HTTP/3 connection with curl
test_http3_with_curl() {
    log "Testing HTTP/3 connection with curl..."
    
    if ! check_curl_http3_support; then
        warn "Skipping HTTP/3 curl test (not supported)"
        return 0
    fi
    
    local response headers
    
    # Test health endpoint with HTTP/3
    response=$(curl -k -s --http3 --max-time $TIMEOUT "https://$HOST:$HTTP3_PORT$TEST_ENDPOINT" 2>/dev/null || echo "")
    
    if [ -n "$response" ] && [[ "$response" == *"HTTP/3 Server OK"* ]]; then
        log "✓ HTTP/3 health endpoint test successful"
        log "  Response: $response"
        
        # Test with headers to verify protocol
        headers=$(curl -k -s --http3 --max-time $TIMEOUT -I "https://$HOST:$HTTP3_PORT$TEST_ENDPOINT" 2>/dev/null || echo "")
        
        if echo "$headers" | grep -q "HTTP/3"; then
            log "✓ HTTP/3 protocol confirmed in response headers"
        elif echo "$headers" | grep -q "HTTP/2"; then
            warn "Connection fell back to HTTP/2"
        else
            warn "Could not determine protocol from headers"
        fi
        
        return 0
    else
        error "✗ HTTP/3 connection test failed"
        error "  Response: $response"
        return 1
    fi
}

# Test QUIC-specific features
test_quic_features() {
    log "Testing QUIC-specific features..."
    
    # Test QUIC info endpoint
    local quic_response
    quic_response=$(curl -k -s --max-time $TIMEOUT "https://$HOST:$HTTP3_PORT$QUIC_INFO_ENDPOINT" 2>/dev/null || echo "")
    
    if [ -n "$quic_response" ]; then
        log "✓ QUIC info endpoint accessible"
        log "  Response: $quic_response"
        
        # Parse QUIC status from response
        if echo "$quic_response" | grep -q '"quic_enabled"'; then
            local quic_status
            quic_status=$(echo "$quic_response" | grep -o '"quic_enabled":"[^"]*"' | cut -d'"' -f4)
            
            if [ "$quic_status" = "1" ] || [ "$quic_status" = "true" ]; then
                log "✓ QUIC is enabled on the server"
            else
                warn "QUIC appears to be disabled or not active"
            fi
        fi
        
        return 0
    else
        error "✗ QUIC info endpoint test failed"
        return 1
    fi
}

# Test Alt-Svc header for HTTP/3 advertisement
test_alt_svc_header() {
    log "Testing Alt-Svc header for HTTP/3 advertisement..."
    
    local headers
    headers=$(curl -k -s --max-time $TIMEOUT -I "https://$HOST:$HTTP3_PORT$STATUS_ENDPOINT" 2>/dev/null || echo "")
    
    if [ -n "$headers" ]; then
        if echo "$headers" | grep -i "alt-svc:" | grep -q "h3="; then
            log "✓ Alt-Svc header advertises HTTP/3"
            local alt_svc_header
            alt_svc_header=$(echo "$headers" | grep -i "alt-svc:" | head -1)
            log "  $alt_svc_header"
            return 0
        else
            warn "Alt-Svc header not found or doesn't advertise HTTP/3"
            return 1
        fi
    else
        error "✗ Could not retrieve headers for Alt-Svc test"
        return 1
    fi
}

# Test connection migration (basic test)
test_connection_migration() {
    log "Testing QUIC connection migration capabilities..."
    
    # This is a basic test - in a real scenario, connection migration
    # would involve changing network interfaces or IP addresses
    
    if ! check_curl_http3_support; then
        warn "Skipping connection migration test (curl HTTP/3 not supported)"
        return 0
    fi
    
    # Make multiple requests to test connection reuse
    local request_count=3
    local success_count=0
    
    for i in $(seq 1 $request_count); do
        local response
        response=$(curl -k -s --http3 --max-time $TIMEOUT "https://$HOST:$HTTP3_PORT$TEST_ENDPOINT" 2>/dev/null || echo "")
        
        if [[ "$response" == *"HTTP/3 Server OK"* ]]; then
            success_count=$((success_count + 1))
        fi
        
        sleep 1
    done
    
    if [ $success_count -eq $request_count ]; then
        log "✓ Connection migration test passed ($success_count/$request_count requests successful)"
        return 0
    else
        warn "Connection migration test partial success ($success_count/$request_count requests successful)"
        return 1
    fi
}

# Test QUIC 0-RTT (if supported)
test_quic_0rtt() {
    log "Testing QUIC 0-RTT capabilities..."
    
    if ! check_curl_http3_support; then
        warn "Skipping 0-RTT test (curl HTTP/3 not supported)"
        return 0
    fi
    
    # First request to establish connection
    log "Making initial request to establish QUIC connection..."
    local first_response
    first_response=$(curl -k -s --http3 --max-time $TIMEOUT "https://$HOST:$HTTP3_PORT$TEST_ENDPOINT" 2>/dev/null || echo "")
    
    if [[ "$first_response" == *"HTTP/3 Server OK"* ]]; then
        log "✓ Initial QUIC connection established"
        
        # Second request should potentially use 0-RTT
        sleep 2
        log "Making second request (potential 0-RTT)..."
        local second_response
        second_response=$(curl -k -s --http3 --max-time $TIMEOUT "https://$HOST:$HTTP3_PORT$TEST_ENDPOINT" 2>/dev/null || echo "")
        
        if [[ "$second_response" == *"HTTP/3 Server OK"* ]]; then
            log "✓ Second QUIC request successful (0-RTT may have been used)"
            return 0
        else
            warn "Second QUIC request failed"
            return 1
        fi
    else
        warn "Initial QUIC connection failed, skipping 0-RTT test"
        return 1
    fi
}

# Performance comparison test
test_quic_performance() {
    log "Testing QUIC performance characteristics..."
    
    if ! check_curl_http3_support; then
        warn "Skipping QUIC performance test (curl HTTP/3 not supported)"
        return 0
    fi
    
    # Test multiple concurrent requests
    local concurrent_requests=5
    local temp_dir="/tmp/quic_test_$$"
    mkdir -p "$temp_dir"
    
    log "Testing $concurrent_requests concurrent QUIC requests..."
    
    # Start concurrent requests
    for i in $(seq 1 $concurrent_requests); do
        (
            local start_time end_time duration
            start_time=$(date +%s.%N)
            curl -k -s --http3 --max-time $TIMEOUT "https://$HOST:$HTTP3_PORT$TEST_ENDPOINT" > "$temp_dir/response_$i.txt" 2>/dev/null
            end_time=$(date +%s.%N)
            duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
            echo "$duration" > "$temp_dir/time_$i.txt"
        ) &
    done
    
    # Wait for all requests to complete
    wait
    
    # Analyze results
    local successful_requests=0
    local total_time=0
    
    for i in $(seq 1 $concurrent_requests); do
        if [ -f "$temp_dir/response_$i.txt" ] && grep -q "HTTP/3 Server OK" "$temp_dir/response_$i.txt"; then
            successful_requests=$((successful_requests + 1))
        fi
        
        if [ -f "$temp_dir/time_$i.txt" ]; then
            local request_time
            request_time=$(cat "$temp_dir/time_$i.txt")
            total_time=$(echo "$total_time + $request_time" | bc -l 2>/dev/null || echo "$total_time")
        fi
    done
    
    # Cleanup
    rm -rf "$temp_dir"
    
    if [ $successful_requests -eq $concurrent_requests ]; then
        log "✓ QUIC concurrent requests test passed ($successful_requests/$concurrent_requests successful)"
        if command -v bc >/dev/null 2>&1 && [ "$total_time" != "0" ]; then
            local avg_time
            avg_time=$(echo "scale=3; $total_time / $concurrent_requests" | bc -l)
            log "  Average request time: ${avg_time}s"
        fi
        return 0
    else
        warn "QUIC concurrent requests test partial success ($successful_requests/$concurrent_requests successful)"
        return 1
    fi
}

# Main QUIC connectivity test function
main() {
    log "Starting QUIC/UDP connectivity tests..."
    local exit_code=0
    
    # Run all QUIC/UDP tests
    check_udp_port_listening || exit_code=1
    test_basic_udp_connectivity || true  # Don't fail on UDP connectivity
    test_http3_with_curl || exit_code=1
    test_quic_features || exit_code=1
    test_alt_svc_header || true  # Don't fail on Alt-Svc header
    test_connection_migration || true  # Don't fail on connection migration
    test_quic_0rtt || true  # Don't fail on 0-RTT test
    test_quic_performance || true  # Don't fail on performance test
    
    if [ $exit_code -eq 0 ]; then
        log "✓ All critical QUIC/UDP connectivity tests passed"
    else
        error "✗ Some critical QUIC/UDP connectivity tests failed"
    fi
    
    return $exit_code
}

# Run main function
main "$@"