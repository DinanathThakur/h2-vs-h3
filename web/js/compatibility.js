/**
 * Browser Compatibility Detection Module
 * Detects HTTP/2 and HTTP/3 support in the current browser
 */

class CompatibilityChecker {
    constructor() {
        this.http2Support = false;
        this.http3Support = false;
        this.quicSupport = false;
        this.browserInfo = this.getBrowserInfo();
        this.fallbackActive = false;
        this.notificationsShown = new Set();
        
        this.init();
    }

    /**
     * Initialize compatibility checks
     */
    init() {
        this.checkHTTP2Support();
        this.checkHTTP3Support();
        this.setupFallbackMechanisms();
        this.updateUI();
        this.showCompatibilityNotifications();
    }

    /**
     * Get browser information
     */
    getBrowserInfo() {
        const ua = navigator.userAgent;
        let browser = 'Unknown';
        let version = 'Unknown';

        // Chrome/Chromium
        if (ua.includes('Chrome/') && !ua.includes('Edg/')) {
            browser = 'Chrome';
            version = ua.match(/Chrome\/(\d+)/)?.[1] || 'Unknown';
        }
        // Edge
        else if (ua.includes('Edg/')) {
            browser = 'Edge';
            version = ua.match(/Edg\/(\d+)/)?.[1] || 'Unknown';
        }
        // Firefox
        else if (ua.includes('Firefox/')) {
            browser = 'Firefox';
            version = ua.match(/Firefox\/(\d+)/)?.[1] || 'Unknown';
        }
        // Safari
        else if (ua.includes('Safari/') && !ua.includes('Chrome/')) {
            browser = 'Safari';
            version = ua.match(/Version\/(\d+)/)?.[1] || 'Unknown';
        }

        return { browser, version };
    }

    /**
     * Check HTTP/2 support
     */
    checkHTTP2Support() {
        // HTTP/2 is widely supported in modern browsers
        // Check for basic features that indicate HTTP/2 support
        this.http2Support = (
            'fetch' in window &&
            'Promise' in window &&
            'TextEncoder' in window
        );

        // Additional check for specific HTTP/2 indicators
        if (this.http2Support) {
            // Most modern browsers support HTTP/2
            const { browser, version } = this.browserInfo;
            
            if (browser === 'Chrome' && parseInt(version) >= 40) this.http2Support = true;
            else if (browser === 'Firefox' && parseInt(version) >= 36) this.http2Support = true;
            else if (browser === 'Safari' && parseInt(version) >= 9) this.http2Support = true;
            else if (browser === 'Edge' && parseInt(version) >= 12) this.http2Support = true;
        }
    }

    /**
     * Check HTTP/3 support
     */
    checkHTTP3Support() {
        const { browser, version } = this.browserInfo;
        
        // Chrome/Chromium HTTP/3 support
        if (browser === 'Chrome' && parseInt(version) >= 87) {
            this.http3Support = true;
            this.quicSupport = true;
        }
        // Edge HTTP/3 support
        else if (browser === 'Edge' && parseInt(version) >= 87) {
            this.http3Support = true;
            this.quicSupport = true;
        }
        // Firefox HTTP/3 support (requires flag in older versions)
        else if (browser === 'Firefox') {
            if (parseInt(version) >= 88) {
                this.http3Support = true;
                this.quicSupport = true;
            } else if (parseInt(version) >= 72) {
                // Older Firefox versions need manual enabling
                this.http3Support = 'requires-flag';
                this.quicSupport = 'requires-flag';
            }
        }
        // Safari has limited HTTP/3 support
        else if (browser === 'Safari') {
            if (parseInt(version) >= 14) {
                this.http3Support = 'limited';
                this.quicSupport = 'limited';
            }
        }

        // Additional runtime check for HTTP/3
        this.performRuntimeHTTP3Check();
    }

