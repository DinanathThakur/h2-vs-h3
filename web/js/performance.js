/**
 * Performance Measurement Module
 * Measures and compares HTTP/2 vs HTTP/3 performance metrics
 */

class PerformanceMeasurement {
    constructor() {
        this.measurements = {
            http2: [],
            http3: []
        };
        this.currentTest = null;
        this.testScenarios = this.initializeTestScenarios();
    }

    /**
     * Initialize test scenarios
     */
    initializeTestScenarios() {
        return {
            basic: {
                name: 'Basic Page Load',
                description: 'Simple HTML page with minimal resources',
                testUrl: 'test-basic.html',
                resources: ['styles.css', 'script.js']
            },
            images: {
                name: 'Multiple Images',
                description: 'Page with multiple images to test multiplexing',
                testUrl: 'test-images.html',
                resources: Array.from({length: 10}, (_, i) => `image-${i + 1}.jpg`)
            },
            mixed: {
                name: 'Mixed Resources',
                description: 'Page with various resource types',
                testUrl: 'test-mixed.html',
                resources: ['styles.css', 'script.js', 'data.json', 'font.woff2', 'image.jpg']
            },
            'network-simulation': {
                name: 'Network Simulation Test',
                description: 'Comprehensive test page for network simulation features',
                testUrl: 'test-network-simulation.html',
                resources: Array.from({length: 10}, (_, i) => `small-${i + 1}.svg`).concat(['small.css', 'medium.css', 'large.css', 'small.js', 'medium.js', 'large.js', 'test-data.json'])
            }
        };
    }

    /**
     * Start performance test for both protocols
     */
    async startTest(scenario = 'basic') {
        this.currentTest = {
            scenario,
            startTime: performance.now(),
            results: {}
        };

        // Update UI to show testing state
        this.updateTestingUI(true);

        try {
            // Test HTTP/2
            const http2Result = await this.testProtocol('http2', scenario);
            this.currentTest.results.http2 = http2Result;
            this.updateProtocolMetrics('http2', http2Result);

            // Test HTTP/3
            const http3Result = await this.testProtocol('http3', scenario);
            this.currentTest.results.http3 = http3Result;
            this.updateProtocolMetrics('http3', http3Result);

            // Store results
            this.measurements.http2.push(http2Result);
            this.measurements.http3.push(http3Result);

            // Show comparison
            this.showComparison();

        } catch (error) {
            console.error('Performance test failed:', error);
            this.showError(error.message);
        } finally {
            this.updateTestingUI(false);
        }
    }

    /**
     * Test a specific protocol
     */
    async testProtocol(protocol, scenario) {
        const port = protocol === 'http2' ? '8443' : '8444';
        const baseUrl = `https://localhost:${port}`;
        const testUrl = `${baseUrl}/${this.testScenarios[scenario].testUrl}`;

        const startTime = performance.now();
        const result = {
            protocol,
            scenario,
            startTime,
            loadTime: 0,
            connectionTime: 0,
            firstByteTime: 0,
            resourceCount: 0,
            totalSize: 0,
            resources: [],
            errors: [],
            realTimeMetrics: []
        };

        try {
            // Update iframe and measure loading
            const iframe = document.getElementById(`${protocol}Frame`);
            const loadingOverlay = document.getElementById(`${protocol}Loading`);
            
            // Show loading state
            loadingOverlay.classList.add('active');
            this.updateProtocolStatus(protocol, 'loading', 'Connecting...');

            // Start real-time monitoring
            const monitoringInterval = this.startRealTimeMonitoring(protocol, result, startTime);

            // Measure connection and first byte time
            const connectionStart = performance.now();
            this.updateProtocolStatus(protocol, 'loading', 'Loading page...');
            
            // Load the test page in iframe
            await this.loadIframe(iframe, testUrl);
            
            const loadEnd = performance.now();
            result.loadTime = loadEnd - startTime;
            result.connectionTime = loadEnd - connectionStart;

            // Stop real-time monitoring
            clearInterval(monitoringInterval);

            // Update status for resource measurement
            this.updateProtocolStatus(protocol, 'loading', 'Measuring resources...');

            // Measure resource loading if possible
            await this.measureResources(iframe, result);

            // Update status
            this.updateProtocolStatus(protocol, 'success', 'Complete');
            
        } catch (error) {
            result.errors.push(error.message);
            this.updateProtocolStatus(protocol, 'error', 'Error');
            console.error(`${protocol} test failed:`, error);
        } finally {
            // Hide loading state
            const loadingOverlay = document.getElementById(`${protocol}Loading`);
            loadingOverlay.classList.remove('active');
        }

        return result;
    }

