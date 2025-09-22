#!/bin/bash

# HTTP/2 vs HTTP/3 Demo Configuration Script
# This script helps configure environment variables and settings

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_ROOT/.env"
CONFIG_TEMPLATE="$PROJECT_ROOT/.env.template"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

prompt() {
    echo -e "${CYAN}$1${NC}"
}

# Configuration variables with defaults
declare -A CONFIG_VARS=(
    ["HTTP2_PORT"]="8443"
    ["HTTP3_PORT"]="8444"
    ["DEMO_ENV"]="development"
    ["LOG_LEVEL"]="info"
    ["BUILD_MODE"]="pull"
    ["STOP_TIMEOUT"]="30"
    ["SKIP_HEALTH_CHECK"]="false"
    ["FORCE_REBUILD"]="false"
    ["KEEP_LOGS"]="false"
    ["KEEP_CERTS"]="false"
    ["COMPOSE_FILE"]="docker-compose.yml"
)

declare -A CONFIG_DESCRIPTIONS=(
    ["HTTP2_PORT"]="Port for HTTP/2 server (HTTPS)"
    ["HTTP3_PORT"]="Port for HTTP/3 server (HTTPS + QUIC/UDP)"
    ["DEMO_ENV"]="Demo environment (development, staging, production)"
    ["LOG_LEVEL"]="Logging level (debug, info, warn, error)"
    ["BUILD_MODE"]="Container build mode (pull, build, rebuild)"
    ["STOP_TIMEOUT"]="Container stop timeout in seconds"
    ["SKIP_HEALTH_CHECK"]="Skip health checks after startup (true/false)"
    ["FORCE_REBUILD"]="Force rebuild containers on startup (true/false)"
    ["KEEP_LOGS"]="Keep log files during cleanup (true/false)"
    ["KEEP_CERTS"]="Keep SSL certificates during cleanup (true/false)"
    ["COMPOSE_FILE"]="Docker compose file to use"
)

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

HTTP/2 vs HTTP/3 Demo Configuration Script

This script helps configure environment variables and settings for the demo.

OPTIONS:
    -h, --help              Show this help message
    -i, --interactive       Interactive configuration mode
    -s, --show              Show current configuration
    -r, --reset             Reset to default configuration
    -v, --validate          Validate current configuration
    --set KEY=VALUE         Set a specific configuration value
    --get KEY               Get a specific configuration value
    --export                Export configuration as environment variables
    --template              Create configuration template

CONFIGURATION VARIABLES:
    HTTP2_PORT              HTTP/2 server port (default: 8443)
    HTTP3_PORT              HTTP/3 server port (default: 8444)
    DEMO_ENV                Environment: development, staging, production
    LOG_LEVEL               Logging: debug, info, warn, error
    BUILD_MODE              Build mode: pull, build, rebuild
    STOP_TIMEOUT            Container stop timeout in seconds
    SKIP_HEALTH_CHECK       Skip health checks (true/false)
    FORCE_REBUILD           Force rebuild containers (true/false)
    KEEP_LOGS               Keep logs during cleanup (true/false)
    KEEP_CERTS              Keep certificates during cleanup (true/false)
    COMPOSE_FILE            Docker compose file path

EXAMPLES:
    $0 --interactive        # Interactive configuration
    $0 --show               # Show current settings
    $0 --set HTTP2_PORT=9443 # Set HTTP/2 port
    $0 --get LOG_LEVEL      # Get current log level
    $0 --export             # Export as environment variables
    $0 --reset              # Reset to defaults

EOF
}

# Load existing configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        info "Loading configuration from $CONFIG_FILE"
        
        # Source the config file to load variables
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ $key =~ ^[[:space:]]*# ]] && continue
            [[ -z $key ]] && continue
            
            # Remove quotes from value
            value=$(echo "$value" | sed 's/^["'\'']//' | sed 's/["'\'']$//')
            
            # Store in CONFIG_VARS if it's a known variable
            if [[ -n ${CONFIG_VARS[$key]} ]] || [[ -n ${CONFIG_DESCRIPTIONS[$key]} ]]; then
                CONFIG_VARS[$key]="$value"
            fi
        done < "$CONFIG_FILE"
        
        log "✓ Configuration loaded"
    else
        info "No existing configuration file found, using defaults"
    fi
}

