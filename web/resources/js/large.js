// Large JavaScript file - ~15KB
(function(global) {
    'use strict';
    
    // Advanced Performance Monitoring System
    class AdvancedPerformanceMonitor {
        constructor(options = {}) {
            this.options = {
                enableResourceTiming: true,
                enableNavigationTiming: true,
                enableUserTiming: true,
                bufferSize: 1000,
                ...options
            };
            
            this.metrics = [];
            this.resourceMetrics = [];
            this.navigationMetrics = {};
            this.userTimings = [];
            this.observers = [];
            
            this.init();
        }
        
        init() {
            this.startTime = performance.now();
            this.collectNavigationTiming();
            this.setupObservers();
        }
        
        collectNavigationTiming() {
            if (!this.options.enableNavigationTiming) return;
            
            const navigation = performance.getEntriesByType('navigation')[0];
            if (navigation) {
                this.navigationMetrics = {
                    domainLookup: navigation.domainLookupEnd - navigation.domainLookupStart,
                    tcpConnect: navigation.connectEnd - navigation.connectStart,
                    tlsHandshake: navigation.secureConnectionStart > 0 ? 
                        navigation.connectEnd - navigation.secureConnectionStart : 0,
                    request: navigation.responseStart - navigation.requestStart,
                    response: navigation.responseEnd - navigation.responseStart,
                    domProcessing: navigation.domComplete - navigation.domLoading,
                    loadComplete: navigation.loadEventEnd - navigation.loadEventStart
                };
            }
        }
        
        setupObservers() {
            if (this.options.enableResourceTiming && 'PerformanceObserver' in window) {
                const resourceObserver = new PerformanceObserver((list) => {
                    list.getEntries().forEach(entry => {
                        this.resourceMetrics.push({
                            name: entry.name,
                            type: entry.initiatorType,
                            duration: entry.duration,
                            size: entry.transferSize || 0,
                            cached: entry.transferSize === 0 && entry.decodedBodySize > 0,
                            timestamp: entry.startTime
                        });
                    });
                });
                
                resourceObserver.observe({ entryTypes: ['resource'] });
                this.observers.push(resourceObserver);
            }
            
            if (this.options.enableUserTiming && 'PerformanceObserver' in window) {
                const userTimingObserver = new PerformanceObserver((list) => {
                    list.getEntries().forEach(entry => {
                        this.userTimings.push({
                            name: entry.name,
                            type: entry.entryType,
                            duration: entry.duration || 0,
                            startTime: entry.startTime
                        });
                    });
                });
                
                userTimingObserver.observe({ entryTypes: ['measure', 'mark'] });
                this.observers.push(userTimingObserver);
            }
        }
        
        mark(name, detail = {}) {
            const time = performance.now() - this.startTime;
            const metric = {
                name,
                time,
                timestamp: Date.now(),
                detail,
                type: 'mark'
            };
            
            this.metrics.push(metric);
            
            if (this.options.enableUserTiming) {
                performance.mark(name);
            }
            
            this.emit('mark', metric);
            return metric;
        }
        
        measure(name, startMark, endMark) {
            if (this.options.enableUserTiming) {
                performance.measure(name, startMark, endMark);
            }
            
            const startMetric = this.metrics.find(m => m.name === startMark);
            const endMetric = this.metrics.find(m => m.name === endMark);
            
            if (startMetric && endMetric) {
                const duration = endMetric.time - startMetric.time;
                const metric = {
                    name,
                    duration,
                    startTime: startMetric.time,
                    endTime: endMetric.time,
                    type: 'measure'
                };
                
                this.metrics.push(metric);
                this.emit('measure', metric);
                return metric;
            }
        }
        
        getMetrics(type = null) {
            if (type) {
                return this.metrics.filter(m => m.type === type);
            }
            return [...this.metrics];
        }
        
        getResourceMetrics() {
            return [...this.resourceMetrics];
        }
        
        getNavigationMetrics() {
            return { ...this.navigationMetrics };
        }
        
        generateReport() {
            return {
                summary: {
                    totalMarks: this.metrics.filter(m => m.type === 'mark').length,
                    totalMeasures: this.metrics.filter(m => m.type === 'measure').length,
                    totalResources: this.resourceMetrics.length,
                    sessionDuration: performance.now() - this.startTime
                },
                navigation: this.navigationMetrics,
                resources: this.resourceMetrics,
                userTimings: this.userTimings,
                customMetrics: this.metrics
            };
        }
        
        emit(event, data) {
            if (this.listeners && this.listeners[event]) {
                this.listeners[event].forEach(callback => callback(data));
            }
        }
        
        on(event, callback) {
            if (!this.listeners) this.listeners = {};
            if (!this.listeners[event]) this.listeners[event] = [];
            this.listeners[event].push(callback);
        }
        
        off(event, callback) {
            if (this.listeners && this.listeners[event]) {
                this.listeners[event] = this.listeners[event].filter(cb => cb !== callback);
            }
        }
        
        destroy() {
            this.observers.forEach(observer => observer.disconnect());
            this.observers = [];
            this.listeners = {};
        }
    }
    
    // Advanced Resource Management System
    class ResourceManager {
        constructor() {
            this.cache = new Map();
            this.loadingQueue = new Map();
            this.preloadQueue = [];
            this.maxConcurrent = 6;
            this.currentLoading = 0;
            this.retryAttempts = 3;
            this.timeout = 10000;
        }
        
        async load(url, options = {}) {
            const cacheKey = this.getCacheKey(url, options);
            
            // Return cached resource if available
            if (this.cache.has(cacheKey) && !options.bypassCache) {
                return this.cache.get(cacheKey);
            }
            
            // Return existing promise if already loading
            if (this.loadingQueue.has(cacheKey)) {
                return this.loadingQueue.get(cacheKey);
            }
            
            // Create loading promise
            const loadPromise = this.createLoadPromise(url, options);
            this.loadingQueue.set(cacheKey, loadPromise);
            
            try {
                const result = await loadPromise;
                this.cache.set(cacheKey, result);
                return result;
            } finally {
                this.loadingQueue.delete(cacheKey);
            }
        }
        
        async createLoadPromise(url, options) {
            return new Promise((resolve, reject) => {
                const timeoutId = setTimeout(() => {
                    reject(new Error(`Resource load timeout: ${url}`));
                }, this.timeout);
                
                this.loadResource(url, options)
                    .then(result => {
                        clearTimeout(timeoutId);
                        resolve(result);
                    })
                    .catch(error => {
                        clearTimeout(timeoutId);
                        if (options.retry !== false && this.retryAttempts > 0) {
                            this.retryLoad(url, options, this.retryAttempts)
                                .then(resolve)
                                .catch(reject);
                        } else {
                            reject(error);
                        }
                    });
            });
        }
        
        async retryLoad(url, options, attemptsLeft) {
            if (attemptsLeft <= 0) {
                throw new Error(`Failed to load resource after retries: ${url}`);
            }
            
            await this.delay(1000 * (this.retryAttempts - attemptsLeft + 1));
            
            try {
                return await this.loadResource(url, options);
            } catch (error) {
                return this.retryLoad(url, options, attemptsLeft - 1);
            }
        }
        
        async loadResource(url, options) {
            const type = this.getResourceType(url, options);
            
            switch (type) {
                case 'script':
                    return this.loadScript(url, options);
                case 'stylesheet':
                    return this.loadStylesheet(url, options);
                case 'image':
                    return this.loadImage(url, options);
                case 'json':
                    return this.loadJSON(url, options);
                case 'text':
                    return this.loadText(url, options);
                default:
                    return this.loadGeneric(url, options);
            }
        }
        
        async loadScript(url, options) {
            return new Promise((resolve, reject) => {
                const script = document.createElement('script');
                script.src = url;
                script.async = options.async !== false;
                script.defer = options.defer === true;
                
                script.onload = () => resolve({ type: 'script', url, element: script });
                script.onerror = () => reject(new Error(`Failed to load script: ${url}`));
                
                document.head.appendChild(script);
            });
        }
        
        async loadStylesheet(url, options) {
            return new Promise((resolve, reject) => {
                const link = document.createElement('link');
                link.rel = 'stylesheet';
                link.href = url;
                
                link.onload = () => resolve({ type: 'stylesheet', url, element: link });
                link.onerror = () => reject(new Error(`Failed to load stylesheet: ${url}`));
                
                document.head.appendChild(link);
            });
        }
        
        async loadImage(url, options) {
            return new Promise((resolve, reject) => {
                const img = new Image();
                img.crossOrigin = options.crossOrigin || 'anonymous';
                
                img.onload = () => resolve({ type: 'image', url, element: img, width: img.width, height: img.height });
                img.onerror = () => reject(new Error(`Failed to load image: ${url}`));
                
                img.src = url;
            });
        }
        
        async loadJSON(url, options) {
            const response = await fetch(url, options);
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            const data = await response.json();
            return { type: 'json', url, data };
        }
        
        async loadText(url, options) {
            const response = await fetch(url, options);
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            const text = await response.text();
            return { type: 'text', url, data: text };
        }
        
        async loadGeneric(url, options) {
            const response = await fetch(url, options);
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            return { type: 'generic', url, response };
        }
        
        getResourceType(url, options) {
            if (options.type) return options.type;
            
            const extension = url.split('.').pop().toLowerCase();
            const typeMap = {
                'js': 'script',
                'css': 'stylesheet',
                'jpg': 'image',
                'jpeg': 'image',
                'png': 'image',
                'gif': 'image',
                'svg': 'image',
                'webp': 'image',
                'json': 'json',
                'txt': 'text',
                'html': 'text',
                'xml': 'text'
            };
            
            return typeMap[extension] || 'generic';
        }
        
        getCacheKey(url, options) {
            return `${url}:${JSON.stringify(options)}`;
        }
        
        async delay(ms) {
            return new Promise(resolve => setTimeout(resolve, ms));
        }
        
        preload(urls) {
            urls.forEach(url => {
                if (typeof url === 'string') {
                    this.preloadQueue.push({ url, options: {} });
                } else {
                    this.preloadQueue.push(url);
                }
            });
            
            this.processPreloadQueue();
        }
        
        async processPreloadQueue() {
            while (this.preloadQueue.length > 0 && this.currentLoading < this.maxConcurrent) {
                const item = this.preloadQueue.shift();
                this.currentLoading++;
                
                this.load(item.url, item.options)
                    .finally(() => {
                        this.currentLoading--;
                        this.processPreloadQueue();
                    });
            }
        }
        
        clearCache() {
            this.cache.clear();
        }
        
        getCacheSize() {
            return this.cache.size;
        }
        
        getCacheKeys() {
            return Array.from(this.cache.keys());
        }
    }
    
    // Advanced DOM Manipulation Library
    class DOMLibrary {
        constructor() {
            this.eventDelegates = new Map();
        }
        
        $(selector, context = document) {
            if (typeof selector === 'string') {
                return new DOMCollection(Array.from(context.querySelectorAll(selector)));
            } else if (selector instanceof Element) {
                return new DOMCollection([selector]);
            } else if (selector instanceof NodeList || Array.isArray(selector)) {
                return new DOMCollection(Array.from(selector));
            }
            return new DOMCollection([]);
        }
        
        create(tag, attributes = {}, children = []) {
            const element = document.createElement(tag);
            
            Object.entries(attributes).forEach(([key, value]) => {
                if (key === 'className' || key === 'class') {
                    element.className = value;
                } else if (key === 'innerHTML') {
                    element.innerHTML = value;
                } else if (key === 'textContent') {
                    element.textContent = value;
                } else if (key.startsWith('data-')) {
                    element.dataset[key.slice(5)] = value;
                } else if (key.startsWith('on') && typeof value === 'function') {
                    element.addEventListener(key.slice(2), value);
                } else {
                    element.setAttribute(key, value);
                }
            });
            
            children.forEach(child => {
                if (typeof child === 'string') {
                    element.appendChild(document.createTextNode(child));
                } else if (child instanceof Element) {
                    element.appendChild(child);
                }
            });
            
            return element;
        }
        
        delegate(selector, event, handler) {
            const key = `${selector}:${event}`;
            
            if (!this.eventDelegates.has(key)) {
                const delegateHandler = (e) => {
                    const target = e.target.closest(selector);
                    if (target) {
                        handler.call(target, e);
                    }
                };
                
                document.addEventListener(event, delegateHandler);
                this.eventDelegates.set(key, delegateHandler);
            }
        }
        
        undelegate(selector, event) {
            const key = `${selector}:${event}`;
            const handler = this.eventDelegates.get(key);
            
            if (handler) {
                document.removeEventListener(event, handler);
                this.eventDelegates.delete(key);
            }
        }
        
        ready(callback) {
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', callback);
            } else {
                callback();
            }
        }
    }
    
    class DOMCollection {
        constructor(elements) {
            this.elements = elements;
            this.length = elements.length;
        }
        
        each(callback) {
            this.elements.forEach((element, index) => {
                callback.call(element, index, element);
            });
            return this;
        }
        
        addClass(className) {
            return this.each(function() {
                this.classList.add(className);
            });
        }
        
        removeClass(className) {
            return this.each(function() {
                this.classList.remove(className);
            });
        }
        
        toggleClass(className) {
            return this.each(function() {
                this.classList.toggle(className);
            });
        }
        
        hasClass(className) {
            return this.elements.some(el => el.classList.contains(className));
        }
        
        attr(name, value) {
            if (value === undefined) {
                return this.elements[0]?.getAttribute(name);
            }
            return this.each(function() {
                this.setAttribute(name, value);
            });
        }
        
        css(property, value) {
            if (value === undefined) {
                return getComputedStyle(this.elements[0])[property];
            }
            return this.each(function() {
                this.style[property] = value;
            });
        }
        
        on(event, handler) {
            return this.each(function() {
                this.addEventListener(event, handler);
            });
        }
        
        off(event, handler) {
            return this.each(function() {
                this.removeEventListener(event, handler);
            });
        }
        
        hide() {
            return this.css('display', 'none');
        }
        
        show() {
            return this.css('display', '');
        }
        
        fadeIn(duration = 300) {
            return this.each(function() {
                const element = this;
                element.style.opacity = '0';
                element.style.display = '';
                
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
            });
        }
        
        fadeOut(duration = 300) {
            return this.each(function() {
                const element = this;
                const startOpacity = parseFloat(getComputedStyle(element).opacity);
                const start = performance.now();
                
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
            });
        }
        
        first() {
            return new DOMCollection(this.elements.slice(0, 1));
        }
        
        last() {
            return new DOMCollection(this.elements.slice(-1));
        }
        
        eq(index) {
            return new DOMCollection([this.elements[index]].filter(Boolean));
        }
        
        find(selector) {
            const found = [];
            this.elements.forEach(element => {
                found.push(...element.querySelectorAll(selector));
            });
            return new DOMCollection(found);
        }
        
        parent() {
            const parents = this.elements.map(el => el.parentElement).filter(Boolean);
            return new DOMCollection([...new Set(parents)]);
        }
        
        children() {
            const children = [];
            this.elements.forEach(element => {
                children.push(...element.children);
            });
            return new DOMCollection(children);
        }
    }
    
    // Initialize large test functionality
    function initLargeTest() {
        console.log('Large JS loaded - Advanced features initialized');
        
        const monitor = new AdvancedPerformanceMonitor();
        const resourceManager = new ResourceManager();
        const dom = new DOMLibrary();
        
        monitor.mark('large-js-init');
        
        // Export all utilities to global scope
        global.largeTestUtils = {
            AdvancedPerformanceMonitor,
            ResourceManager,
            DOMLibrary,
            DOMCollection,
            monitor,
            resourceManager,
            dom,
            $: dom.$.bind(dom)
        };
        
        // Set up advanced event handling
        dom.delegate('.large-test-button', 'click', function(e) {
            const button = this;
            monitor.mark(`button-click-${Date.now()}`);
            
            dom.$(button).fadeOut(200);
            setTimeout(() => {
                button.textContent = 'Advanced Click Handled!';
                dom.$(button).fadeIn(200);
            }, 200);
        });
        
        // Preload some resources for demonstration
        resourceManager.preload([
            'resources/css/small.css',
            'resources/js/small.js'
        ]);
        
        monitor.mark('large-js-ready');
        
        // Log performance report after 5 seconds
        setTimeout(() => {
            console.log('Performance Report:', monitor.generateReport());
        }, 5000);
    }
    
    // Auto-initialize
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initLargeTest);
    } else {
        initLargeTest();
    }
    
})(window);