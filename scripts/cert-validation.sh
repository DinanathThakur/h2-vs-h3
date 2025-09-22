#!/bin/bash

# SSL certificate validation script
# This script validates SSL certificates used by the HTTP/2 and HTTP/3 servers

set -e

# Configuration
CERT_DIR="./certs"
CERT_FILE="$CERT_DIR/server.crt"
KEY_FILE="$CERT_DIR/server.key"
HTTP2_HOST="localhost"
HTTP2_PORT="8443"
HTTP3_HOST="localhost"
HTTP3_PORT="8444"
MIN_DAYS_VALID=7

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

# Check if certificate files exist
check_cert_files_exist() {
    log "Checking if certificate files exist..."
    
    if [ -f "$CERT_FILE" ]; then
        log "✓ Certificate file exists: $CERT_FILE"
    else
        error "✗ Certificate file not found: $CERT_FILE"
        return 1
    fi
    
    if [ -f "$KEY_FILE" ]; then
        log "✓ Private key file exists: $KEY_FILE"
    else
        error "✗ Private key file not found: $KEY_FILE"
        return 1
    fi
    
    return 0
}

# Check certificate file permissions
check_cert_permissions() {
    log "Checking certificate file permissions..."
    
    # Check certificate file permissions (should be readable)
    local cert_perms
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS stat command
        cert_perms=$(stat -f "%A" "$CERT_FILE" 2>/dev/null)
    else
        # Linux stat command
        cert_perms=$(stat -c "%a" "$CERT_FILE" 2>/dev/null)
    fi
    
    if [ "$cert_perms" = "644" ] || [ "$cert_perms" = "444" ] || [ "$cert_perms" = "600" ]; then
        log "✓ Certificate file has appropriate permissions: $cert_perms"
    else
        warn "Certificate file permissions may be too permissive: $cert_perms"
    fi
    
    # Check private key file permissions (should be restrictive)
    local key_perms
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS stat command
        key_perms=$(stat -f "%A" "$KEY_FILE" 2>/dev/null)
    else
        # Linux stat command
        key_perms=$(stat -c "%a" "$KEY_FILE" 2>/dev/null)
    fi
    
    if [ "$key_perms" = "600" ] || [ "$key_perms" = "400" ]; then
        log "✓ Private key file has secure permissions: $key_perms"
    else
        error "✗ Private key file has insecure permissions: $key_perms (should be 600 or 400)"
        return 1
    fi
    
    return 0
}

# Validate certificate content and properties
validate_certificate_content() {
    log "Validating certificate content..."
    
    # Check if certificate is valid
    if ! openssl x509 -in "$CERT_FILE" -noout -text >/dev/null 2>&1; then
        error "✗ Certificate file is not a valid X.509 certificate"
        return 1
    fi
    
    log "✓ Certificate file is a valid X.509 certificate"
    
    # Get certificate details
    local cert_subject cert_issuer cert_serial cert_not_before cert_not_after
    cert_subject=$(openssl x509 -in "$CERT_FILE" -noout -subject | sed 's/subject=//')
    cert_issuer=$(openssl x509 -in "$CERT_FILE" -noout -issuer | sed 's/issuer=//')
    cert_serial=$(openssl x509 -in "$CERT_FILE" -noout -serial | sed 's/serial=//')
    cert_not_before=$(openssl x509 -in "$CERT_FILE" -noout -startdate | sed 's/notBefore=//')
    cert_not_after=$(openssl x509 -in "$CERT_FILE" -noout -enddate | sed 's/notAfter=//')
    
    log "Certificate details:"
    log "  Subject: $cert_subject"
    log "  Issuer: $cert_issuer"
    log "  Serial: $cert_serial"
    log "  Valid from: $cert_not_before"
    log "  Valid until: $cert_not_after"
    
    return 0
}

# Check certificate expiration
check_certificate_expiration() {
    log "Checking certificate expiration..."
    
    # Get expiration date string
    local exp_date_str
    exp_date_str=$(openssl x509 -in "$CERT_FILE" -noout -enddate | sed 's/notAfter=//')
    
    # Convert to epoch time (macOS compatible)
    local exp_date_epoch
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS date command
        exp_date_epoch=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$exp_date_str" +%s 2>/dev/null)
    else
        # Linux date command
        exp_date_epoch=$(date -d "$exp_date_str" +%s 2>/dev/null)
    fi
    
    # Fallback if date parsing fails
    if [ -z "$exp_date_epoch" ] || [ "$exp_date_epoch" = "" ]; then
        warn "Could not parse certificate expiration date: $exp_date_str"
        return 0
    fi
    
    # Get current date in seconds since epoch
    local current_date_epoch
    current_date_epoch=$(date +%s)
    
    # Calculate days until expiration
    local days_until_exp
    days_until_exp=$(( (exp_date_epoch - current_date_epoch) / 86400 ))
    
    if [ $days_until_exp -lt 0 ]; then
        error "✗ Certificate has expired $((days_until_exp * -1)) days ago"
        return 1
    elif [ $days_until_exp -lt $MIN_DAYS_VALID ]; then
        warn "Certificate expires in $days_until_exp days (less than $MIN_DAYS_VALID days)"
        return 1
    else
        log "✓ Certificate is valid for $days_until_exp more days"
    fi
    
    return 0
}