    /**
     * Perform runtime HTTP/3 check
     */
    async performRuntimeHTTP3Check() {
        try {
            // Check if the browser can handle HTTP/3 requests
            // This is a basic check - actual HTTP/3 negotiation happens at the network level
            if ('serviceWorker' in navigator && 'fetch' in window) {
                // Modern browsers with service worker support are more likely to support HTTP/3
                const connection = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
                if (connection) {
                    // Additional network API checks
                    this.networkInfo = {
                        effectiveType: connection.effectiveType,
                        downlink: connection.downlink,
                        rtt: connection.rtt
                    };
                }
            }

            // Test actual HTTP/3 connectivity if possible
            await this.testHTTP3Connectivity();
        } catch (error) {
            console.warn('Runtime HTTP/3 check failed:', error);
        }
    }

    /**
     * Test HTTP/3 connectivity
     */
    async testHTTP3Connectivity() {
        try {
            // Attempt to detect HTTP/3 support by checking for QUIC-related features
            const hasQuicSupport = this.detectQuicFeatures();
            
            if (!hasQuicSupport && this.http3Support === true) {
                // Downgrade support level if runtime check fails
                this.http3Support = 'limited';
                console.warn('HTTP/3 support detected but QUIC features not available');
            }
        } catch (error) {
            console.warn('HTTP/3 connectivity test failed:', error);
        }
    }

    /**
     * Detect QUIC-related browser features
     */
    detectQuicFeatures() {
        // Check for features that indicate good HTTP/3/QUIC support
        const features = {
            webTransport: 'WebTransport' in window,
            webRTC: 'RTCPeerConnection' in window,
            streams: 'ReadableStream' in window && 'WritableStream' in window,
            crypto: 'crypto' in window && 'subtle' in crypto
        };

        // Count available features
        const availableFeatures = Object.values(features).filter(Boolean).length;
        
        // Store feature info
        this.quicFeatures = features;
        
        // Return true if most features are available
        return availableFeatures >= 3;
    }

    /**
     * Setup fallback mechanisms for unsupported browsers
     */
    setupFallbackMechanisms() {
        // Setup HTTP/3 fallback
        if (!this.http3Support || this.http3Support === 'limited' || this.http3Support === 'requires-flag') {
            this.setupHTTP3Fallback();
        }

        // Setup HTTP/2 fallback (rare case)
        if (!this.http2Support) {
            this.setupHTTP2Fallback();
        }

        // Setup general compatibility fallbacks
        this.setupGeneralFallbacks();
    }

    /**
     * Setup HTTP/3 fallback mechanisms
     */
    setupHTTP3Fallback() {
        this.fallbackActive = true;
        
        // Override HTTP/3 URLs to use HTTP/2 endpoints
        this.originalFetch = window.fetch;
        window.fetch = this.createFallbackFetch();

        // Modify iframe sources to use HTTP/2 ports
        this.setupIframeFallback();

        console.log('HTTP/3 fallback mechanisms activated');
    }

    /**
     * Create fallback fetch function
     */
    createFallbackFetch() {
        const originalFetch = this.originalFetch;
        
        return async (input, init = {}) => {
            try {
                // Convert HTTP/3 URLs to HTTP/2 equivalents
                let url = typeof input === 'string' ? input : input.url;
                
                if (url.includes(':8444')) {
                    url = url.replace(':8444', ':8443');
                    console.log(`Fallback: Redirecting HTTP/3 request to HTTP/2: ${url}`);
                }

                const modifiedInput = typeof input === 'string' ? url : 
                    new Request(url, input);

                return await originalFetch(modifiedInput, init);
            } catch (error) {
                console.warn('Fallback fetch failed:', error);
                throw error;
            }
        };
    }

    /**
     * Setup iframe fallback for HTTP/3
     */
    setupIframeFallback() {
        // Monitor iframe src changes and redirect HTTP/3 to HTTP/2
        const observer = new MutationObserver((mutations) => {
            mutations.forEach((mutation) => {
                if (mutation.type === 'attributes' && mutation.attributeName === 'src') {
                    const iframe = mutation.target;
                    if (iframe.src && iframe.src.includes(':8444')) {
                        const fallbackSrc = iframe.src.replace(':8444', ':8443');
                        console.log(`Fallback: Redirecting iframe from HTTP/3 to HTTP/2`);
                        iframe.src = fallbackSrc;
                    }
                }
            });
        });

        // Observe all iframes
        document.querySelectorAll('iframe').forEach(iframe => {
            observer.observe(iframe, { attributes: true });
        });

        // Store observer for cleanup
        this.iframeObserver = observer;
    }

