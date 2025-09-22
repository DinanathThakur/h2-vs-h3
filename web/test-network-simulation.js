/**
 * Network Simulation Test Script
 * Tests the network simulation functionality
 */

// Test network simulation features
function testNetworkSimulation() {
    console.log('Testing network simulation features...');
    
    // Check if NetworkSimulation class is available
    if (typeof NetworkSimulation === 'undefined') {
        console.error('NetworkSimulation class not found');
        return false;
    }
    
    // Create instance
    const networkSim = new NetworkSimulation();
    
    // Test basic functionality
    const tests = [
        testSimulationControls,
        testLatencySimulation,
        testBandwidthSimulation,
        testPacketLossSimulation,
        testConnectionInterruption,
        testConnectionMigration,
        testNetworkScenarios
    ];
    
    let passed = 0;
    let failed = 0;
    
    tests.forEach(test => {
        try {
            if (test(networkSim)) {
                console.log(`✅ ${test.name} passed`);
                passed++;
            } else {
                console.log(`❌ ${test.name} failed`);
                failed++;
            }
        } catch (error) {
            console.error(`❌ ${test.name} threw error:`, error);
            failed++;
        }
    });
    
    console.log(`\nTest Results: ${passed} passed, ${failed} failed`);
    return failed === 0;
}

// Test simulation controls creation
function testSimulationControls(networkSim) {
    const controls = document.querySelector('.network-simulation-controls');
    return controls !== null;
}

// Test latency simulation
function testLatencySimulation(networkSim) {
    const latencySlider = document.getElementById('latencySlider');
    if (!latencySlider) return false;
    
    // Test slider functionality
    latencySlider.value = 100;
    latencySlider.dispatchEvent(new Event('input'));
    
    const latencyValue = document.getElementById('latencyValue');
    return latencyValue && latencyValue.textContent === '100ms';
}

// Test bandwidth simulation
function testBandwidthSimulation(networkSim) {
    const bandwidthSlider = document.getElementById('bandwidthSlider');
    if (!bandwidthSlider) return false;
    
    // Test slider functionality
    bandwidthSlider.value = 50;
    bandwidthSlider.dispatchEvent(new Event('input'));
    
    const bandwidthValue = document.getElementById('bandwidthValue');
    return bandwidthValue && bandwidthValue.textContent === '50 Mbps';
}

// Test packet loss simulation
function testPacketLossSimulation(networkSim) {
    const packetLossSlider = document.getElementById('packetLossSlider');
    if (!packetLossSlider) return false;
    
    // Test slider functionality
    packetLossSlider.value = 2.5;
    packetLossSlider.dispatchEvent(new Event('input'));
    
    const packetLossValue = document.getElementById('packetLossValue');
    return packetLossValue && packetLossValue.textContent === '2.5%';
}

// Test connection interruption
function testConnectionInterruption(networkSim) {
    const interruptButton = document.getElementById('connectionInterruption');
    return interruptButton !== null;
}

// Test connection migration
function testConnectionMigration(networkSim) {
    const migrationButton = document.getElementById('connectionMigration');
    return migrationButton !== null;
}

// Test network scenarios
function testNetworkScenarios(networkSim) {
    const scenarioSelect = document.getElementById('scenarioSelect');
    if (!scenarioSelect) return false;
    
    // Test scenario selection
    scenarioSelect.value = 'mobile-3g';
    scenarioSelect.dispatchEvent(new Event('change'));
    
    return true;
}

// Test connection status updates
function testConnectionStatus() {
    const http2Connection = document.getElementById('http2Connection');
    const http3Connection = document.getElementById('http3Connection');
    
    return http2Connection !== null && http3Connection !== null;
}

// Test simulation state management
function testSimulationState(networkSim) {
    const state = networkSim.getSimulationState();
    
    return state && 
           typeof state.isSimulating === 'boolean' &&
           typeof state.connectionStates === 'object' &&
           Array.isArray(state.history);
}

// Run tests when page loads
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        setTimeout(testNetworkSimulation, 1000); // Wait for initialization
    });
} else {
    setTimeout(testNetworkSimulation, 1000);
}

// Export for manual testing
window.testNetworkSimulation = testNetworkSimulation;