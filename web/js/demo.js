/**
 * Main Demo Controller
 * Coordinates the HTTP/2 vs HTTP/3 demonstration
 */

class DemoController {
    constructor() {
        this.performanceMeasurement = null;
        this.compatibilityChecker = null;
        this.networkSimulation = null;
        this.initialized = false;
        
        this.init();
    }

    /**
     * Initialize the demo
     */
    init() {
        // Wait for DOM and other modules to be ready
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', () => this.setup());
        } else {
            this.setup();
        }
    }

    /**
     * Setup the demo after DOM is ready
     */
    setup() {
        // Initialize performance measurement
        this.performanceMeasurement = new PerformanceMeasurement();
        
        // Initialize network simulation
        this.networkSimulation = new NetworkSimulation();
        
        // Wait for compatibility checker
        this.waitForCompatibilityChecker();
        
        // Setup event listeners
        this.setupEventListeners();
        
        // Initialize UI
        this.initializeUI();
        
        this.initialized = true;
        console.log('Demo controller initialized');
    }

    /**
     * Wait for compatibility checker to be ready
     */
    waitForCompatibilityChecker() {
        if (window.compatibilityChecker) {
            this.compatibilityChecker = window.compatibilityChecker;
            this.handleCompatibilityResults();
        } else {
            // Listen for compatibility check completion
            window.addEventListener('compatibilityChecked', (event) => {
                this.compatibilityChecker = window.compatibilityChecker;
                this.handleCompatibilityResults(event.detail);
            });
        }
    }

    /**
     * Handle compatibility check results
     */
    handleCompatibilityResults(compatibility) {
        if (!compatibility) {
            compatibility = window.protocolCompatibility;
        }

        console.log('Browser compatibility:', compatibility);

        // Handle different levels of HTTP/3 support
        if (compatibility.http3 === 'requires-flag') {
            // Firefox users need to enable HTTP/3 manually
            console.log('HTTP/3 requires manual enabling');
        } else if (compatibility.http3 === 'limited') {
            // Limited support browsers
            console.log('Limited HTTP/3 support detected');
        } else if (!compatibility.http3) {
            // No HTTP/3 support
            console.log('No HTTP/3 support - using fallback');
        }

        // Update UI based on compatibility
        this.updateUIForCompatibility(compatibility);
    }

    /**
     * Setup event listeners
     */
    setupEventListeners() {
        // Start test button
        const startButton = document.getElementById('startTest');
        if (startButton) {
            startButton.addEventListener('click', () => this.startTest());
        }

        // Reset button
        const resetButton = document.getElementById('resetTest');
        if (resetButton) {
            resetButton.addEventListener('click', () => this.resetTest());
        }

        // Scenario selection
        const scenarioSelect = document.getElementById('testScenario');
        if (scenarioSelect) {
            scenarioSelect.addEventListener('change', (e) => this.onScenarioChange(e.target.value));
        }

        // Export results button
        const exportButton = document.getElementById('exportResults');
        if (exportButton) {
            exportButton.addEventListener('click', () => this.exportResults());
        }

        // Import results button
        const importButton = document.getElementById('importResultsBtn');
        const importInput = document.getElementById('importResults');
        if (importButton && importInput) {
            importButton.addEventListener('click', () => importInput.click());
            importInput.addEventListener('change', (e) => this.importResults(e.target.files[0]));
        }

        // Run multiple tests button
        const multipleTestsButton = document.getElementById('runMultipleTests');
        if (multipleTestsButton) {
            multipleTestsButton.addEventListener('click', () => this.runMultipleTests());
        }

        // Handle iframe errors
        this.setupIframeErrorHandling();

        // Handle window resize for responsive updates
        window.addEventListener('resize', () => this.handleResize());

        // Handle visibility change to pause/resume tests
        document.addEventListener('visibilitychange', () => this.handleVisibilityChange());
    }

    /**
     * Setup iframe error handling
     */
    setupIframeErrorHandling() {
        const http2Frame = document.getElementById('http2Frame');
        const http3Frame = document.getElementById('http3Frame');

        if (http2Frame) {
            http2Frame.addEventListener('error', () => {
                this.handleIframeError('http2');
            });
        }

        if (http3Frame) {
            http3Frame.addEventListener('error', () => {
                this.handleIframeError('http3');
            });
        }
    }

    /**
     * Handle iframe loading errors
     */
    handleIframeError(protocol) {
        console.error(`${protocol} iframe failed to load`);
        
        const statusElement = document.getElementById(`${protocol}Status`);
        if (statusElement) {
            const dot = statusElement.querySelector('.status-dot');
            const text = statusElement.querySelector('.status-text');
            
            if (dot) dot.className = 'status-dot error';
            if (text) text.textContent = 'Connection Error';
        }

        // Show helpful error message
        this.showConnectionError(protocol);
    }

    /**
     * Show connection error message
     */
    showConnectionError(protocol) {
        const port = protocol === 'http2' ? '8443' : '8444';
        const message = `
            <div class="error-message">
                <strong>Connection Error:</strong> Unable to connect to ${protocol.toUpperCase()} server on port ${port}.
                <br><small>Please ensure the Docker containers are running: <code>docker-compose up</code></small>
            </div>
        `;

        const summaryElement = document.getElementById('resultsSummary');
        const contentElement = document.getElementById('summaryContent');

        if (summaryElement && contentElement) {
            contentElement.innerHTML = message;
            summaryElement.style.display = 'block';
        }
    }

    /**
     * Initialize UI elements
     */
    initializeUI() {
        // Set default scenario
        const scenarioSelect = document.getElementById('testScenario');
        if (scenarioSelect && !scenarioSelect.value) {
            scenarioSelect.value = 'basic';
        }

        // Initialize protocol status
        this.updateProtocolStatus('http2', 'ready', 'Ready');
        this.updateProtocolStatus('http3', 'ready', 'Ready');

        // Add keyboard shortcuts
        this.setupKeyboardShortcuts();
    }

    /**
     * Setup keyboard shortcuts
     */
    setupKeyboardShortcuts() {
        document.addEventListener('keydown', (e) => {
            // Ctrl/Cmd + Enter to start test
            if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
                e.preventDefault();
                this.startTest();
            }
            
            // Escape to reset
            if (e.key === 'Escape') {
                e.preventDefault();
                this.resetTest();
            }
        });
    }

    /**
     * Start performance test
     */
    async startTest() {
        if (!this.performanceMeasurement) {
            console.error('Performance measurement not initialized');
            return;
        }

        const scenarioSelect = document.getElementById('testScenario');
        const scenario = scenarioSelect ? scenarioSelect.value : 'basic';

        console.log(`Starting performance test with scenario: ${scenario}`);

        // Show protocol-specific warnings
        this.showProtocolWarnings();

        try {
            await this.performanceMeasurement.startTest(scenario);
        } catch (error) {
            console.error('Test failed:', error);
            this.showError(`Test failed: ${error.message}`);
        }
    }

    /**
     * Reset test
     */
    resetTest() {
        if (this.performanceMeasurement) {
            this.performanceMeasurement.resetTest();
        }
        
        console.log('Test reset');
    }

    /**
     * Handle scenario change
     */
    onScenarioChange(scenario) {
        console.log(`Scenario changed to: ${scenario}`);
        
        // Update UI to reflect scenario
        this.updateScenarioDescription(scenario);
    }

    /**
     * Update scenario description
     */
    updateScenarioDescription(scenario) {
        if (!this.performanceMeasurement) return;

        const scenarios = this.performanceMeasurement.testScenarios;
        const scenarioInfo = scenarios[scenario];

        if (scenarioInfo) {
            // You could add a description element to show scenario details
            console.log(`Selected scenario: ${scenarioInfo.name} - ${scenarioInfo.description}`);
        }
    }

    /**
     * Update protocol status
     */
    updateProtocolStatus(protocol, status, text) {
        const statusElement = document.getElementById(`${protocol}Status`);
        if (!statusElement) return;

        const dot = statusElement.querySelector('.status-dot');
        const textElement = statusElement.querySelector('.status-text');

        if (dot) {
            dot.className = `status-dot ${status}`;
        }
        if (textElement) {
            textElement.textContent = text;
        }
    }

    /**
     * Show compatibility warning
     */
    showCompatibilityWarning(message) {
        // Create a temporary notification
        const notification = document.createElement('div');
        notification.className = 'compatibility-warning';
        notification.innerHTML = `
            <div class="warning-content">
                <span class="warning-icon">⚠️</span>
                <span class="warning-text">${message}</span>
                <button class="warning-close" onclick="this.parentElement.parentElement.remove()">×</button>
            </div>
        `;

        // Add styles
        notification.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            background: #fff3cd;
            border: 1px solid #ffeaa7;
            border-radius: 8px;
            padding: 1rem;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            z-index: 1000;
            max-width: 400px;
        `;

        document.body.appendChild(notification);

        // Auto-remove after 10 seconds
        setTimeout(() => {
            if (notification.parentElement) {
                notification.remove();
            }
        }, 10000);
    }

    /**
     * Update UI for compatibility
     */
    updateUIForCompatibility(compatibility) {
        // Handle different HTTP/3 support levels
        const http3Section = document.querySelector('.protocol-section:nth-child(2)');
        if (http3Section) {
            if (compatibility.http3 === 'requires-flag') {
                http3Section.classList.add('requires-config');
                http3Section.title = 'HTTP/3 available but requires manual enabling';
            } else if (compatibility.http3 === 'limited') {
                http3Section.classList.add('limited-support');
                http3Section.title = 'Limited HTTP/3 support - may fall back to HTTP/2';
            } else if (!compatibility.http3) {
                http3Section.classList.add('limited-support');
                http3Section.title = 'HTTP/3 not supported - using HTTP/2 fallback';
            }
        }

        // Update test scenario options if fallback is active
        if (compatibility.fallbackActive) {
            this.updateTestScenariosForFallback();
        }

        // Add browser-specific notes
        this.addBrowserSpecificNotes(compatibility.browser);
    }

    /**
     * Update test scenarios for fallback mode
     */
    updateTestScenariosForFallback() {
        const testScenario = document.getElementById('testScenario');
        if (!testScenario) return;

        // Add fallback indicators to scenario options
        Array.from(testScenario.options).forEach(option => {
            if (!option.textContent.includes('(Fallback)')) {
                option.textContent += ' (Fallback Mode)';
            }
        });

        // Update start button tooltip
        const startButton = document.getElementById('startTest');
        if (startButton) {
            startButton.title = 'Running in fallback mode - HTTP/3 requests will be redirected to HTTP/2';
        }
    }

    /**
     * Add browser-specific notes
     */
    addBrowserSpecificNotes(browserInfo) {
        const notes = [];

        if (browserInfo.browser === 'Firefox') {
            notes.push('Firefox: HTTP/3 may require enabling in about:config');
        } else if (browserInfo.browser === 'Safari') {
            notes.push('Safari: HTTP/3 support is limited');
        } else if (browserInfo.browser === 'Chrome') {
            notes.push('Chrome: Full HTTP/2 and HTTP/3 support available');
        } else if (browserInfo.browser === 'Edge') {
            notes.push('Edge: HTTP/3 support available in recent versions');
        }

        if (notes.length > 0) {
            console.log('Browser notes:', notes);
        }
    }

    /**
     * Handle window resize
     */
    handleResize() {
        // Update responsive elements if needed
        console.log('Window resized');
    }

    /**
     * Handle visibility change
     */
    handleVisibilityChange() {
        if (document.hidden) {
            console.log('Page hidden - pausing any active tests');
        } else {
            console.log('Page visible - resuming');
        }
    }

    /**
     * Show error message
     */
    showError(message) {
        console.error(message);
        
        const summaryElement = document.getElementById('resultsSummary');
        const contentElement = document.getElementById('summaryContent');

        if (summaryElement && contentElement) {
            contentElement.innerHTML = `
                <div class="error-message">
                    <strong>Error:</strong> ${message}
                </div>
            `;
            summaryElement.style.display = 'block';
        }
    }

    /**
     * Export test results
     */
    exportResults() {
        if (!this.performanceMeasurement) {
            this.showError('Performance measurement not initialized');
            return;
        }

        try {
            this.performanceMeasurement.exportResults();
            console.log('Results exported successfully');
        } catch (error) {
            console.error('Export failed:', error);
            this.showError(`Export failed: ${error.message}`);
        }
    }

    /**
     * Import test results
     */
    async importResults(file) {
        if (!file || !this.performanceMeasurement) {
            return;
        }

        try {
            const results = await this.performanceMeasurement.importResults(file);
            console.log('Results imported successfully:', results);
            
            // Show success message
            this.showSuccessMessage('Test results imported successfully');
        } catch (error) {
            console.error('Import failed:', error);
            this.showError(`Import failed: ${error.message}`);
        }
    }

    /**
     * Run multiple tests for better statistical accuracy
     */
    async runMultipleTests(count = 5) {
        if (!this.performanceMeasurement) {
            this.showError('Performance measurement not initialized');
            return;
        }

        const scenarioSelect = document.getElementById('testScenario');
        const scenario = scenarioSelect ? scenarioSelect.value : 'basic';

        console.log(`Running ${count} tests with scenario: ${scenario}`);

        // Update UI to show multiple test progress
        const startButton = document.getElementById('startTest');
        const multipleTestsButton = document.getElementById('runMultipleTests');
        
        if (startButton) startButton.disabled = true;
        if (multipleTestsButton) {
            multipleTestsButton.disabled = true;
            multipleTestsButton.textContent = `Running test 1/${count}...`;
        }

        try {
            for (let i = 0; i < count; i++) {
                console.log(`Running test ${i + 1}/${count}`);
                
                if (multipleTestsButton) {
                    multipleTestsButton.textContent = `Running test ${i + 1}/${count}...`;
                }

                await this.performanceMeasurement.startTest(scenario);
                
                // Wait between tests to avoid overwhelming the servers
                if (i < count - 1) {
                    await new Promise(resolve => setTimeout(resolve, 2000));
                }
            }

            // Show aggregated results
            this.showMultipleTestResults(count);
            
        } catch (error) {
            console.error('Multiple tests failed:', error);
            this.showError(`Multiple tests failed: ${error.message}`);
        } finally {
            // Reset UI
            if (startButton) startButton.disabled = false;
            if (multipleTestsButton) {
                multipleTestsButton.disabled = false;
                multipleTestsButton.textContent = 'Run 5 Tests';
            }
        }
    }

    /**
     * Show results from multiple tests
     */
    showMultipleTestResults(testCount) {
        const stats = this.performanceMeasurement.getStatistics();
        
        const summaryElement = document.getElementById('resultsSummary');
        const contentElement = document.getElementById('summaryContent');

        if (summaryElement && contentElement) {
            contentElement.innerHTML = `
                <div class="summary-header">
                    <h4>Multiple Test Results (${testCount} tests)</h4>
                </div>
                
                <div class="multiple-test-stats">
                    <div class="protocol-stats">
                        <h5>HTTP/2 Statistics:</h5>
                        <p>Average: ${stats.http2.avg.toFixed(0)}ms</p>
                        <p>Min: ${stats.http2.min.toFixed(0)}ms</p>
                        <p>Max: ${stats.http2.max.toFixed(0)}ms</p>
                        <p>Std Dev: ${stats.http2.stdDev.toFixed(0)}ms</p>
                    </div>
                    
                    <div class="protocol-stats">
                        <h5>HTTP/3 Statistics:</h5>
                        <p>Average: ${stats.http3.avg.toFixed(0)}ms</p>
                        <p>Min: ${stats.http3.min.toFixed(0)}ms</p>
                        <p>Max: ${stats.http3.max.toFixed(0)}ms</p>
                        <p>Std Dev: ${stats.http3.stdDev.toFixed(0)}ms</p>
                    </div>
                </div>
                
                <div class="summary-note">
                    <small>Multiple tests provide more reliable performance comparisons by reducing the impact of network variations.</small>
                </div>
            `;
            summaryElement.style.display = 'block';
        }
    }

    /**
     * Show success message
     */
    showSuccessMessage(message) {
        const notification = document.createElement('div');
        notification.className = 'success-notification';
        notification.innerHTML = `
            <div class="notification-content">
                <span class="success-icon">✅</span>
                <span class="notification-text">${message}</span>
                <button class="notification-close" onclick="this.parentElement.parentElement.remove()">×</button>
            </div>
        `;

        notification.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            background: #d4edda;
            border: 1px solid #c3e6cb;
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
     * Handle iframe loading with compatibility fallback
     */
    handleIframeLoadWithFallback(protocol, url) {
        const iframe = document.getElementById(`${protocol}Frame`);
        if (!iframe) return;

        // Check if we need to use fallback URL
        const compatibility = window.protocolCompatibility;
        if (protocol === 'http3' && compatibility?.fallbackActive) {
            // Redirect HTTP/3 to HTTP/2
            const fallbackUrl = url.replace(':8444', ':8443');
            console.log(`Using fallback URL for ${protocol}: ${fallbackUrl}`);
            iframe.src = fallbackUrl;
        } else {
            iframe.src = url;
        }
    }

    /**
     * Check if protocol is effectively supported
     */
    isProtocolEffectivelySupported(protocol) {
        const compatibility = window.protocolCompatibility;
        if (!compatibility) return false;

        if (protocol === 'http2') {
            return compatibility.http2;
        } else if (protocol === 'http3') {
            return compatibility.http3 === true && !compatibility.fallbackActive;
        }

        return false;
    }

    /**
     * Get effective protocol for testing
     */
    getEffectiveProtocol(requestedProtocol) {
        if (requestedProtocol === 'http3' && !this.isProtocolEffectivelySupported('http3')) {
            return 'http2'; // Fallback to HTTP/2
        }
        return requestedProtocol;
    }

    /**
     * Show protocol-specific warnings during tests
     */
    showProtocolWarnings() {
        const compatibility = window.protocolCompatibility;
        if (!compatibility) return;

        if (compatibility.fallbackActive) {
            this.showTemporaryMessage(
                'Running in fallback mode - HTTP/3 requests are being redirected to HTTP/2',
                'warning',
                3000
            );
        } else if (compatibility.http3 === 'limited') {
            this.showTemporaryMessage(
                'Limited HTTP/3 support detected - results may vary',
                'info',
                3000
            );
        }
    }

    /**
     * Show temporary message
     */
    showTemporaryMessage(message, type = 'info', duration = 3000) {
        const messageElement = document.createElement('div');
        messageElement.className = `temporary-message ${type}`;
        messageElement.textContent = message;
        
        messageElement.style.cssText = `
            position: fixed;
            bottom: 20px;
            left: 50%;
            transform: translateX(-50%);
            background: ${type === 'warning' ? '#fff3cd' : '#d1ecf1'};
            color: ${type === 'warning' ? '#856404' : '#0c5460'};
            padding: 0.75rem 1.5rem;
            border-radius: 6px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.15);
            z-index: 1000;
            font-size: 0.9rem;
            max-width: 400px;
            text-align: center;
        `;

        document.body.appendChild(messageElement);

        setTimeout(() => {
            if (messageElement.parentElement) {
                messageElement.remove();
            }
        }, duration);
    }

    /**
     * Get demo status
     */
    getStatus() {
        return {
            initialized: this.initialized,
            compatibility: window.protocolCompatibility,
            currentTest: this.performanceMeasurement?.currentTest,
            statistics: this.performanceMeasurement?.getStatistics(),
            networkSimulation: this.networkSimulation?.getSimulationState(),
            effectiveProtocols: {
                http2: this.isProtocolEffectivelySupported('http2'),
                http3: this.isProtocolEffectivelySupported('http3')
            }
        };
    }
}

// Initialize demo when page loads
document.addEventListener('DOMContentLoaded', () => {
    window.demoController = new DemoController();
});

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = DemoController;
}