    /**
     * Start real-time monitoring during test
     */
    startRealTimeMonitoring(protocol, result, startTime) {
        let lastUpdate = startTime;
        
        return setInterval(() => {
            const currentTime = performance.now();
            const elapsed = currentTime - startTime;
            
            // Update real-time metrics
            result.realTimeMetrics.push({
                timestamp: currentTime,
                elapsed: elapsed,
                memoryUsage: this.getMemoryUsage()
            });

            // Update UI with current elapsed time
            const loadTimeElement = document.getElementById(`${protocol}LoadTime`);
            if (loadTimeElement) {
                loadTimeElement.textContent = `${elapsed.toFixed(0)}ms`;
            }

            // Update status with progress
            if (elapsed < 1000) {
                this.updateProtocolStatus(protocol, 'loading', `Loading... ${elapsed.toFixed(0)}ms`);
            } else {
                this.updateProtocolStatus(protocol, 'loading', `Loading... ${(elapsed/1000).toFixed(1)}s`);
            }

            lastUpdate = currentTime;
        }, 100); // Update every 100ms
    }

    /**
     * Get memory usage if available
     */
    getMemoryUsage() {
        if (performance.memory) {
            return {
                used: performance.memory.usedJSHeapSize,
                total: performance.memory.totalJSHeapSize,
                limit: performance.memory.jsHeapSizeLimit
            };
        }
        return null;
    }

    /**
     * Load iframe and measure timing
     */
    loadIframe(iframe, url) {
        return new Promise((resolve, reject) => {
            const timeout = setTimeout(() => {
                reject(new Error('Load timeout'));
            }, 10000);

            const onLoad = () => {
                clearTimeout(timeout);
                iframe.removeEventListener('load', onLoad);
                iframe.removeEventListener('error', onError);
                resolve();
            };

            const onError = () => {
                clearTimeout(timeout);
                iframe.removeEventListener('load', onLoad);
                iframe.removeEventListener('error', onError);
                reject(new Error('Failed to load'));
            };

            iframe.addEventListener('load', onLoad);
            iframe.addEventListener('error', onError);
            iframe.src = url;
        });
    }

    /**
     * Measure resource loading within iframe
     */
    async measureResources(iframe, result) {
        try {
            // Try to access iframe's performance data
            // Note: This may be limited by CORS policies
            const iframeWindow = iframe.contentWindow;
            if (iframeWindow && iframeWindow.performance) {
                const entries = iframeWindow.performance.getEntriesByType('resource');
                const navigationEntries = iframeWindow.performance.getEntriesByType('navigation');
                
                result.resourceCount = entries.length;
                result.resources = entries.map(entry => ({
                    name: entry.name,
                    duration: entry.duration,
                    size: entry.transferSize || entry.encodedBodySize || 0,
                    type: this.getResourceType(entry.name),
                    startTime: entry.startTime,
                    responseEnd: entry.responseEnd,
                    connectStart: entry.connectStart,
                    connectEnd: entry.connectEnd
                }));
                
                result.totalSize = result.resources.reduce((sum, resource) => sum + resource.size, 0);
                
                // Get more detailed timing from navigation entry
                if (navigationEntries.length > 0) {
                    const nav = navigationEntries[0];
                    result.connectionTime = nav.connectEnd - nav.connectStart;
                    result.firstByteTime = nav.responseStart - nav.requestStart;
                    result.domContentLoaded = nav.domContentLoadedEventEnd - nav.domContentLoadedEventStart;
                    result.domComplete = nav.domComplete - nav.navigationStart;
                }
                
                // Listen for postMessage from iframe for additional metrics
                this.setupIframeMessageListener(result);
            }
        } catch (error) {
            // CORS or other access issues - this is expected
            console.warn('Could not access iframe performance data:', error.message);
            
            // Fallback: estimate based on load time
            result.resourceCount = this.estimateResourceCount(result.scenario);
            result.firstByteTime = result.loadTime * 0.3; // Estimate
            result.connectionTime = result.loadTime * 0.1; // Estimate
        }
    }

