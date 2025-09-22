// Small JavaScript file - ~1KB
function initSmallTest() {
    console.log('Small JS loaded');
    
    const button = document.querySelector('.test-button');
    if (button) {
        button.addEventListener('click', () => {
            alert('Small JS working!');
        });
    }
    
    // Simple utility functions
    const utils = {
        formatTime: (ms) => `${Math.round(ms)}ms`,
        getCurrentTime: () => new Date().toISOString(),
        randomId: () => Math.random().toString(36).substr(2, 9)
    };
    
    window.smallTestUtils = utils;
}

// Auto-initialize
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initSmallTest);
} else {
    initSmallTest();
}