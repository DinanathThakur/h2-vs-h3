# HTTP/2 vs HTTP/3 Demo Scripts

This directory contains all the scripts needed to manage the HTTP/2 vs HTTP/3 demonstration environment.

## Quick Start

```bash
# Start the demo
./scripts/demo.sh start

# Check status
./scripts/demo.sh status

# View logs
./scripts/demo.sh logs

# Stop the demo
./scripts/demo.sh stop
```

## Main Scripts

### `demo.sh` - Main Management Script
The primary entry point for all demo operations.

```bash
./scripts/demo.sh <command> [options]
```

**Commands:**
- `start` - Start the demo
- `stop` - Stop the demo
- `restart` - Restart the demo
- `status` - Show status
- `logs` - Show logs
- `cleanup` - Clean up resources
- `configure` - Configure settings
- `debug` - Debug utilities
- `monitor` - Health monitoring

### `start-demo.sh` - Demo Startup
Starts the HTTP/2 vs HTTP/3 demo with comprehensive setup and validation.

**Features:**
- Prerequisites validation
- Port availability checking
- SSL certificate generation
- Container image management
- Health checks
- Startup logging

**Usage:**
```bash
./scripts/start-demo.sh [options]

Options:
  --http2-port PORT     HTTP/2 server port (default: 8443)
  --http3-port PORT     HTTP/3 server port (default: 8444)
  --build-mode MODE     Build mode: pull, build, rebuild
  --env ENV             Environment: development, staging, production
  --log-level LEVEL     Log level: debug, info, warn, error
  --force-rebuild       Force rebuild containers
  --skip-health-check   Skip health checks
  --detach              Run in background
```

### `stop-demo.sh` - Demo Shutdown
Gracefully stops all demo containers and services.

**Features:**
- Graceful container shutdown
- Configurable stop timeout
- Optional resource cleanup
- Port availability verification

**Usage:**
```bash
./scripts/stop-demo.sh [options]

Options:
  --timeout SECONDS     Stop timeout (default: 30)
  --force               Force stop containers
  --remove-volumes      Remove volumes
  --remove-images       Remove images
  --cleanup-all         Remove everything
```

### `cleanup-demo.sh` - Resource Cleanup
Comprehensive cleanup of all demo resources.

**Features:**
- Container removal
- Image cleanup
- Volume removal
- Network cleanup
- Certificate cleanup
- Log file cleanup
- Build artifact cleanup

**Usage:**
```bash
./scripts/cleanup-demo.sh [options]

Options:
  --force               Force cleanup without prompts
  --keep-logs           Keep log files
  --keep-certs          Keep SSL certificates
  --dry-run             Show what would be cleaned
  --nuclear             Complete system cleanup
```

### `configure-demo.sh` - Configuration Management
Interactive and programmatic configuration management.

**Features:**
- Interactive configuration mode
- Environment variable management
- Configuration validation
- Template generation
- Export capabilities

**Usage:**
```bash
./scripts/configure-demo.sh [options]

Options:
  --interactive         Interactive configuration
  --show                Show current configuration
  --reset               Reset to defaults
  --validate            Validate configuration
  --set KEY=VALUE       Set specific value
  --get KEY             Get specific value
  --export              Export as environment variables
```

### `debug-demo.sh` - Debug and Troubleshooting
Comprehensive debugging and troubleshooting utilities.

**Features:**
- Container log analysis
- Network connectivity testing
- SSL certificate validation
- Performance diagnostics
- System information collection
- Comprehensive troubleshooting

**Usage:**
```bash
./scripts/debug-demo.sh <command> [options]

Commands:
  logs                  Show container logs
  status                Show detailed status
  network               Network information
  certificates          SSL certificate info
  performance           Performance diagnostics
  troubleshoot          Comprehensive troubleshooting
  collect               Collect all debug info

Options:
  --lines NUMBER        Number of log lines
  --follow              Follow logs
  --debug-level LEVEL   Debug verbosity
  --output-file FILE    Save output to file
```

### `monitor.sh` - Health Monitoring
Continuous monitoring and health checking.

**Features:**
- Container health monitoring
- Port availability checking
- SSL certificate validation
- QUIC connectivity testing
- System resource monitoring
- Report generation

## Supporting Scripts

### `generate-certs.sh` - SSL Certificate Generation
Generates self-signed SSL certificates for the demo.

### `health-check-http2.sh` - HTTP/2 Health Check
Health check script for HTTP/2 containers.

### `health-check-http3.sh` - HTTP/3 Health Check
Health check script for HTTP/3 containers.