    /**
     * Get resource type from URL
     */
    getResourceType(url) {
        const extension = url.split('.').pop().toLowerCase();
        const typeMap = {
            'html': 'document',
            'css': 'stylesheet',
            'js': 'script',
            'jpg': 'image',
            'jpeg': 'image',
            'png': 'image',
            'gif': 'image',
            'svg': 'image',
            'webp': 'image',
            'woff': 'font',
            'woff2': 'font',
            'ttf': 'font',
            'otf': 'font',
            'json': 'xhr',
            'xml': 'xhr',
            'txt': 'other'
        };
        return typeMap[extension] || 'other';
    }

    /**
     * Setup iframe message listener for additional metrics
     */
    setupIframeMessageListener(result) {
        const messageHandler = (event) => {
            if (event.data && event.data.type === 'pageLoaded') {
                // Update result with data from iframe
                if (event.data.loadTime) {
                    result.iframeLoadTime = event.data.loadTime;
                }
                if (event.data.resourceCount) {
                    result.resourceCount = Math.max(result.resourceCount, event.data.resourceCount);
                }
                if (event.data.resources) {
                    result.iframeResources = event.data.resources;
                }
                
                // Remove listener after receiving data
                window.removeEventListener('message', messageHandler);
            }
        };
        
        window.addEventListener('message', messageHandler);
        
        // Clean up listener after timeout
        setTimeout(() => {
            window.removeEventListener('message', messageHandler);
        }, 5000);
    }

    /**
     * Estimate resource count based on scenario
     */
    estimateResourceCount(scenario) {
        const estimates = {
            'basic': 3,
            'images': 12,
            'mixed': 6
        };
        return estimates[scenario] || 3;
    }

    /**
     * Update protocol status indicator
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
     * Update protocol metrics display
     */
    updateProtocolMetrics(protocol, result) {
        const loadTimeElement = document.getElementById(`${protocol}LoadTime`);
        const connectionElement = document.getElementById(`${protocol}Connection`);
        const firstByteElement = document.getElementById(`${protocol}FirstByte`);

        if (loadTimeElement) {
            loadTimeElement.textContent = `${result.loadTime.toFixed(0)}ms`;
        }
        if (connectionElement) {
            connectionElement.textContent = `${result.connectionTime.toFixed(0)}ms`;
        }
        if (firstByteElement) {
            firstByteElement.textContent = `${result.firstByteTime.toFixed(0)}ms`;
        }

        // Update additional metrics if available
        this.updateAdditionalMetrics(protocol, result);
    }

    /**
     * Update additional metrics display
     */
    updateAdditionalMetrics(protocol, result) {
        // Update resource count
        const resourceCountElement = document.getElementById(`${protocol}ResourceCount`);
        if (resourceCountElement) {
            resourceCountElement.textContent = result.resourceCount || 0;
        }

        // Update total size
        const totalSizeElement = document.getElementById(`${protocol}TotalSize`);
        if (totalSizeElement) {
            const sizeInKB = (result.totalSize / 1024).toFixed(1);
            totalSizeElement.textContent = `${sizeInKB} KB`;
        }

        // Update DOM metrics if available
        if (result.domContentLoaded) {
            const domElement = document.getElementById(`${protocol}DOMLoaded`);
            if (domElement) {
                domElement.textContent = `${result.domContentLoaded.toFixed(0)}ms`;
            }
        }

        // Show real-time resource loading progress
        this.updateResourceProgress(protocol, result);
    }