    /**
     * Setup HTTP/2 fallback (for very old browsers)
     */
    setupHTTP2Fallback() {
        console.warn('HTTP/2 not supported - implementing basic fallbacks');
        
        // Add polyfills or alternative implementations if needed
        this.addHTTP2Polyfills();
    }

    /**
     * Add HTTP/2 polyfills for older browsers
     */
    addHTTP2Polyfills() {
        // Add fetch polyfill if needed
        if (!window.fetch) {
            console.warn('Fetch API not available - consider adding a polyfill');
        }

        // Add Promise polyfill if needed
        if (!window.Promise) {
            console.warn('Promise not available - consider adding a polyfill');
        }
    }

    /**
     * Setup general compatibility fallbacks
     */
    setupGeneralFallbacks() {
        // Handle missing modern JavaScript features
        this.addModernJSFallbacks();
        
        // Setup error handling for compatibility issues
        this.setupCompatibilityErrorHandling();
    }

    /**
     * Add fallbacks for modern JavaScript features
     */
    addModernJSFallbacks() {
        // Add Array.from polyfill if needed
        if (!Array.from) {
            Array.from = function(arrayLike) {
                return Array.prototype.slice.call(arrayLike);
            };
        }

        // Add Object.assign polyfill if needed
        if (!Object.assign) {
            Object.assign = function(target, ...sources) {
                sources.forEach(source => {
                    if (source) {
                        Object.keys(source).forEach(key => {
                            target[key] = source[key];
                        });
                    }
                });
                return target;
            };
        }
    }

    /**
     * Setup error handling for compatibility issues
     */
    setupCompatibilityErrorHandling() {
        // Global error handler for compatibility issues
        window.addEventListener('error', (event) => {
            if (this.isCompatibilityError(event.error)) {
                console.warn('Compatibility error detected:', event.error);
                this.handleCompatibilityError(event.error);
            }
        });

        // Unhandled promise rejection handler
        window.addEventListener('unhandledrejection', (event) => {
            if (this.isCompatibilityError(event.reason)) {
                console.warn('Compatibility promise rejection:', event.reason);
                this.handleCompatibilityError(event.reason);
            }
        });
    }

    /**
     * Check if an error is compatibility-related
     */
    isCompatibilityError(error) {
        if (!error) return false;
        
        const compatibilityKeywords = [
            'http/3', 'quic', 'protocol', 'connection',
            'fetch', 'promise', 'async', 'await'
        ];

        const errorMessage = error.message || error.toString();
        return compatibilityKeywords.some(keyword => 
            errorMessage.toLowerCase().includes(keyword)
        );
    }

    /**
     * Handle compatibility errors
     */
    handleCompatibilityError(error) {
        // Show user-friendly error message
        this.showCompatibilityError(error);
        
        // Attempt automatic recovery
        this.attemptErrorRecovery(error);
    }

    /**
     * Show compatibility error to user
     */
    showCompatibilityError(error) {
        const message = `
            <div class="compatibility-error">
                <strong>Compatibility Issue:</strong> ${error.message || 'Unknown error'}
                <br><small>The demo will attempt to use fallback mechanisms.</small>
            </div>
        `;

        this.showNotification(message, 'error', 8000);
    }

    /**
     * Attempt to recover from compatibility errors
     */
    attemptErrorRecovery(error) {
        // Force fallback mode if not already active
        if (!this.fallbackActive) {
            console.log('Activating fallback mode due to error');
            this.setupHTTP3Fallback();
        }

        // Refresh compatibility status
        setTimeout(() => {
            this.updateUI();
        }, 1000);
    }