# Validate private key
validate_private_key() {
    log "Validating private key..."
    
    # Check if private key is valid
    if ! openssl rsa -in "$KEY_FILE" -check -noout >/dev/null 2>&1; then
        error "✗ Private key file is not a valid RSA private key"
        return 1
    fi
    
    log "✓ Private key file is a valid RSA private key"
    
    # Get key size
    local key_size
    key_size=$(openssl rsa -in "$KEY_FILE" -text -noout 2>/dev/null | grep "Private-Key:" | grep -o '[0-9]\+')
    
    if [ "$key_size" -ge 2048 ]; then
        log "✓ Private key size is adequate: $key_size bits"
    else
        warn "Private key size may be too small: $key_size bits (recommended: 2048+ bits)"
    fi
    
    return 0
}

# Check certificate and key match
check_cert_key_match() {
    log "Checking if certificate and private key match..."
    
    # Get certificate public key hash
    local cert_hash
    cert_hash=$(openssl x509 -in "$CERT_FILE" -pubkey -noout | openssl rsa -pubin -outform DER 2>/dev/null | openssl dgst -sha256 -hex | cut -d' ' -f2)
    
    # Get private key public key hash
    local key_hash
    key_hash=$(openssl rsa -in "$KEY_FILE" -pubout -outform DER 2>/dev/null | openssl dgst -sha256 -hex | cut -d' ' -f2)
    
    if [ "$cert_hash" = "$key_hash" ]; then
        log "✓ Certificate and private key match"
        return 0
    else
        error "✗ Certificate and private key do not match"
        error "  Certificate hash: $cert_hash"
        error "  Private key hash: $key_hash"
        return 1
    fi
}

# Check certificate Subject Alternative Names (SAN)
check_certificate_san() {
    log "Checking certificate Subject Alternative Names..."
    
    local san_info
    san_info=$(openssl x509 -in "$CERT_FILE" -text -noout | grep -A1 "Subject Alternative Name" | tail -1 | sed 's/^[[:space:]]*//' || echo "")
    
    if [ -n "$san_info" ]; then
        log "✓ Certificate has Subject Alternative Names: $san_info"
        
        # Check if localhost and 127.0.0.1 are included
        if echo "$san_info" | grep -q "localhost"; then
            log "✓ Certificate includes localhost in SAN"
        else
            warn "Certificate does not include localhost in SAN"
        fi
        
        if echo "$san_info" | grep -q "127.0.0.1"; then
            log "✓ Certificate includes 127.0.0.1 in SAN"
        else
            warn "Certificate does not include 127.0.0.1 in SAN"
        fi
    else
        warn "Certificate does not have Subject Alternative Names"
    fi
    
    return 0
}

# Test certificate with servers
test_certificate_with_servers() {
    log "Testing certificate with running servers..."
    
    # Test HTTP/2 server
    log "Testing certificate with HTTP/2 server..."
    local http2_cert_info
    http2_cert_info=$(echo | openssl s_client -connect $HTTP2_HOST:$HTTP2_PORT -servername $HTTP2_HOST 2>/dev/null | openssl x509 -noout -fingerprint 2>/dev/null || echo "")
    
    if [ -n "$http2_cert_info" ]; then
        log "✓ HTTP/2 server certificate connection successful"
        log "  $http2_cert_info"
    else
        warn "Could not connect to HTTP/2 server for certificate test (server may not be running)"
    fi
    
    # Test HTTP/3 server
    log "Testing certificate with HTTP/3 server..."
    local http3_cert_info
    http3_cert_info=$(echo | openssl s_client -connect $HTTP3_HOST:$HTTP3_PORT -servername $HTTP3_HOST 2>/dev/null | openssl x509 -noout -fingerprint 2>/dev/null || echo "")
    
    if [ -n "$http3_cert_info" ]; then
        log "✓ HTTP/3 server certificate connection successful"
        log "  $http3_cert_info"
    else
        warn "Could not connect to HTTP/3 server for certificate test (server may not be running)"
    fi
    
    return 0
}

# Main certificate validation function
main() {
    log "Starting SSL certificate validation..."
    local exit_code=0
    
    # Run all validation checks
    check_cert_files_exist || exit_code=1
    check_cert_permissions || exit_code=1
    validate_certificate_content || exit_code=1
    check_certificate_expiration || exit_code=1
    validate_private_key || exit_code=1
    check_cert_key_match || exit_code=1
    check_certificate_san || true  # Don't fail on SAN warnings
    test_certificate_with_servers || true  # Don't fail if servers aren't running
    
    if [ $exit_code -eq 0 ]; then
        log "✓ All SSL certificate validation checks passed"
    else
        error "✗ Some SSL certificate validation checks failed"
    fi
    
    return $exit_code
}

# Run main function
main "$@"