    /**
     * Update resource loading progress
     */
    updateResourceProgress(protocol, result) {
        const progressElement = document.getElementById(`${protocol}Progress`);
        if (!progressElement) return;

        if (result.resources && result.resources.length > 0) {
            const resourceList = result.resources
                .sort((a, b) => a.responseEnd - b.responseEnd)
                .slice(0, 5) // Show top 5 resources
                .map(resource => {
                    const name = resource.name.split('/').pop() || 'Unknown';
                    const size = resource.size ? `(${(resource.size / 1024).toFixed(1)}KB)` : '';
                    const duration = `${resource.duration.toFixed(0)}ms`;
                    return `<div class="resource-item">${name} ${size} - ${duration}</div>`;
                })
                .join('');

            progressElement.innerHTML = `
                <div class="resource-progress">
                    <h4>Resource Loading:</h4>
                    ${resourceList}
                    ${result.resources.length > 5 ? `<div class="more-resources">... and ${result.resources.length - 5} more</div>` : ''}
                </div>
            `;
        }
    }

    /**
     * Update testing UI state
     */
    updateTestingUI(testing) {
        const startButton = document.getElementById('startTest');
        const resetButton = document.getElementById('resetTest');
        const scenarioSelect = document.getElementById('testScenario');

        if (startButton) {
            startButton.disabled = testing;
            startButton.textContent = testing ? 'Testing...' : 'Start Performance Test';
        }
        if (resetButton) {
            resetButton.disabled = testing;
        }
        if (scenarioSelect) {
            scenarioSelect.disabled = testing;
        }
    }

    /**
     * Show comparison results
     */
    showComparison() {
        if (!this.currentTest || !this.currentTest.results.http2 || !this.currentTest.results.http3) {
            return;
        }

        const http2Result = this.currentTest.results.http2;
        const http3Result = this.currentTest.results.http3;

        // Compare load times
        const http2Faster = http2Result.loadTime < http3Result.loadTime;
        const timeDiff = Math.abs(http2Result.loadTime - http3Result.loadTime);
        const percentDiff = ((timeDiff / Math.max(http2Result.loadTime, http3Result.loadTime)) * 100).toFixed(1);

        // Update metric styling
        this.updateMetricComparison('LoadTime', http2Result.loadTime, http3Result.loadTime);
        this.updateMetricComparison('Connection', http2Result.connectionTime, http3Result.connectionTime);

        // Show results summary
        this.showResultsSummary(http2Result, http3Result, { http2Faster, timeDiff, percentDiff });
    }

    /**
     * Update metric comparison styling
     */
    updateMetricComparison(metric, http2Value, http3Value) {
        const http2Element = document.getElementById(`http2${metric}`);
        const http3Element = document.getElementById(`http3${metric}`);

        if (http2Element && http3Element) {
            // Remove existing classes
            http2Element.classList.remove('faster', 'slower');
            http3Element.classList.remove('faster', 'slower');

            // Add comparison classes
            if (http2Value < http3Value) {
                http2Element.classList.add('faster');
                http3Element.classList.add('slower');
            } else if (http3Value < http2Value) {
                http3Element.classList.add('faster');
                http2Element.classList.add('slower');
            }
        }
    }

