// Medium JavaScript file - ~5KB
(function() {
    'use strict';
    
    // Performance monitoring utilities
    class PerformanceMonitor {
        constructor() {
            this.metrics = [];
            this.startTime = performance.now();
        }
        
        mark(name) {
            const time = performance.now() - this.startTime;
            this.metrics.push({ name, time, timestamp: Date.now() });
            console.log(`Performance mark: ${name} at ${Math.round(time)}ms`);
        }
        
        getMetrics() {
            return this.metrics;
        }
        
        reset() {
            this.metrics = [];
            this.startTime = performance.now();
        }
    }
    
    // Resource loader utility
    class ResourceLoader {
        constructor() {
            this.loadedResources = new Set();
            this.loadingPromises = new Map();
        }
        
        async loadCSS(url) {
            if (this.loadedResources.has(url)) {
                return Promise.resolve();
            }
            
            if (this.loadingPromises.has(url)) {
                return this.loadingPromises.get(url);
            }
            
            const promise = new Promise((resolve, reject) => {
                const link = document.createElement('link');
                link.rel = 'stylesheet';
                link.href = url;
                link.onload = () => {
                    this.loadedResources.add(url);
                    resolve();
                };
                link.onerror = reject;
                document.head.appendChild(link);
            });
            
            this.loadingPromises.set(url, promise);
            return promise;
        }
        
        async loadJS(url) {
            if (this.loadedResources.has(url)) {
                return Promise.resolve();
            }
            
            if (this.loadingPromises.has(url)) {
                return this.loadingPromises.get(url);
            }
            
            const promise = new Promise((resolve, reject) => {
                const script = document.createElement('script');
                script.src = url;
                script.onload = () => {
                    this.loadedResources.add(url);
                    resolve();
                };
                script.onerror = reject;
                document.head.appendChild(script);
            });
            
            this.loadingPromises.set(url, promise);
            return promise;
        }
        
        async loadImage(url) {
            return new Promise((resolve, reject) => {
                const img = new Image();
                img.onload = () => resolve(img);
                img.onerror = reject;
                img.src = url;
            });
        }
    }
    
    // DOM utilities
    const DOMUtils = {
        createElement(tag, attributes = {}, children = []) {
            const element = document.createElement(tag);
            
            Object.entries(attributes).forEach(([key, value]) => {
                if (key === 'className') {
                    element.className = value;
                } else if (key === 'innerHTML') {
                    element.innerHTML = value;
                } else {
                    element.setAttribute(key, value);
                }
            });
            
            children.forEach(child => {
                if (typeof child === 'string') {
                    element.appendChild(document.createTextNode(child));
                } else {
                    element.appendChild(child);
                }
            });
            
            return element;
        },
        
        findElements(selector) {
            return Array.from(document.querySelectorAll(selector));
        },
        
        addEventListeners(elements, event, handler) {
            elements.forEach(element => {
                element.addEventListener(event, handler);
            });
        },
        
        removeEventListeners(elements, event, handler) {
            elements.forEach(element => {
                element.removeEventListener(event, handler);
            });
        }
    };
    
    // Animation utilities
    const AnimationUtils = {
        fadeIn(element, duration = 300) {
            element.style.opacity = '0';
            element.style.display = 'block';
            
            const start = performance.now();
            
            function animate(currentTime) {
                const elapsed = currentTime - start;
                const progress = Math.min(elapsed / duration, 1);
                
                element.style.opacity = progress;
                
                if (progress < 1) {
                    requestAnimationFrame(animate);
                }
            }
            
            requestAnimationFrame(animate);
        },
        
        fadeOut(element, duration = 300) {
            const start = performance.now();
            const startOpacity = parseFloat(getComputedStyle(element).opacity);
            
            function animate(currentTime) {
                const elapsed = currentTime - start;
                const progress = Math.min(elapsed / duration, 1);
                
                element.style.opacity = startOpacity * (1 - progress);
                
                if (progress < 1) {
                    requestAnimationFrame(animate);
                } else {
                    element.style.display = 'none';
                }
            }
            
            requestAnimationFrame(animate);
        },
        
        slideDown(element, duration = 300) {
            element.style.height = '0px';
            element.style.overflow = 'hidden';
            element.style.display = 'block';
            
            const targetHeight = element.scrollHeight;
            const start = performance.now();
            
            function animate(currentTime) {
                const elapsed = currentTime - start;
                const progress = Math.min(elapsed / duration, 1);
                
                element.style.height = (targetHeight * progress) + 'px';
                
                if (progress < 1) {
                    requestAnimationFrame(animate);
                } else {
                    element.style.height = 'auto';
                    element.style.overflow = 'visible';
                }
            }
            
            requestAnimationFrame(animate);
        }
    };
    
    // HTTP utilities
    const HTTPUtils = {
        async get(url, options = {}) {
            const response = await fetch(url, {
                method: 'GET',
                ...options
            });
            
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            
            return response;
        },
        
        async post(url, data, options = {}) {
            const response = await fetch(url, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    ...options.headers
                },
                body: JSON.stringify(data),
                ...options
            });
            
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            
            return response;
        },
        
        async loadJSON(url) {
            const response = await this.get(url);
            return response.json();
        }
    };
    
    // Initialize medium test functionality
    function initMediumTest() {
        console.log('Medium JS loaded');
        
        const monitor = new PerformanceMonitor();
        const loader = new ResourceLoader();
        
        monitor.mark('medium-js-init');
        
        // Export utilities to global scope
        window.mediumTestUtils = {
            PerformanceMonitor,
            ResourceLoader,
            DOMUtils,
            AnimationUtils,
            HTTPUtils,
            monitor,
            loader
        };
        
        // Add some interactive functionality
        const buttons = DOMUtils.findElements('.medium-test-button');
        DOMUtils.addEventListeners(buttons, 'click', (event) => {
            const button = event.target;
            AnimationUtils.fadeOut(button, 200);
            setTimeout(() => {
                button.textContent = 'Clicked!';
                AnimationUtils.fadeIn(button, 200);
            }, 200);
        });
        
        monitor.mark('medium-js-ready');
    }
    
    // Auto-initialize
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initMediumTest);
    } else {
        initMediumTest();
    }
})();