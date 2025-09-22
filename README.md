# HTTP/2 vs HTTP/3 Performance Demo

A comprehensive, containerized demonstration application showcasing the performance and behavioral differences between HTTP/2 and HTTP/3 protocols. This interactive demo provides real-time performance comparisons, educational content, and cross-browser compatibility features.

## 🚀 Quick Start

### Prerequisites
- Docker and Docker Compose
- Modern web browser (Chrome 87+, Firefox 88+, Edge 87+ recommended)
- Available ports: 8443 (HTTP/2) and 8444 (HTTP/3)

### Start the Demo
```bash
# Simple start
./scripts/demo.sh start

# Or with Docker Compose directly
docker-compose up --build
```

### Access the Demo
- **Main Demo Interface**: https://localhost:8443 or https://localhost:8444
- **HTTP/2 Server**: https://localhost:8443
- **HTTP/3 Server**: https://localhost:8444

### Stop the Demo
```bash
./scripts/demo.sh stop
```

## 📋 Table of Contents

- [Features](#-features)
- [Project Structure](#-project-structure)
- [Installation & Setup](#-installation--setup)
- [Usage Guide](#-usage-guide)
- [Testing & Validation](#-testing--validation)
- [Browser Compatibility](#-browser-compatibility)
- [Educational Content](#-educational-content)
- [Scripts & Automation](#-scripts--automation)
- [Configuration](#-configuration)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)

## ✨ Features

### Core Functionality
- **Real-time Performance Comparison** - Side-by-side HTTP/2 vs HTTP/3 performance testing
- **Multiple Test Scenarios** - Basic page loads, image-heavy content, mixed resources, network simulation
- **Interactive Metrics** - Load time, connection time, TTFB, resource count, and total size
- **Statistical Analysis** - Multiple test runs with averages, min/max, and standard deviation
- **Export/Import Results** - Save and share performance test results

### Cross-Browser Compatibility
- **Automatic Browser Detection** - Identifies browser type and version
- **HTTP/3 Support Detection** - Detects full, limited, or no HTTP/3 support
- **Graceful Fallback** - Automatic fallback to HTTP/2 when HTTP/3 is unavailable
- **User Notifications** - Browser-specific instructions and compatibility warnings
- **Protocol-Specific UI** - Visual indicators for different support levels

### Educational Content
- **Protocol Comparison** - Detailed explanations of HTTP/2 vs HTTP/3 differences
- **Interactive Visualizations** - Connection handshake, multiplexing, and migration demos
- **Performance Metrics Guide** - Understanding what each metric means
- **Real-World Scenarios** - Performance expectations in different network conditions
- **QUIC Benefits Deep Dive** - Comprehensive coverage of QUIC protocol advantages

### Network Simulation
- **Latency Simulation** - Test performance under different network conditions
- **Packet Loss Simulation** - Demonstrate HTTP/3's resilience to packet loss
- **Bandwidth Throttling** - Simulate various connection speeds
- **Mobile Network Conditions** - Test scenarios for mobile users

### Advanced Features
- **Caching Behavior Analysis** - Compare caching strategies between protocols
- **Multiplexing Demonstration** - Visual representation of request multiplexing
- **Connection Migration** - Demonstrate HTTP/3's connection migration capabilities
- **Resource Loading Patterns** - Analyze how different resource types are loaded

## 🏗️ Project Structure

```
.
├── README.md                   # This file
├── docker-compose.yml          # Container orchestration
├── nginx/                      # Server configurations
│   ├── http2/                  # HTTP/2 server setup
│   │   ├── Dockerfile
│   │   └── nginx.conf
│   └── http3/                  # HTTP/3 server setup
│       ├── Dockerfile
│       └── nginx.conf
├── web/                        # Web application
│   ├── index.html              # Main demo interface
│   ├── styles.css              # Application styling
│   ├── EDUCATIONAL_CONTENT.md  # Educational documentation
│   ├── js/                     # JavaScript modules
│   │   ├── demo.js             # Main demo controller
│   │   ├── compatibility.js    # Browser compatibility handling
│   │   ├── performance.js      # Performance measurement
│   │   ├── network-simulation.js # Network condition simulation
│   │   └── education.js        # Educational content management
│   ├── resources/              # Test resources
│   │   ├── images/             # Test images of various sizes
│   │   ├── css/                # CSS test files
│   │   └── js/                 # JavaScript test files
│   └── test-*.html             # Individual test pages
├── scripts/                    # Management and utility scripts
│   ├── demo.sh                 # Main management script
│   ├── start-demo.sh           # Demo startup
│   ├── stop-demo.sh            # Demo shutdown
│   ├── cleanup-demo.sh         # Resource cleanup
│   ├── configure-demo.sh       # Configuration management
│   ├── debug-demo.sh           # Debugging utilities
│   ├── monitor.sh              # Health monitoring
│   └── *.sh                    # Supporting scripts
├── certs/                      # SSL certificates
```

## 🔧 Installation & Setup

### Method 1: Using Demo Script (Recommended)
```bash
# Clone the repository
git clone <repository-url>
cd h2-vs-h3-demo

# Start with automatic setup
./scripts/demo.sh start

# Check status
./scripts/demo.sh status
```

### Method 2: Manual Docker Setup
```bash
# Generate SSL certificates
./scripts/generate-certs.sh

# Build and start containers
docker-compose up --build -d

# Verify containers are running
docker-compose ps
```

### Method 3: Development Setup
```bash
# Start with development configuration
./scripts/demo.sh start --env development --log-level debug

# Enable monitoring
./scripts/demo.sh monitor
```

## 📖 Usage Guide

### Basic Performance Testing

1. **Access the Demo**: Open https://localhost:8443 in your browser
2. **Select Test Scenario**: Choose from Basic, Images, Mixed Resources, or Network Simulation
3. **Run Test**: Click "Start Performance Test"
4. **View Results**: Compare metrics between HTTP/2 and HTTP/3
5. **Export Results**: Save results for later analysis

### Advanced Testing

#### Multiple Test Runs
```bash
# Run 5 tests for statistical accuracy
Click "Run 5 Tests" button in the interface
```

#### Network Simulation
```bash
# Access network simulation
Select "Network Simulation Test" scenario
Configure latency, packet loss, and bandwidth
Run tests under different conditions
```

#### Browser Compatibility Testing
```bash
# Test compatibility features
Open https://localhost:8443/test-compatibility.html
Run browser detection and fallback tests
```

### Command Line Management

```bash
# Start demo with custom ports
./scripts/demo.sh start --http2-port 9443 --http3-port 9444

# Monitor health and performance
./scripts/demo.sh monitor

# View logs
./scripts/demo.sh logs --follow

# Debug issues
./scripts/demo.sh debug troubleshoot

# Clean up resources
./scripts/demo.sh cleanup
```

## 🧪 Testing & Validation

### Available Test Pages

| Test Page | Purpose | URL |
|-----------|---------|-----|
| Main Demo | Complete performance comparison | `/index.html` |
| Basic Test | Simple page load testing | `/test-basic.html` |
| Image Test | Image-heavy content testing | `/test-images.html` |
| Mixed Resources | Various resource types | `/test-mixed.html` |
| Caching Test | Cache behavior analysis | `/test-caching.html` |
| Multiplexing | Request multiplexing demo | `/test-multiplexing.html` |
| Network Simulation | Network condition testing | `/test-network-simulation.html` |
| Compatibility Test | Browser compatibility testing | `/test-compatibility.html` |
| Comprehensive Test | All features combined | `/test-comprehensive.html` |

### Running Tests

#### Automated Health Checks
```bash
# Check HTTP/2 server health
./scripts/health-check-http2.sh

# Check HTTP/3 server health
./scripts/health-check-http3.sh

# Check QUIC connectivity
./scripts/quic-connectivity-test.sh
```

#### Manual Testing
```bash
# Test HTTP/2 endpoint
curl -k --http2 https://localhost:8443/

# Test HTTP/3 endpoint (if supported)
curl -k --http3 https://localhost:8444/
```

## 🌐 Browser Compatibility

### Supported Browsers

| Browser | HTTP/2 | HTTP/3 | Notes |
|---------|--------|--------|-------|
| Chrome 87+ | ✅ Full | ✅ Full | Best experience |
| Firefox 88+ | ✅ Full | ✅ Full | May require enabling |
| Edge 87+ | ✅ Full | ✅ Full | Full support |
| Safari 14+ | ✅ Full | ⚠️ Limited | Limited HTTP/3 support |
| Older Browsers | ✅ Full | ❌ None | Automatic fallback |

### Compatibility Features

- **Automatic Detection**: Browser and version identification
- **Graceful Fallback**: HTTP/3 requests automatically redirect to HTTP/2
- **User Notifications**: Browser-specific instructions and warnings
- **Visual Indicators**: UI adjustments based on support level
- **Fallback Testing**: Manual fallback mode for testing

### Enabling HTTP/3 in Firefox
1. Type `about:config` in the address bar
2. Search for `network.http.http3.enabled`
3. Set the value to `true`
4. Restart Firefox and reload the demo

## 📚 Educational Content

### Interactive Learning Modules

1. **Protocol Overview**: Understanding HTTP/2 and HTTP/3 fundamentals
2. **Connection Handshake**: Visual comparison of connection establishment
3. **Multiplexing**: How requests are handled differently
4. **Connection Migration**: HTTP/3's network change resilience
5. **Security**: Built-in encryption and security improvements
6. **Performance Metrics**: Understanding what measurements mean
7. **Real-World Scenarios**: Performance in different network conditions

### QUIC Benefits Deep Dive

- **0-RTT Connection Resumption**: Instant reconnection for repeat visits
- **Connection Migration**: Seamless network switching
- **Advanced Congestion Control**: Better bandwidth utilization
- **Integrated Security**: Mandatory encryption with TLS 1.3
- **Stream Independence**: No head-of-line blocking

## 🔧 Scripts & Automation

### Main Management Script
```bash
./scripts/demo.sh <command> [options]

Commands:
  start     - Start the demo
  stop      - Stop the demo
  restart   - Restart the demo
  status    - Show status
  logs      - Show logs
  cleanup   - Clean up resources
  configure - Configure settings
  debug     - Debug utilities
  monitor   - Health monitoring
```

### Individual Scripts

| Script | Purpose |
|--------|---------|
| `start-demo.sh` | Comprehensive demo startup with validation |
| `stop-demo.sh` | Graceful shutdown with cleanup options |
| `cleanup-demo.sh` | Resource cleanup and maintenance |
| `configure-demo.sh` | Configuration management |
| `debug-demo.sh` | Debugging and troubleshooting |
| `monitor.sh` | Health monitoring and reporting |
| `generate-certs.sh` | SSL certificate generation |
| `health-check-*.sh` | Protocol-specific health checks |
| `port-check.sh` | Port availability verification |
| `cert-validation.sh` | Certificate validation |
| `quic-connectivity-test.sh` | QUIC connectivity testing |

### Script Options

```bash
# Start with custom configuration
./scripts/demo.sh start --http2-port 9443 --http3-port 9444 --env production

# Debug with verbose logging
./scripts/demo.sh debug troubleshoot --debug-level verbose --output-file debug.log

# Cleanup with options
./scripts/demo.sh cleanup --keep-certs --keep-logs
```

## ⚙️ Configuration

### Environment Variables

Create a `.env` file in the project root:

```bash
# Server Configuration
HTTP2_PORT=8443
HTTP3_PORT=8444
DEMO_ENV=development

# Build Configuration
BUILD_MODE=pull
COMPOSE_FILE=docker-compose.yml
STOP_TIMEOUT=30

# Logging
LOG_LEVEL=info
LOG_DIR=/tmp/h2-h3-demo-logs

# Feature Flags
SKIP_HEALTH_CHECK=false
FORCE_REBUILD=false
KEEP_LOGS=false
KEEP_CERTS=false
```

### Interactive Configuration
```bash
# Interactive setup
./scripts/demo.sh configure --interactive

# Set specific values
./scripts/demo.sh configure --set HTTP2_PORT=9443
./scripts/demo.sh configure --set LOG_LEVEL=debug

# Show current configuration
./scripts/demo.sh configure --show
```

## 🔍 Troubleshooting

### Common Issues

#### Port Conflicts
```bash
# Check port availability
./scripts/debug-demo.sh network

# Use different ports
./scripts/demo.sh start --http2-port 9443 --http3-port 9444
```

#### Certificate Issues
```bash
# Validate certificates
./scripts/debug-demo.sh certificates

# Regenerate certificates
./scripts/generate-certs.sh --force
```

#### Container Problems
```bash
# Comprehensive troubleshooting
./scripts/debug-demo.sh troubleshoot

# Check container logs
./scripts/demo.sh logs --follow

# Rebuild containers
./scripts/demo.sh start --build-mode rebuild
```

#### HTTP/3 Not Working
```bash
# Test QUIC connectivity
./scripts/quic-connectivity-test.sh

# Check browser compatibility
Open https://localhost:8443/test-compatibility.html

# Force fallback mode for testing
Use compatibility test page to force fallback
```

### Debug Information Collection
```bash
# Collect comprehensive debug info
./scripts/debug-demo.sh collect

# This creates a report with:
# - System information
# - Container status
# - Network configuration
# - Certificate details
# - Performance metrics
# - Configuration files
# - Recent logs
```

### Log Files

Logs are stored in `/tmp/h2-h3-demo-logs/`:
- `startup_TIMESTAMP.log` - Startup operations
- `stop_TIMESTAMP.log` - Stop operations
- `cleanup_TIMESTAMP.log` - Cleanup operations
- `debug_TIMESTAMP.log` - Debug sessions
- `monitor_TIMESTAMP.log` - Monitoring data

## 🤝 Contributing

### Development Setup
```bash
# Clone and setup
git clone <repository-url>
cd h2-vs-h3-demo

# Start in development mode
./scripts/demo.sh start --env development --log-level debug

# Make changes and test
# ... your changes ...

# Run tests
./scripts/debug-demo.sh troubleshoot
```

### Code Structure
- **Frontend**: Vanilla JavaScript with modular architecture
- **Backend**: nginx with HTTP/2 and HTTP/3 configurations
- **Infrastructure**: Docker containers with health checks
- **Scripts**: Bash scripts with comprehensive error handling

### Testing Changes
```bash
# Test compatibility features
Open /test-compatibility.html

# Test performance features
Open /test-comprehensive.html

# Test network simulation
Open /test-network-simulation.html

# Run health checks
./scripts/monitor.sh
```

## 📄 License

This project is open source. See the LICENSE file for details.

## 🆘 Support

### Getting Help
1. Check the [Troubleshooting](#-troubleshooting) section
2. Run `./scripts/debug-demo.sh troubleshoot`
3. Collect debug information with `./scripts/debug-demo.sh collect`
4. Check the logs in `/tmp/h2-h3-demo-logs/`

### Reporting Issues
When reporting issues, please include:
- Browser type and version
- Operating system
- Error messages from logs
- Steps to reproduce
- Output from `./scripts/debug-demo.sh collect`

---

**Happy testing! 🚀** Experience the future of web protocols with HTTP/3 and QUIC.