# Save configuration to file
save_config() {
    info "Saving configuration to $CONFIG_FILE"
    
    cat > "$CONFIG_FILE" << EOF
# HTTP/2 vs HTTP/3 Demo Configuration
# Generated on $(date)

# Server Ports
HTTP2_PORT=${CONFIG_VARS[HTTP2_PORT]}
HTTP3_PORT=${CONFIG_VARS[HTTP3_PORT]}

# Environment Settings
DEMO_ENV=${CONFIG_VARS[DEMO_ENV]}
LOG_LEVEL=${CONFIG_VARS[LOG_LEVEL]}

# Build and Deployment
BUILD_MODE=${CONFIG_VARS[BUILD_MODE]}
COMPOSE_FILE=${CONFIG_VARS[COMPOSE_FILE]}
STOP_TIMEOUT=${CONFIG_VARS[STOP_TIMEOUT]}

# Feature Flags
SKIP_HEALTH_CHECK=${CONFIG_VARS[SKIP_HEALTH_CHECK]}
FORCE_REBUILD=${CONFIG_VARS[FORCE_REBUILD]}

# Cleanup Options
KEEP_LOGS=${CONFIG_VARS[KEEP_LOGS]}
KEEP_CERTS=${CONFIG_VARS[KEEP_CERTS]}

# Additional environment variables can be added here
# LOG_DIR=/tmp/h2-h3-demo-logs
# DOCKER_BUILDKIT=1

EOF
    
    log "✓ Configuration saved to $CONFIG_FILE"
}

# Show current configuration
show_config() {
    info "Current Configuration:"
    echo
    
    for key in "${!CONFIG_VARS[@]}"; do
        local value="${CONFIG_VARS[$key]}"
        local description="${CONFIG_DESCRIPTIONS[$key]}"
        
        printf "  %-20s = %-15s # %s\n" "$key" "$value" "$description"
    done
    
    echo
    info "Configuration file: $CONFIG_FILE"
    
    if [ -f "$CONFIG_FILE" ]; then
        info "Last modified: $(stat -c %y "$CONFIG_FILE" 2>/dev/null || stat -f %Sm "$CONFIG_FILE" 2>/dev/null || echo "unknown")"
    else
        warn "Configuration file does not exist"
    fi
}

# Interactive configuration
interactive_config() {
    info "Interactive Configuration Mode"
    echo
    
    for key in "${!CONFIG_VARS[@]}"; do
        local current_value="${CONFIG_VARS[$key]}"
        local description="${CONFIG_DESCRIPTIONS[$key]}"
        
        prompt "$description"
        prompt "Current value: $current_value"
        
        read -p "New value (press Enter to keep current): " new_value
        
        if [ -n "$new_value" ]; then
            CONFIG_VARS[$key]="$new_value"
            log "✓ Set $key = $new_value"
        else
            info "Keeping current value: $current_value"
        fi
        
        echo
    done
    
    prompt "Save configuration? (y/N): "
    read -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        save_config
    else
        info "Configuration not saved"
    fi
}

# Validate configuration
validate_config() {
    info "Validating configuration..."
    local errors=0
    
    # Validate ports
    for port_var in "HTTP2_PORT" "HTTP3_PORT"; do
        local port="${CONFIG_VARS[$port_var]}"
        
        if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1024 ] || [ "$port" -gt 65535 ]; then
            error "Invalid $port_var: $port (must be 1024-65535)"
            errors=$((errors + 1))
        fi
    done
    
    # Check for port conflicts
    if [ "${CONFIG_VARS[HTTP2_PORT]}" = "${CONFIG_VARS[HTTP3_PORT]}" ]; then
        error "HTTP2_PORT and HTTP3_PORT cannot be the same"
        errors=$((errors + 1))
    fi
    
    # Validate environment
    local env="${CONFIG_VARS[DEMO_ENV]}"
    if [[ ! "$env" =~ ^(development|staging|production)$ ]]; then
        error "Invalid DEMO_ENV: $env (must be development, staging, or production)"
        errors=$((errors + 1))
    fi
    
    # Validate log level
    local log_level="${CONFIG_VARS[LOG_LEVEL]}"
    if [[ ! "$log_level" =~ ^(debug|info|warn|error)$ ]]; then
        error "Invalid LOG_LEVEL: $log_level (must be debug, info, warn, or error)"
        errors=$((errors + 1))
    fi
    
    # Validate build mode
    local build_mode="${CONFIG_VARS[BUILD_MODE]}"
    if [[ ! "$build_mode" =~ ^(pull|build|rebuild)$ ]]; then
        error "Invalid BUILD_MODE: $build_mode (must be pull, build, or rebuild)"
        errors=$((errors + 1))
    fi
    
    # Validate boolean values
    for bool_var in "SKIP_HEALTH_CHECK" "FORCE_REBUILD" "KEEP_LOGS" "KEEP_CERTS"; do
        local value="${CONFIG_VARS[$bool_var]}"
        if [[ ! "$value" =~ ^(true|false)$ ]]; then
            error "Invalid $bool_var: $value (must be true or false)"
            errors=$((errors + 1))
        fi
    done
    
    # Validate timeout
    local timeout="${CONFIG_VARS[STOP_TIMEOUT]}"
    if ! [[ "$timeout" =~ ^[0-9]+$ ]] || [ "$timeout" -lt 1 ] || [ "$timeout" -gt 300 ]; then
        error "Invalid STOP_TIMEOUT: $timeout (must be 1-300 seconds)"
        errors=$((errors + 1))
    fi
    
    # Validate compose file
    local compose_file="${CONFIG_VARS[COMPOSE_FILE]}"
    if [ ! -f "$PROJECT_ROOT/$compose_file" ]; then
        error "Compose file not found: $PROJECT_ROOT/$compose_file"
        errors=$((errors + 1))
    fi
    
    if [ $errors -eq 0 ]; then
        log "✓ Configuration is valid"
        return 0
    else
        error "✗ Configuration has $errors error(s)"
        return 1
    fi
}