    /**
     * Show results summary
     */
    showResultsSummary(http2Result, http3Result, comparison) {
        const summaryElement = document.getElementById('resultsSummary');
        const contentElement = document.getElementById('summaryContent');

        if (!summaryElement || !contentElement) return;

        const winner = comparison.http2Faster ? 'HTTP/2' : 'HTTP/3';
        const loser = comparison.http2Faster ? 'HTTP/3' : 'HTTP/2';

        // Calculate additional metrics
        const http2Throughput = http2Result.totalSize / (http2Result.loadTime / 1000); // bytes per second
        const http3Throughput = http3Result.totalSize / (http3Result.loadTime / 1000);
        const throughputDiff = Math.abs(http2Throughput - http3Throughput);
        const throughputWinner = http2Throughput > http3Throughput ? 'HTTP/2' : 'HTTP/3';

        contentElement.innerHTML = `
            <div class="summary-header">
                <h4>Performance Comparison Results</h4>
            </div>
            
            <div class="summary-winner">
                <strong>${winner}</strong> was faster by <strong>${comparison.timeDiff.toFixed(0)}ms</strong> 
                (${comparison.percentDiff}% improvement)
            </div>
            
            <div class="summary-metrics">
                <div class="metric-comparison">
                    <div class="metric-row">
                        <span class="metric-name">Load Time:</span>
                        <span class="metric-http2 ${comparison.http2Faster ? 'winner' : ''}">${http2Result.loadTime.toFixed(0)}ms</span>
                        <span class="metric-http3 ${!comparison.http2Faster ? 'winner' : ''}">${http3Result.loadTime.toFixed(0)}ms</span>
                    </div>
                    <div class="metric-row">
                        <span class="metric-name">Connection Time:</span>
                        <span class="metric-http2">${http2Result.connectionTime.toFixed(0)}ms</span>
                        <span class="metric-http3">${http3Result.connectionTime.toFixed(0)}ms</span>
                    </div>
                    <div class="metric-row">
                        <span class="metric-name">First Byte:</span>
                        <span class="metric-http2">${http2Result.firstByteTime.toFixed(0)}ms</span>
                        <span class="metric-http3">${http3Result.firstByteTime.toFixed(0)}ms</span>
                    </div>
                    <div class="metric-row">
                        <span class="metric-name">Resources:</span>
                        <span class="metric-http2">${http2Result.resourceCount}</span>
                        <span class="metric-http3">${http3Result.resourceCount}</span>
                    </div>
                    <div class="metric-row">
                        <span class="metric-name">Total Size:</span>
                        <span class="metric-http2">${(http2Result.totalSize / 1024).toFixed(1)} KB</span>
                        <span class="metric-http3">${(http3Result.totalSize / 1024).toFixed(1)} KB</span>
                    </div>
                    ${http2Result.totalSize > 0 && http3Result.totalSize > 0 ? `
                    <div class="metric-row">
                        <span class="metric-name">Throughput:</span>
                        <span class="metric-http2 ${throughputWinner === 'HTTP/2' ? 'winner' : ''}">${(http2Throughput / 1024).toFixed(1)} KB/s</span>
                        <span class="metric-http3 ${throughputWinner === 'HTTP/3' ? 'winner' : ''}">${(http3Throughput / 1024).toFixed(1)} KB/s</span>
                    </div>
                    ` : ''}
                </div>
            </div>
            
            <div class="summary-insights">
                <h5>Key Insights:</h5>
                <ul>
                    ${this.generateInsights(http2Result, http3Result, comparison)}
                </ul>
            </div>
            
            <div class="summary-note">
                <small>Results may vary based on network conditions, server configuration, and browser implementation. 
                Run multiple tests for more reliable comparisons.</small>
            </div>
        `;

        summaryElement.style.display = 'block';
    }

    /**
     * Generate insights based on test results
     */
    generateInsights(http2Result, http3Result, comparison) {
        const insights = [];

        // Connection time insights
        if (Math.abs(http2Result.connectionTime - http3Result.connectionTime) > 50) {
            const fasterConnection = http2Result.connectionTime < http3Result.connectionTime ? 'HTTP/2' : 'HTTP/3';
            insights.push(`<li>${fasterConnection} established connection ${Math.abs(http2Result.connectionTime - http3Result.connectionTime).toFixed(0)}ms faster</li>`);
        }

        // Resource loading insights
        if (http2Result.resourceCount > 5 || http3Result.resourceCount > 5) {
            insights.push(`<li>Multiple resources loaded - multiplexing benefits should be visible</li>`);
        }

        // Size-based insights
        if (http2Result.totalSize > 100 * 1024 || http3Result.totalSize > 100 * 1024) { // > 100KB
            insights.push(`<li>Large payload size - compression and transfer efficiency matter</li>`);
        }

        // Performance difference insights
        if (comparison.percentDiff > 20) {
            insights.push(`<li>Significant performance difference (${comparison.percentDiff}%) - protocol choice matters for this scenario</li>`);
        } else if (comparison.percentDiff < 5) {
            insights.push(`<li>Similar performance (${comparison.percentDiff}% difference) - both protocols perform well for this scenario</li>`);
        }

        // Error insights
        if (http2Result.errors.length > 0 || http3Result.errors.length > 0) {
            insights.push(`<li>Connection issues detected - check server configuration</li>`);
        }

        return insights.join('');
    }

    /**
     * Show error message
     */
    showError(message) {
        const summaryElement = document.getElementById('resultsSummary');
        const contentElement = document.getElementById('summaryContent');

        if (summaryElement && contentElement) {
            contentElement.innerHTML = `
                <div class="error-message">
                    <strong>Test Error:</strong> ${message}
                    <br><small>Please ensure both servers are running and accessible.</small>
                </div>
            `;
            summaryElement.style.display = 'block';
        }
    }