    /**
     * Show compatibility notifications
     */
    showCompatibilityNotifications() {
        // Show HTTP/3 specific notifications
        if (this.http3Support === 'requires-flag') {
            this.showFirefoxHTTP3Instructions();
        } else if (this.http3Support === 'limited') {
            this.showLimitedHTTP3Warning();
        } else if (!this.http3Support) {
            this.showHTTP3UnsupportedNotification();
        }

        // Show general browser recommendations
        this.showBrowserRecommendations();
    }

    /**
     * Show Firefox HTTP/3 enabling instructions
     */
    showFirefoxHTTP3Instructions() {
        if (this.notificationsShown.has('firefox-http3')) return;
        
        const message = `
            <div class="firefox-instructions">
                <strong>Enable HTTP/3 in Firefox:</strong>
                <ol>
                    <li>Type <code>about:config</code> in the address bar</li>
                    <li>Search for <code>network.http.http3.enabled</code></li>
                    <li>Set the value to <code>true</code></li>
                    <li>Restart Firefox and reload this page</li>
                </ol>
                <button onclick="this.parentElement.parentElement.remove()" class="instruction-dismiss">Got it</button>
            </div>
        `;

        this.showNotification(message, 'info', 0); // Persistent
        this.notificationsShown.add('firefox-http3');
    }

    /**
     * Show limited HTTP/3 support warning
     */
    showLimitedHTTP3Warning() {
        if (this.notificationsShown.has('limited-http3')) return;

        const message = `
            <div class="limited-support-warning">
                <strong>Limited HTTP/3 Support:</strong> Your browser has partial HTTP/3 support. 
                Some features may fall back to HTTP/2 automatically.
                <br><small>Consider using Chrome or Firefox for the best experience.</small>
            </div>
        `;

        this.showNotification(message, 'warning', 7000);
        this.notificationsShown.add('limited-http3');
    }

    /**
     * Show HTTP/3 unsupported notification
     */
    showHTTP3UnsupportedNotification() {
        if (this.notificationsShown.has('no-http3')) return;

        const message = `
            <div class="unsupported-notification">
                <strong>HTTP/3 Not Supported:</strong> Your browser doesn't support HTTP/3. 
                The demo will use HTTP/2 for both comparisons.
                <br><small>Upgrade to a modern browser to see HTTP/3 in action.</small>
            </div>
        `;

        this.showNotification(message, 'warning', 6000);
        this.notificationsShown.add('no-http3');
    }

    /**
     * Show browser recommendations
     */
    showBrowserRecommendations() {
        const { browser, version } = this.browserInfo;
        
        // Show upgrade recommendations for older browsers
        if (browser === 'Chrome' && parseInt(version) < 87) {
            this.showBrowserUpgradeNotification('Chrome', '87+');
        } else if (browser === 'Firefox' && parseInt(version) < 88) {
            this.showBrowserUpgradeNotification('Firefox', '88+');
        } else if (browser === 'Safari') {
            this.showSafariLimitations();
        }
    }

    /**
     * Show browser upgrade notification
     */
    showBrowserUpgradeNotification(browserName, recommendedVersion) {
        if (this.notificationsShown.has('upgrade-browser')) return;

        const message = `
            <div class="upgrade-notification">
                <strong>Browser Update Recommended:</strong> 
                For the best HTTP/3 experience, please update ${browserName} to version ${recommendedVersion}.
                <br><small>Your current version may have limited protocol support.</small>
            </div>
        `;

        this.showNotification(message, 'info', 8000);
        this.notificationsShown.add('upgrade-browser');
    }

    /**
     * Show Safari limitations
     */
    showSafariLimitations() {
        if (this.notificationsShown.has('safari-limitations')) return;

        const message = `
            <div class="safari-limitations">
                <strong>Safari HTTP/3 Support:</strong> Safari has limited HTTP/3 support. 
                For the full demo experience, consider using Chrome or Firefox.
                <br><small>The demo will work but may not show HTTP/3 benefits.</small>
            </div>
        `;

        this.showNotification(message, 'info', 6000);
        this.notificationsShown.add('safari-limitations');
    }

