/**
 * Network Simulation Module
 * Simulates various network conditions and connection scenarios
 */

class NetworkSimulation {
    constructor() {
        this.isSimulating = false;
        this.currentSimulation = null;
        this.simulationWorker = null;
        this.connectionStates = {
            http2: 'connected',
            http3: 'connected'
        };
        this.simulationHistory = [];
        
        this.init();
    }

    /**
     * Initialize network simulation
     */
    init() {
        this.setupSimulationControls();
        this.initializeConnectionMonitoring();
        console.log('Network simulation initialized');
    }

    /**
     * Setup simulation control UI
     */
    setupSimulationControls() {
        // Create simulation controls container
        const controlsContainer = this.createSimulationControls();
        
        // Insert after existing controls
        const existingControls = document.querySelector('.controls');
        if (existingControls) {
            existingControls.parentNode.insertBefore(controlsContainer, existingControls.nextSibling);
        }
    }

    /**
     * Create simulation controls UI
     */
    createSimulationControls() {
        const container = document.createElement('div');
        container.className = 'network-simulation-controls';
        container.innerHTML = `
            <div class="simulation-header">
                <h3>Network Simulation</h3>
                <div class="simulation-status" id="simulationStatus">
                    <span class="status-indicator ready"></span>
                    <span class="status-text">Ready</span>
                </div>
            </div>
            
            <div class="simulation-controls-grid">
                <!-- Latency Simulation -->
                <div class="control-group">
                    <label for="latencySlider">Network Latency</label>
                    <div class="slider-container">
                        <input type="range" id="latencySlider" min="0" max="500" value="0" step="10">
                        <span class="slider-value" id="latencyValue">0ms</span>
                    </div>
                    <div class="preset-buttons">
                        <button class="preset-btn" data-latency="0">None</button>
                        <button class="preset-btn" data-latency="50">WiFi</button>
                        <button class="preset-btn" data-latency="150">3G</button>
                        <button class="preset-btn" data-latency="300">2G</button>
                    </div>
                </div>

                <!-- Bandwidth Simulation -->
                <div class="control-group">
                    <label for="bandwidthSlider">Bandwidth Limit</label>
                    <div class="slider-container">
                        <input type="range" id="bandwidthSlider" min="0" max="100" value="0" step="5">
                        <span class="slider-value" id="bandwidthValue">Unlimited</span>
                    </div>
                    <div class="preset-buttons">
                        <button class="preset-btn" data-bandwidth="0">Unlimited</button>
                        <button class="preset-btn" data-bandwidth="10">Slow 3G</button>
                        <button class="preset-btn" data-bandwidth="50">Fast 3G</button>
                        <button class="preset-btn" data-bandwidth="100">4G</button>
                    </div>
                </div>

                <!-- Packet Loss Simulation -->
                <div class="control-group">
                    <label for="packetLossSlider">Packet Loss</label>
                    <div class="slider-container">
                        <input type="range" id="packetLossSlider" min="0" max="10" value="0" step="0.5">
                        <span class="slider-value" id="packetLossValue">0%</span>
                    </div>
                    <div class="preset-buttons">
                        <button class="preset-btn" data-packet-loss="0">None</button>
                        <button class="preset-btn" data-packet-loss="1">Light</button>
                        <button class="preset-btn" data-packet-loss="3">Moderate</button>
                        <button class="preset-btn" data-packet-loss="5">Heavy</button>
                    </div>
                </div>
            </div>

            <div class="simulation-actions">
                <button id="applySimulation" class="btn btn-primary">Apply Simulation</button>
                <button id="resetSimulation" class="btn btn-secondary">Reset Network</button>
                <button id="connectionInterruption" class="btn btn-warning">Simulate Interruption</button>
                <button id="connectionMigration" class="btn btn-info">Test Migration</button>
            </div>

            <div class="simulation-scenarios">
                <label for="scenarioSelect">Quick Scenarios:</label>
                <select id="scenarioSelect" class="scenario-select">
                    <option value="">Select a scenario...</option>
                    <option value="perfect">Perfect Network</option>
                    <option value="home-wifi">Home WiFi</option>
                    <option value="office-wifi">Office WiFi</option>
                    <option value="mobile-4g">Mobile 4G</option>
                    <option value="mobile-3g">Mobile 3G</option>
                    <option value="mobile-2g">Mobile 2G</option>
                    <option value="satellite">Satellite</option>
                    <option value="congested">Congested Network</option>
                    <option value="unstable">Unstable Connection</option>
                </select>
            </div>

            <div class="connection-status">
                <div class="protocol-connection">
                    <span class="protocol-label">HTTP/2:</span>
                    <span class="connection-indicator" id="http2Connection">
                        <span class="connection-dot connected"></span>
                        <span class="connection-text">Connected</span>
                    </span>
                </div>
                <div class="protocol-connection">
                    <span class="protocol-label">HTTP/3:</span>
                    <span class="connection-indicator" id="http3Connection">
                        <span class="connection-dot connected"></span>
                        <span class="connection-text">Connected</span>
                    </span>
                </div>
            </div>
        `;

        this.attachSimulationEventListeners(container);
        return container;
    }