    /**
     * Reset test results
     */
    resetTest() {
        // Clear iframes
        const http2Frame = document.getElementById('http2Frame');
        const http3Frame = document.getElementById('http3Frame');
        
        if (http2Frame) http2Frame.src = 'about:blank';
        if (http3Frame) http3Frame.src = 'about:blank';

        // Reset metrics
        ['http2', 'http3'].forEach(protocol => {
            this.updateProtocolMetrics(protocol, {
                loadTime: 0,
                connectionTime: 0,
                firstByteTime: 0,
                resourceCount: 0,
                totalSize: 0
            });
            this.updateProtocolStatus(protocol, '', 'Ready');
            
            // Clear metric styling
            ['LoadTime', 'Connection', 'FirstByte', 'ResourceCount', 'TotalSize'].forEach(metric => {
                const element = document.getElementById(`${protocol}${metric}`);
                if (element) {
                    element.classList.remove('faster', 'slower', 'winner');
                    element.textContent = '-';
                }
            });

            // Clear progress displays
            const progressElement = document.getElementById(`${protocol}Progress`);
            if (progressElement) {
                progressElement.innerHTML = '';
            }
        });

        // Hide results
        const summaryElement = document.getElementById('resultsSummary');
        if (summaryElement) {
            summaryElement.style.display = 'none';
        }

        this.currentTest = null;
        console.log('Performance test reset');
    }

    /**
     * Get performance statistics
     */
    getStatistics() {
        const http2Stats = this.calculateStats(this.measurements.http2);
        const http3Stats = this.calculateStats(this.measurements.http3);

        return {
            http2: http2Stats,
            http3: http3Stats,
            totalTests: this.measurements.http2.length
        };
    }

    /**
     * Calculate statistics for measurements
     */
    calculateStats(measurements) {
        if (measurements.length === 0) {
            return { avg: 0, min: 0, max: 0, count: 0, stdDev: 0 };
        }

        const loadTimes = measurements.map(m => m.loadTime);
        const avg = loadTimes.reduce((a, b) => a + b, 0) / loadTimes.length;
        const variance = loadTimes.reduce((sum, time) => sum + Math.pow(time - avg, 2), 0) / loadTimes.length;
        
        return {
            avg: avg,
            min: Math.min(...loadTimes),
            max: Math.max(...loadTimes),
            count: measurements.length,
            stdDev: Math.sqrt(variance)
        };
    }

    /**
     * Export test results for analysis
     */
    exportResults() {
        const results = {
            timestamp: new Date().toISOString(),
            currentTest: this.currentTest,
            measurements: this.measurements,
            statistics: this.getStatistics(),
            testScenarios: this.testScenarios,
            browserInfo: {
                userAgent: navigator.userAgent,
                platform: navigator.platform,
                language: navigator.language,
                cookieEnabled: navigator.cookieEnabled,
                onLine: navigator.onLine
            }
        };

        // Create downloadable JSON file
        const dataStr = JSON.stringify(results, null, 2);
        const dataBlob = new Blob([dataStr], { type: 'application/json' });
        const url = URL.createObjectURL(dataBlob);
        
        const link = document.createElement('a');
        link.href = url;
        link.download = `http-performance-test-${new Date().toISOString().slice(0, 19).replace(/:/g, '-')}.json`;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(url);

        console.log('Test results exported');
        return results;
    }

    /**
     * Import test results from file
     */
    importResults(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = (e) => {
                try {
                    const results = JSON.parse(e.target.result);
                    
                    // Validate structure
                    if (results.measurements && results.measurements.http2 && results.measurements.http3) {
                        this.measurements = results.measurements;
                        console.log('Test results imported successfully');
                        resolve(results);
                    } else {
                        reject(new Error('Invalid results file format'));
                    }
                } catch (error) {
                    reject(new Error('Failed to parse results file'));
                }
            };
            reader.onerror = () => reject(new Error('Failed to read file'));
            reader.readAsText(file);
        });
    }
}

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = PerformanceMeasurement;
}