    /**
     * Show notification with custom styling and duration
     */
    showNotification(message, type = 'info', duration = 5000) {
        const notification = document.createElement('div');
        notification.className = `compatibility-notification ${type}`;
        notification.innerHTML = `
            <div class="notification-content">
                ${message}
                ${duration > 0 ? '<button class="notification-close" onclick="this.parentElement.parentElement.remove()">×</button>' : ''}
            </div>
        `;

        // Add type-specific styling
        const typeStyles = {
            info: 'background: #d1ecf1; border-color: #bee5eb; color: #0c5460;',
            warning: 'background: #fff3cd; border-color: #ffeaa7; color: #856404;',
            error: 'background: #f8d7da; border-color: #f5c6cb; color: #721c24;',
            success: 'background: #d4edda; border-color: #c3e6cb; color: #155724;'
        };

        notification.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            max-width: 400px;
            padding: 1rem;
            border: 1px solid;
            border-radius: 8px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            z-index: 1000;
            ${typeStyles[type] || typeStyles.info}
        `;

        document.body.appendChild(notification);

        // Auto-remove if duration is set
        if (duration > 0) {
            setTimeout(() => {
                if (notification.parentElement) {
                    notification.remove();
                }
            }, duration);
        }

        return notification;
    }

    /**
     * Update the UI with compatibility information
     */
    updateUI() {
        const indicator = document.getElementById('compatibilityIndicator');
        const text = document.getElementById('compatibilityText');
        
        if (!indicator || !text) return;

        let status = 'partial';
        let message = '';

        // Determine status based on support levels
        if (this.http2Support && this.http3Support === true) {
            status = 'supported';
            message = `Full support (${this.browserInfo.browser} ${this.browserInfo.version})`;
        } else if (this.http2Support && (this.http3Support === 'limited' || this.http3Support === 'requires-flag')) {
            status = 'partial';
            message = `HTTP/2 + Limited HTTP/3 (${this.browserInfo.browser} ${this.browserInfo.version})`;
        } else if (this.http2Support && !this.http3Support) {
            status = 'partial';
            message = `HTTP/2 only (${this.browserInfo.browser} ${this.browserInfo.version})`;
        } else {
            status = 'not-supported';
            message = `Limited support (${this.browserInfo.browser} ${this.browserInfo.version})`;
        }

        // Add fallback indicator
        if (this.fallbackActive) {
            message += ' (Fallback Active)';
        }

        indicator.className = `compatibility-indicator ${status}`;
        text.textContent = message;

        // Apply protocol-specific UI adjustments
        this.applyProtocolUIAdjustments();

        // Store compatibility info globally for other modules
        window.protocolCompatibility = {
            http2: this.http2Support,
            http3: this.http3Support,
            quic: this.quicSupport,
            browser: this.browserInfo,
            networkInfo: this.networkInfo,
            fallbackActive: this.fallbackActive,
            quicFeatures: this.quicFeatures
        };

        // Dispatch custom event
        window.dispatchEvent(new CustomEvent('compatibilityChecked', {
            detail: window.protocolCompatibility
        }));
    }

    /**
     * Apply protocol-specific UI adjustments
     */
    applyProtocolUIAdjustments() {
        // Adjust HTTP/3 section based on support
        this.adjustHTTP3Section();
        
        // Adjust test controls based on capabilities
        this.adjustTestControls();
        
        // Add visual indicators for fallback mode
        this.addFallbackIndicators();
        
        // Adjust educational content
        this.adjustEducationalContent();
    }

    /**
     * Adjust HTTP/3 section UI
     */
    adjustHTTP3Section() {
        const http3Section = document.querySelector('.protocol-section:nth-child(2)');
        if (!http3Section) return;

        if (!this.http3Support || this.http3Support === 'limited') {
            // Add visual indication of limited support
            http3Section.classList.add('limited-support');
            
            // Add tooltip or overlay
            const overlay = document.createElement('div');
            overlay.className = 'protocol-overlay';
            overlay.innerHTML = `
                <div class="overlay-content">
                    <span class="overlay-icon">⚠️</span>
                    <span class="overlay-text">
                        ${!this.http3Support ? 'HTTP/3 not supported' : 'Limited HTTP/3 support'}
                        <br><small>Using HTTP/2 fallback</small>
                    </span>
                </div>
            `;
            
            http3Section.style.position = 'relative';
            http3Section.appendChild(overlay);
        } else if (this.http3Support === 'requires-flag') {
            // Add configuration required indicator
            http3Section.classList.add('requires-config');
            
            const configBadge = document.createElement('div');
            configBadge.className = 'config-required-badge';
            configBadge.textContent = 'Configuration Required';
            http3Section.appendChild(configBadge);
        }
    }

    /**
     * Adjust test controls based on browser capabilities
     */
    adjustTestControls() {
        const testScenario = document.getElementById('testScenario');
        if (!testScenario) return;

        // Disable or modify certain test scenarios for unsupported browsers
        if (!this.http3Support) {
            // Add note to scenario descriptions
            Array.from(testScenario.options).forEach(option => {
                if (option.value !== 'basic') {
                    option.text += ' (HTTP/2 only)';
                }
            });
        }

        // Add compatibility info to start button
        const startButton = document.getElementById('startTest');
        if (startButton && this.fallbackActive) {
            startButton.title = 'Running in fallback mode - HTTP/3 requests will use HTTP/2';
        }
    }

    /**
     * Add fallback indicators to the UI
     */
    addFallbackIndicators() {
        if (!this.fallbackActive) return;

        // Add fallback badge to header
        const header = document.querySelector('.header');
        if (header && !header.querySelector('.fallback-badge')) {
            const badge = document.createElement('div');
            badge.className = 'fallback-badge';
            badge.innerHTML = `
                <span class="badge-icon">🔄</span>
                <span class="badge-text">Fallback Mode Active</span>
            `;
            header.appendChild(badge);
        }
    }

    /**
     * Adjust educational content based on browser support
     */
    adjustEducationalContent() {
        // Add browser-specific notes to educational sections
        const educationSection = document.querySelector('.education-section');
        if (!educationSection) return;

        // Add compatibility notice
        if (!educationSection.querySelector('.compatibility-notice')) {
            const notice = document.createElement('div');
            notice.className = 'compatibility-notice';
            notice.innerHTML = this.generateCompatibilityNotice();
            
            educationSection.insertBefore(notice, educationSection.firstChild);
        }
    }

    /**
     * Generate compatibility notice content
     */
    generateCompatibilityNotice() {
        const { browser, version } = this.browserInfo;
        
        let content = `
            <div class="notice-header">
                <h3>Browser Compatibility Notice</h3>
                <span class="browser-info">${browser} ${version}</span>
            </div>
        `;

        if (this.http2Support && this.http3Support === true) {
            content += `
                <div class="notice-content success">
                    <span class="notice-icon">✅</span>
                    <p>Your browser fully supports both HTTP/2 and HTTP/3 protocols. You'll see accurate performance comparisons.</p>
                </div>
            `;
        } else if (this.http3Support === 'requires-flag') {
            content += `
                <div class="notice-content warning">
                    <span class="notice-icon">⚙️</span>
                    <p>HTTP/3 support is available but requires manual enabling. Follow the instructions above to enable it.</p>
                </div>
            `;
        } else if (this.http3Support === 'limited') {
            content += `
                <div class="notice-content warning">
                    <span class="notice-icon">⚠️</span>
                    <p>Your browser has limited HTTP/3 support. Some features may fall back to HTTP/2.</p>
                </div>
            `;
        } else {
            content += `
                <div class="notice-content info">
                    <span class="notice-icon">ℹ️</span>
                    <p>HTTP/3 is not supported in your browser. The demo will use HTTP/2 for both sides of the comparison.</p>
                </div>
            `;
        }

        return content;
    }

    /**
     * Get compatibility summary
     */
    getCompatibilitySummary() {
        return {
            http2Support: this.http2Support,
            http3Support: this.http3Support,
            quicSupport: this.quicSupport,
            browserInfo: this.browserInfo,
            networkInfo: this.networkInfo,
            recommendations: this.getRecommendations()
        };
    }

    /**
     * Get recommendations based on browser support
     */
    getRecommendations() {
        const recommendations = [];

        if (!this.http2Support) {
            recommendations.push('Consider updating your browser for HTTP/2 support');
        }

        if (!this.http3Support) {
            if (this.browserInfo.browser === 'Firefox') {
                recommendations.push('Enable HTTP/3 in Firefox by setting network.http.http3.enabled to true in about:config');
            } else if (this.browserInfo.browser === 'Chrome') {
                recommendations.push('HTTP/3 should be enabled by default in Chrome 87+');
            } else {
                recommendations.push('HTTP/3 support varies by browser - consider using Chrome or Firefox for best results');
            }
        }

        if (recommendations.length === 0) {
            recommendations.push('Your browser supports both HTTP/2 and HTTP/3!');
        }

        return recommendations;
    }

    /**
     * Check if a specific protocol is supported
     */
    isProtocolSupported(protocol) {
        switch (protocol.toLowerCase()) {
            case 'http2':
            case 'http/2':
                return this.http2Support;
            case 'http3':
            case 'http/3':
                return this.http3Support === true;
            case 'quic':
                return this.quicSupport === true;
            default:
                return false;
        }
    }

    /**
     * Get detailed protocol support information
     */
    getProtocolSupportDetails(protocol) {
        switch (protocol.toLowerCase()) {
            case 'http2':
            case 'http/2':
                return {
                    supported: this.http2Support,
                    level: this.http2Support ? 'full' : 'none',
                    fallbackAvailable: false
                };
            case 'http3':
            case 'http/3':
                return {
                    supported: this.http3Support === true,
                    level: this.http3Support,
                    fallbackAvailable: this.http2Support,
                    requiresConfig: this.http3Support === 'requires-flag'
                };
            case 'quic':
                return {
                    supported: this.quicSupport === true,
                    level: this.quicSupport,
                    features: this.quicFeatures
                };
            default:
                return { supported: false, level: 'none' };
        }
    }

    /**
     * Force fallback mode (for testing or troubleshooting)
     */
    forceFallbackMode() {
        console.log('Forcing fallback mode');
        this.fallbackActive = true;
        this.setupHTTP3Fallback();
        this.updateUI();
        
        this.showNotification(
            'Fallback mode activated manually. HTTP/3 requests will use HTTP/2.',
            'info',
            5000
        );
    }

    /**
     * Disable fallback mode
     */
    disableFallbackMode() {
        if (!this.fallbackActive) return;

        console.log('Disabling fallback mode');
        
        // Restore original fetch if it was overridden
        if (this.originalFetch) {
            window.fetch = this.originalFetch;
            this.originalFetch = null;
        }

        // Disconnect iframe observer
        if (this.iframeObserver) {
            this.iframeObserver.disconnect();
            this.iframeObserver = null;
        }

        this.fallbackActive = false;
        this.updateUI();

        // Remove fallback indicators
        const fallbackBadge = document.querySelector('.fallback-badge');
        if (fallbackBadge) {
            fallbackBadge.remove();
        }
    }

    /**
     * Get current compatibility status
     */
    getCompatibilityStatus() {
        return {
            http2Support: this.http2Support,
            http3Support: this.http3Support,
            quicSupport: this.quicSupport,
            browserInfo: this.browserInfo,
            networkInfo: this.networkInfo,
            fallbackActive: this.fallbackActive,
            quicFeatures: this.quicFeatures,
            notificationsShown: Array.from(this.notificationsShown)
        };
    }

    /**
     * Cleanup compatibility checker
     */
    cleanup() {
        // Disable fallback mode
        this.disableFallbackMode();

        // Remove event listeners
        window.removeEventListener('error', this.handleCompatibilityError);
        window.removeEventListener('unhandledrejection', this.handleCompatibilityError);

        // Clear notifications
        document.querySelectorAll('.compatibility-notification').forEach(notification => {
            notification.remove();
        });

        console.log('Compatibility checker cleaned up');
    }
}

// Initialize compatibility checker when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.compatibilityChecker = new CompatibilityChecker();
});

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = CompatibilityChecker;
}