/**
 * Test Script for Mixed Resources Test
 * Simulates various JavaScript operations and resource loading
 */

// Track this script loading
if (typeof trackResource === 'function') {
    trackResource('JavaScript File', 'script', 2048);
}

// Simulate some JavaScript operations
function simulateDataProcessing() {
    const data = [];
    for (let i = 0; i < 1000; i++) {
        data.push({
            id: i,
            value: Math.random() * 100,
            timestamp: Date.now()
        });
    }
    return data;
}

// Simulate API call
async function simulateAPICall() {
    return new Promise((resolve) => {
        setTimeout(() => {
            resolve({
                status: 'success',
                data: simulateDataProcessing(),
                timestamp: Date.now()
            });
        }, 100 + Math.random() * 200);
    });
}

// Initialize when script loads
(async function() {
    console.log('Test script loaded');
    
    // Simulate some processing
    const processedData = simulateDataProcessing();
    console.log(`Processed ${processedData.length} items`);
    
    // Simulate API call
    try {
        const apiResult = await simulateAPICall();
        console.log('API call completed:', apiResult.status);
        
        if (typeof trackResource === 'function') {
            trackResource('API Response', 'xhr', JSON.stringify(apiResult).length);
        }
    } catch (error) {
        console.error('API call failed:', error);
    }
    
    // Add some dynamic content
    const dynamicContent = document.createElement('div');
    dynamicContent.innerHTML = `
        <h3>Dynamic Content</h3>
        <p>This content was added by JavaScript after the script loaded.</p>
        <p>Processing completed at: ${new Date().toLocaleTimeString()}</p>
    `;
    dynamicContent.style.cssText = `
        background: #e7f3ff;
        padding: 1rem;
        border-radius: 4px;
        margin: 1rem 0;
        border-left: 4px solid #007bff;
    `;
    
    document.querySelector('.test-content').appendChild(dynamicContent);
    
    console.log('Dynamic content added');
})();

// Export some utilities for testing
window.testUtils = {
    simulateDataProcessing,
    simulateAPICall,
    getPerformanceMetrics: () => {
        if (performance.getEntriesByType) {
            return {
                navigation: performance.getEntriesByType('navigation'),
                resources: performance.getEntriesByType('resource'),
                measures: performance.getEntriesByType('measure')
            };
        }
        return null;
    }
};