### `port-check.sh` - Port Availability Check
Verifies that required ports are available.

### `cert-validation.sh` - Certificate Validation
Validates SSL certificates and their configuration.

### `quic-connectivity-test.sh` - QUIC Testing
Tests QUIC/UDP connectivity for HTTP/3.

## Environment Variables

The scripts support various environment variables for configuration:

### Server Configuration
- `HTTP2_PORT` - HTTP/2 server port (default: 8443)
- `HTTP3_PORT` - HTTP/3 server port (default: 8444)
- `DEMO_ENV` - Environment: development, staging, production

### Build and Deployment
- `BUILD_MODE` - Container build mode: pull, build, rebuild
- `COMPOSE_FILE` - Docker compose file path
- `STOP_TIMEOUT` - Container stop timeout in seconds

### Logging and Debugging
- `LOG_LEVEL` - Logging level: debug, info, warn, error
- `LOG_DIR` - Custom log directory path

### Feature Flags
- `SKIP_HEALTH_CHECK` - Skip health checks (true/false)
- `FORCE_REBUILD` - Force rebuild containers (true/false)
- `KEEP_LOGS` - Keep logs during cleanup (true/false)
- `KEEP_CERTS` - Keep certificates during cleanup (true/false)

## Configuration File

Create a `.env` file in the project root to persist configuration:

```bash
# HTTP/2 vs HTTP/3 Demo Configuration
HTTP2_PORT=8443
HTTP3_PORT=8444
DEMO_ENV=development
LOG_LEVEL=info
BUILD_MODE=pull
SKIP_HEALTH_CHECK=false
FORCE_REBUILD=false
KEEP_LOGS=false
KEEP_CERTS=false
```

## Log Files

All scripts generate logs in `/tmp/h2-h3-demo-logs/`:

- `startup_TIMESTAMP.log` - Startup logs
- `stop_TIMESTAMP.log` - Stop operation logs
- `cleanup_TIMESTAMP.log` - Cleanup operation logs
- `debug_TIMESTAMP.log` - Debug session logs
- `monitor_TIMESTAMP.log` - Monitoring logs

## Troubleshooting

### Common Issues

1. **Port conflicts:**
   ```bash
   ./scripts/debug-demo.sh network
   ```

2. **Certificate issues:**
   ```bash
   ./scripts/debug-demo.sh certificates
   ```

3. **Container startup problems:**
   ```bash
   ./scripts/debug-demo.sh troubleshoot
   ```

4. **Performance issues:**
   ```bash
   ./scripts/debug-demo.sh performance
   ```

### Debug Information Collection

Collect comprehensive debug information:
```bash
./scripts/debug-demo.sh collect
```

This creates a detailed report with:
- System information
- Container status
- Network configuration
- Certificate details
- Performance metrics
- Configuration files
- Recent log files

## Examples

### Basic Usage
```bash
# Start with defaults
./scripts/demo.sh start

# Start with custom ports
./scripts/demo.sh start --http2-port 9443 --http3-port 9444

# Start with rebuild
./scripts/demo.sh start --build-mode rebuild --log-level debug
```

### Configuration
```bash
# Interactive configuration
./scripts/demo.sh configure --interactive

# Set specific values
./scripts/demo.sh configure --set HTTP2_PORT=9443
./scripts/demo.sh configure --set LOG_LEVEL=debug

# Show current configuration
./scripts/demo.sh configure --show
```

### Debugging
```bash
# Show container logs
./scripts/demo.sh logs --follow

# Run troubleshooting
./scripts/demo.sh debug troubleshoot

# Collect debug information
./scripts/demo.sh debug collect
```

### Cleanup
```bash
# Basic cleanup
./scripts/demo.sh cleanup

# Keep certificates and logs
./scripts/demo.sh cleanup --keep-certs --keep-logs

# Complete cleanup
./scripts/demo.sh cleanup --nuclear --force
```

## Script Dependencies

### Required Tools
- Docker
- Docker Compose
- bash (4.0+)
- Basic Unix tools (curl, netstat, openssl, etc.)

### Optional Tools
- nc (netcat) - for connectivity testing
- lsof - for port analysis
- bc - for calculations

## Security Considerations

- Scripts generate self-signed certificates for development
- Default ports (8443, 8444) may conflict with other services
- Log files may contain sensitive information
- Nuclear cleanup removes all Docker resources

## Contributing

When modifying scripts:

1. Maintain consistent error handling
2. Add appropriate logging
3. Update help text and documentation
4. Test with different environments
5. Follow the established coding style

## License

These scripts are part of the HTTP/2 vs HTTP/3 demo project.