    /**
     * Attach event listeners to simulation controls
     */
    attachSimulationEventListeners(container) {
        // Slider updates
        const latencySlider = container.querySelector('#latencySlider');
        const bandwidthSlider = container.querySelector('#bandwidthSlider');
        const packetLossSlider = container.querySelector('#packetLossSlider');

        latencySlider.addEventListener('input', (e) => {
            const value = e.target.value;
            container.querySelector('#latencyValue').textContent = `${value}ms`;
        });

        bandwidthSlider.addEventListener('input', (e) => {
            const value = e.target.value;
            const text = value === '0' ? 'Unlimited' : `${value} Mbps`;
            container.querySelector('#bandwidthValue').textContent = text;
        });

        packetLossSlider.addEventListener('input', (e) => {
            const value = e.target.value;
            container.querySelector('#packetLossValue').textContent = `${value}%`;
        });

        // Preset buttons
        container.querySelectorAll('.preset-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const latency = e.target.dataset.latency;
                const bandwidth = e.target.dataset.bandwidth;
                const packetLoss = e.target.dataset.packetLoss;

                if (latency !== undefined) {
                    latencySlider.value = latency;
                    latencySlider.dispatchEvent(new Event('input'));
                }
                if (bandwidth !== undefined) {
                    bandwidthSlider.value = bandwidth;
                    bandwidthSlider.dispatchEvent(new Event('input'));
                }
                if (packetLoss !== undefined) {
                    packetLossSlider.value = packetLoss;
                    packetLossSlider.dispatchEvent(new Event('input'));
                }
            });
        });

        // Action buttons
        container.querySelector('#applySimulation').addEventListener('click', () => {
            this.applyNetworkSimulation();
        });

        container.querySelector('#resetSimulation').addEventListener('click', () => {
            this.resetNetworkSimulation();
        });

        container.querySelector('#connectionInterruption').addEventListener('click', () => {
            this.simulateConnectionInterruption();
        });

        container.querySelector('#connectionMigration').addEventListener('click', () => {
            this.testConnectionMigration();
        });

        // Scenario selection
        container.querySelector('#scenarioSelect').addEventListener('change', (e) => {
            if (e.target.value) {
                this.applyNetworkScenario(e.target.value);
            }
        });
    }

    /**
     * Apply network simulation with current settings
     */
    async applyNetworkSimulation() {
        const latency = parseInt(document.getElementById('latencySlider').value);
        const bandwidth = parseInt(document.getElementById('bandwidthSlider').value);
        const packetLoss = parseFloat(document.getElementById('packetLossSlider').value);

        const settings = {
            latency: latency,
            bandwidth: bandwidth === 0 ? null : bandwidth * 1024 * 1024, // Convert to bytes per second
            packetLoss: packetLoss / 100, // Convert to decimal
            timestamp: Date.now()
        };

        console.log('Applying network simulation:', settings);

        try {
            this.updateSimulationStatus('applying', 'Applying simulation...');
            
            // Start simulation
            await this.startNetworkSimulation(settings);
            
            this.currentSimulation = settings;
            this.simulationHistory.push(settings);
            
            this.updateSimulationStatus('active', `Active: ${latency}ms latency, ${packetLoss}% loss`);
            
            // Show notification
            this.showSimulationNotification('Network simulation applied successfully');
            
        } catch (error) {
            console.error('Failed to apply network simulation:', error);
            this.updateSimulationStatus('error', 'Simulation failed');
            this.showSimulationNotification('Failed to apply network simulation', 'error');
        }
    }

    /**
     * Start network simulation with given settings
     */
    async startNetworkSimulation(settings) {
        this.isSimulating = true;

        // Simulate network conditions using various techniques
        if (settings.latency > 0) {
            await this.simulateLatency(settings.latency);
        }

        if (settings.bandwidth) {
            this.simulateBandwidthLimit(settings.bandwidth);
        }

        if (settings.packetLoss > 0) {
            this.simulatePacketLoss(settings.packetLoss);
        }

        // Update connection monitoring
        this.updateConnectionMonitoring(settings);
    }

    /**
     * Simulate network latency
     */
    async simulateLatency(latencyMs) {
        // Create artificial delay for requests
        const originalFetch = window.fetch;
        
        window.fetch = async function(url, options) {
            // Add delay before making request
            await new Promise(resolve => setTimeout(resolve, latencyMs / 2));
            
            const response = await originalFetch(url, options);
            
            // Add delay after receiving response
            await new Promise(resolve => setTimeout(resolve, latencyMs / 2));
            
            return response;
        };

        // Store original fetch for restoration
        this._originalFetch = originalFetch;
        
        console.log(`Simulating ${latencyMs}ms network latency`);
    }

    /**
     * Simulate bandwidth limitations
     */
    simulateBandwidthLimit(bytesPerSecond) {
        // This is a simplified simulation - in reality, bandwidth limiting
        // would require server-side or browser extension support
        console.log(`Simulating bandwidth limit: ${(bytesPerSecond / 1024 / 1024).toFixed(1)} Mbps`);
        
        // We can simulate by adding delays proportional to content size
        const originalFetch = window.fetch;
        
        window.fetch = async function(url, options) {
            const response = await originalFetch(url, options);
            
            // Clone response to read content length
            const clonedResponse = response.clone();
            const contentLength = parseInt(response.headers.get('content-length')) || 0;
            
            if (contentLength > 0) {
                // Calculate delay based on bandwidth limit
                const transferTime = (contentLength / bytesPerSecond) * 1000; // Convert to ms
                await new Promise(resolve => setTimeout(resolve, transferTime));
            }
            
            return response;
        };

        this._originalFetch = originalFetch;
    }

    /**
     * Simulate packet loss
     */
    simulatePacketLoss(lossRate) {
        console.log(`Simulating ${(lossRate * 100).toFixed(1)}% packet loss`);
        
        const originalFetch = window.fetch;
        
        window.fetch = async function(url, options) {
            // Randomly fail requests based on loss rate
            if (Math.random() < lossRate) {
                throw new Error('Simulated packet loss - request failed');
            }
            
            return await originalFetch(url, options);
        };

        this._originalFetch = originalFetch;
    }

    /**
     * Reset network simulation
     */
    resetNetworkSimulation() {
        console.log('Resetting network simulation');

        // Restore original fetch if modified
        if (this._originalFetch) {
            window.fetch = this._originalFetch;
            delete this._originalFetch;
        }

        // Reset UI controls
        document.getElementById('latencySlider').value = 0;
        document.getElementById('bandwidthSlider').value = 0;
        document.getElementById('packetLossSlider').value = 0;
        document.getElementById('scenarioSelect').value = '';

        // Update display values
        document.getElementById('latencyValue').textContent = '0ms';
        document.getElementById('bandwidthValue').textContent = 'Unlimited';
        document.getElementById('packetLossValue').textContent = '0%';

        // Reset state
        this.isSimulating = false;
        this.currentSimulation = null;

        // Update status
        this.updateSimulationStatus('ready', 'Ready');
        this.updateConnectionStatus('http2', 'connected', 'Connected');
        this.updateConnectionStatus('http3', 'connected', 'Connected');

        this.showSimulationNotification('Network simulation reset');
    }

    /**
     * Apply predefined network scenario
     */
    applyNetworkScenario(scenario) {
        const scenarios = {
            'perfect': { latency: 0, bandwidth: 0, packetLoss: 0 },
            'home-wifi': { latency: 20, bandwidth: 50, packetLoss: 0 },
            'office-wifi': { latency: 10, bandwidth: 100, packetLoss: 0.1 },
            'mobile-4g': { latency: 50, bandwidth: 25, packetLoss: 0.5 },
            'mobile-3g': { latency: 150, bandwidth: 5, packetLoss: 1 },
            'mobile-2g': { latency: 300, bandwidth: 1, packetLoss: 2 },
            'satellite': { latency: 600, bandwidth: 10, packetLoss: 0.5 },
            'congested': { latency: 200, bandwidth: 2, packetLoss: 3 },
            'unstable': { latency: 100, bandwidth: 10, packetLoss: 5 }
        };

        const settings = scenarios[scenario];
        if (!settings) return;

        // Update UI controls
        document.getElementById('latencySlider').value = settings.latency;
        document.getElementById('bandwidthSlider').value = settings.bandwidth;
        document.getElementById('packetLossSlider').value = settings.packetLoss;

        // Trigger input events to update displays
        document.getElementById('latencySlider').dispatchEvent(new Event('input'));
        document.getElementById('bandwidthSlider').dispatchEvent(new Event('input'));
        document.getElementById('packetLossSlider').dispatchEvent(new Event('input'));

        // Apply the simulation
        this.applyNetworkSimulation();

        console.log(`Applied network scenario: ${scenario}`, settings);
    }

    /**
     * Simulate connection interruption
     */
    async simulateConnectionInterruption() {
        console.log('Simulating connection interruption');

        this.updateSimulationStatus('interrupting', 'Simulating interruption...');
        
        // Simulate connection loss
        this.updateConnectionStatus('http2', 'disconnected', 'Interrupted');
        this.updateConnectionStatus('http3', 'disconnected', 'Interrupted');

        // Block all requests temporarily
        const originalFetch = window.fetch;
        window.fetch = async function() {
            throw new Error('Connection interrupted');
        };

        // Show interruption for 3 seconds
        await new Promise(resolve => setTimeout(resolve, 3000));

        // Restore HTTP/2 connection (requires full reconnection)
        window.fetch = originalFetch;
        this.updateConnectionStatus('http2', 'reconnecting', 'Reconnecting...');
        
        // Simulate reconnection delay for HTTP/2
        await new Promise(resolve => setTimeout(resolve, 2000));
        this.updateConnectionStatus('http2', 'connected', 'Reconnected');

        // HTTP/3 recovers faster due to connection migration
        await new Promise(resolve => setTimeout(resolve, 500));
        this.updateConnectionStatus('http3', 'connected', 'Migrated');

        this.updateSimulationStatus('ready', 'Interruption test complete');
        
        this.showSimulationNotification('Connection interruption simulation completed');
    }

    /**
     * Test HTTP/3 connection migration
     */
    async testConnectionMigration() {
        console.log('Testing HTTP/3 connection migration');

        this.updateSimulationStatus('migrating', 'Testing migration...');
        
        // Simulate network change for HTTP/3
        this.updateConnectionStatus('http3', 'migrating', 'Migrating...');
        
        // HTTP/2 would lose connection
        this.updateConnectionStatus('http2', 'disconnected', 'Lost connection');

        // Simulate migration process
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        // HTTP/3 successfully migrates
        this.updateConnectionStatus('http3', 'connected', 'Migration successful');
        
        // HTTP/2 needs to reconnect
        this.updateConnectionStatus('http2', 'reconnecting', 'Reconnecting...');
        await new Promise(resolve => setTimeout(resolve, 2000));
        this.updateConnectionStatus('http2', 'connected', 'Reconnected');

        this.updateSimulationStatus('ready', 'Migration test complete');
        
        this.showSimulationNotification('HTTP/3 connection migration test completed');
        
        // Show educational popup about connection migration
        this.showConnectionMigrationInfo();
    }

    /**
     * Show connection migration educational info
     */
    showConnectionMigrationInfo() {
        const modal = document.createElement('div');
        modal.className = 'migration-info-modal';
        modal.innerHTML = `
            <div class="modal-content">
                <div class="modal-header">
                    <h3>HTTP/3 Connection Migration</h3>
                    <button class="modal-close" onclick="this.closest('.migration-info-modal').remove()">×</button>
                </div>
                <div class="modal-body">
                    <p><strong>What just happened?</strong></p>
                    <ul>
                        <li><strong>HTTP/2:</strong> Lost connection when network changed, required full reconnection (TCP + TLS handshake)</li>
                        <li><strong>HTTP/3:</strong> Seamlessly migrated to new network path using connection ID</li>
                    </ul>
                    
                    <p><strong>Why HTTP/3 is better:</strong></p>
                    <ul>
                        <li>Uses connection IDs instead of IP addresses</li>
                        <li>Can survive network interface changes</li>
                        <li>No interruption to ongoing transfers</li>
                        <li>Critical for mobile users switching networks</li>
                    </ul>
                    
                    <p><strong>Real-world scenarios:</strong></p>
                    <ul>
                        <li>WiFi to cellular handoff</li>
                        <li>Moving between WiFi access points</li>
                        <li>Load balancer changes</li>
                        <li>Network failover situations</li>
                    </ul>
                </div>
                <div class="modal-footer">
                    <button class="btn btn-primary" onclick="this.closest('.migration-info-modal').remove()">Got it!</button>
                </div>
            </div>
        `;

        // Add modal styles
        modal.style.cssText = `
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0,0,0,0.5);
            display: flex;
            align-items: center;
            justify-content: center;
            z-index: 10000;
        `;

        document.body.appendChild(modal);
    }

    /**
     * Initialize connection monitoring
     */
    initializeConnectionMonitoring() {
        // Monitor connection status periodically
        setInterval(() => {
            this.checkConnectionStatus();
        }, 5000);
    }

    /**
     * Check connection status
     */
    async checkConnectionStatus() {
        if (!this.isSimulating) return;

        try {
            // Test HTTP/2 connection
            const http2Response = await fetch('https://localhost:8443/test-basic.html', {
                method: 'HEAD',
                cache: 'no-cache'
            });
            
            if (http2Response.ok) {
                this.updateConnectionStatus('http2', 'connected', 'Connected');
            }
        } catch (error) {
            this.updateConnectionStatus('http2', 'error', 'Connection error');
        }

        try {
            // Test HTTP/3 connection
            const http3Response = await fetch('https://localhost:8444/test-basic.html', {
                method: 'HEAD',
                cache: 'no-cache'
            });
            
            if (http3Response.ok) {
                this.updateConnectionStatus('http3', 'connected', 'Connected');
            }
        } catch (error) {
            this.updateConnectionStatus('http3', 'error', 'Connection error');
        }
    }

    /**
     * Update connection monitoring based on simulation
     */
    updateConnectionMonitoring(settings) {
        // Adjust monitoring frequency based on network conditions
        const baseInterval = 5000;
        const adjustedInterval = baseInterval + (settings.latency * 2);
        
        console.log(`Adjusted connection monitoring interval: ${adjustedInterval}ms`);
    }

    /**
     * Update simulation status
     */
    updateSimulationStatus(status, text) {
        const statusElement = document.getElementById('simulationStatus');
        if (!statusElement) return;

        const indicator = statusElement.querySelector('.status-indicator');
        const textElement = statusElement.querySelector('.status-text');

        if (indicator) {
            indicator.className = `status-indicator ${status}`;
        }
        if (textElement) {
            textElement.textContent = text;
        }
    }

    /**
     * Update connection status for a protocol
     */
    updateConnectionStatus(protocol, status, text) {
        const connectionElement = document.getElementById(`${protocol}Connection`);
        if (!connectionElement) return;

        const dot = connectionElement.querySelector('.connection-dot');
        const textElement = connectionElement.querySelector('.connection-text');

        if (dot) {
            dot.className = `connection-dot ${status}`;
        }
        if (textElement) {
            textElement.textContent = text;
        }

        // Update internal state
        this.connectionStates[protocol] = status;
    }

    /**
     * Show simulation notification
     */
    showSimulationNotification(message, type = 'info') {
        const notification = document.createElement('div');
        notification.className = `simulation-notification ${type}`;
        notification.innerHTML = `
            <div class="notification-content">
                <span class="notification-icon">${type === 'error' ? '❌' : 'ℹ️'}</span>
                <span class="notification-text">${message}</span>
                <button class="notification-close" onclick="this.parentElement.parentElement.remove()">×</button>
            </div>
        `;

        notification.style.cssText = `
            position: fixed;
            top: 80px;
            right: 20px;
            background: ${type === 'error' ? '#f8d7da' : '#d1ecf1'};
            border: 1px solid ${type === 'error' ? '#f5c6cb' : '#bee5eb'};
            border-radius: 8px;
            padding: 1rem;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            z-index: 1000;
            max-width: 400px;
        `;

        document.body.appendChild(notification);

        setTimeout(() => {
            if (notification.parentElement) {
                notification.remove();
            }
        }, 5000);
    }

    /**
     * Get current simulation state
     */
    getSimulationState() {
        return {
            isSimulating: this.isSimulating,
            currentSimulation: this.currentSimulation,
            connectionStates: { ...this.connectionStates },
            history: [...this.simulationHistory]
        };
    }

    /**
     * Export simulation results
     */
    exportSimulationResults() {
        const results = {
            timestamp: new Date().toISOString(),
            simulationState: this.getSimulationState(),
            history: this.simulationHistory,
            browserInfo: {
                userAgent: navigator.userAgent,
                connection: navigator.connection ? {
                    effectiveType: navigator.connection.effectiveType,
                    downlink: navigator.connection.downlink,
                    rtt: navigator.connection.rtt
                } : null
            }
        };

        const dataStr = JSON.stringify(results, null, 2);
        const dataBlob = new Blob([dataStr], { type: 'application/json' });
        const url = URL.createObjectURL(dataBlob);
        
        const link = document.createElement('a');
        link.href = url;
        link.download = `network-simulation-${new Date().toISOString().slice(0, 19).replace(/:/g, '-')}.json`;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(url);

        console.log('Simulation results exported');
        return results;
    }
}

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = NetworkSimulation;
}