# Reset to default configuration
reset_config() {
    warn "Resetting configuration to defaults..."
    
    # Reset all values to defaults
    CONFIG_VARS=(
        ["HTTP2_PORT"]="8443"
        ["HTTP3_PORT"]="8444"
        ["DEMO_ENV"]="development"
        ["LOG_LEVEL"]="info"
        ["BUILD_MODE"]="pull"
        ["STOP_TIMEOUT"]="30"
        ["SKIP_HEALTH_CHECK"]="false"
        ["FORCE_REBUILD"]="false"
        ["KEEP_LOGS"]="false"
        ["KEEP_CERTS"]="false"
        ["COMPOSE_FILE"]="docker-compose.yml"
    )
    
    save_config
    log "✓ Configuration reset to defaults"
}

# Set a specific configuration value
set_config_value() {
    local key_value="$1"
    local key="${key_value%%=*}"
    local value="${key_value#*=}"
    
    if [ "$key" = "$key_value" ]; then
        error "Invalid format. Use KEY=VALUE"
        return 1
    fi
    
    if [[ -z ${CONFIG_DESCRIPTIONS[$key]} ]]; then
        error "Unknown configuration key: $key"
        return 1
    fi
    
    CONFIG_VARS[$key]="$value"
    log "Set $key = $value"
    
    save_config
}

# Get a specific configuration value
get_config_value() {
    local key="$1"
    
    if [[ -z ${CONFIG_VARS[$key]} ]]; then
        error "Unknown configuration key: $key"
        return 1
    fi
    
    echo "${CONFIG_VARS[$key]}"
}

# Export configuration as environment variables
export_config() {
    info "Exporting configuration as environment variables:"
    echo
    
    for key in "${!CONFIG_VARS[@]}"; do
        local value="${CONFIG_VARS[$key]}"
        echo "export $key=\"$value\""
    done
    
    echo
    info "To use these variables in your shell, run:"
    info "  source <($0 --export)"
}

# Create configuration template
create_template() {
    info "Creating configuration template at $CONFIG_TEMPLATE"
    
    cat > "$CONFIG_TEMPLATE" << EOF
# HTTP/2 vs HTTP/3 Demo Configuration Template
# Copy this file to .env and modify as needed

# Server Ports
# HTTP2_PORT=8443
# HTTP3_PORT=8444

# Environment Settings
# DEMO_ENV=development          # development, staging, production
# LOG_LEVEL=info               # debug, info, warn, error

# Build and Deployment
# BUILD_MODE=pull              # pull, build, rebuild
# COMPOSE_FILE=docker-compose.yml
# STOP_TIMEOUT=30

# Feature Flags
# SKIP_HEALTH_CHECK=false      # Skip health checks after startup
# FORCE_REBUILD=false          # Force rebuild containers

# Cleanup Options
# KEEP_LOGS=false              # Keep log files during cleanup
# KEEP_CERTS=false             # Keep SSL certificates during cleanup

# Additional Options
# LOG_DIR=/tmp/h2-h3-demo-logs # Custom log directory
# DOCKER_BUILDKIT=1            # Enable Docker BuildKit

EOF
    
    log "✓ Configuration template created at $CONFIG_TEMPLATE"
}

# Parse command line arguments
parse_arguments() {
    if [ $# -eq 0 ]; then
        show_config
        return 0
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -i|--interactive)
                interactive_config
                exit 0
                ;;
            -s|--show)
                show_config
                exit 0
                ;;
            -r|--reset)
                reset_config
                exit 0
                ;;
            -v|--validate)
                validate_config
                exit $?
                ;;
            --set)
                set_config_value "$2"
                shift 2
                ;;
            --get)
                get_config_value "$2"
                shift 2
                ;;
            --export)
                export_config
                exit 0
                ;;
            --template)
                create_template
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    log "HTTP/2 vs HTTP/3 Demo Configuration"
    
    # Load existing configuration
    load_config
    
    # Parse arguments
    parse_arguments "$@"
}

# Run main function
main "$@"