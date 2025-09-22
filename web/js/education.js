/**
 * Educational Content Interactive Features
 * Handles tab switching, benefit details, and educational interactions
 */

// Tab switching functionality
function initializeTabs() {
    const tabButtons = document.querySelectorAll('.tab-button');
    const tabContents = document.querySelectorAll('.tab-content');
    
    tabButtons.forEach(button => {
        button.addEventListener('click', () => {
            const targetTab = button.getAttribute('data-tab');
            
            // Remove active class from all buttons and contents
            tabButtons.forEach(btn => btn.classList.remove('active'));
            tabContents.forEach(content => content.classList.remove('active'));
            
            // Add active class to clicked button and corresponding content
            button.classList.add('active');
            const targetContent = document.getElementById(targetTab);
            if (targetContent) {
                targetContent.classList.add('active');
            }
        });
    });
}

// Benefit details toggle functionality
function toggleBenefitDetails(benefitId) {
    const details = document.getElementById(`${benefitId}-details`);
    const button = details.parentElement.querySelector('.learn-more-btn');
    
    if (details.classList.contains('active')) {
        details.classList.remove('active');
        button.textContent = 'Learn More';
    } else {
        // Close all other open details
        document.querySelectorAll('.benefit-details.active').forEach(detail => {
            detail.classList.remove('active');
            detail.parentElement.querySelector('.learn-more-btn').textContent = 'Learn More';
        });
        
        // Open the clicked one
        details.classList.add('active');
        button.textContent = 'Show Less';
    }
}

// Add interactive hover effects to educational cards
function initializeCardInteractions() {
    const cards = document.querySelectorAll('.benefit-card, .scenario-card, .overview-card');
    
    cards.forEach(card => {
        card.addEventListener('mouseenter', () => {
            card.style.transform = 'translateY(-5px)';
        });
        
        card.addEventListener('mouseleave', () => {
            card.style.transform = 'translateY(0)';
        });
    });
}

// Smooth scrolling for educational sections
function initializeSmoothScrolling() {
    const links = document.querySelectorAll('a[href^="#"]');
    
    links.forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            const targetId = link.getAttribute('href').substring(1);
            const targetElement = document.getElementById(targetId);
            
            if (targetElement) {
                targetElement.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        });
    });
}

// Add visual indicators for protocol performance
function addPerformanceIndicators() {
    const performanceElements = document.querySelectorAll('.performance');
    
    performanceElements.forEach(element => {
        const text = element.textContent.toLowerCase();
        
        if (text.includes('faster') || text.includes('better')) {
            element.style.position = 'relative';
            element.style.overflow = 'hidden';
            
            // Add a subtle animation for better performance indicators
            element.addEventListener('mouseenter', () => {
                element.style.transform = 'scale(1.05)';
                element.style.transition = 'transform 0.2s ease';
            });
            
            element.addEventListener('mouseleave', () => {
                element.style.transform = 'scale(1)';
            });
        }
    });
}

// Initialize educational tooltips
function initializeTooltips() {
    const tooltipElements = document.querySelectorAll('[data-tooltip]');
    
    tooltipElements.forEach(element => {
        element.addEventListener('mouseenter', (e) => {
            const tooltip = document.createElement('div');
            tooltip.className = 'tooltip';
            tooltip.textContent = element.getAttribute('data-tooltip');
            tooltip.style.cssText = `
                position: absolute;
                background: #333;
                color: white;
                padding: 0.5rem 1rem;
                border-radius: 4px;
                font-size: 0.9rem;
                z-index: 1000;
                pointer-events: none;
                white-space: nowrap;
                opacity: 0;
                transition: opacity 0.3s ease;
            `;
            
            document.body.appendChild(tooltip);
            
            const rect = element.getBoundingClientRect();
            tooltip.style.left = `${rect.left + rect.width / 2 - tooltip.offsetWidth / 2}px`;
            tooltip.style.top = `${rect.top - tooltip.offsetHeight - 10}px`;
            
            setTimeout(() => {
                tooltip.style.opacity = '1';
            }, 100);
            
            element._tooltip = tooltip;
        });
        
        element.addEventListener('mouseleave', () => {
            if (element._tooltip) {
                element._tooltip.remove();
                element._tooltip = null;
            }
        });
    });
}

// Add progressive disclosure for complex content
function initializeProgressiveDisclosure() {
    const complexSections = document.querySelectorAll('.metric-factors, .benefit-details');
    
    complexSections.forEach(section => {
        const items = section.querySelectorAll('li');
        if (items.length > 3) {
            // Hide items beyond the first 3
            for (let i = 3; i < items.length; i++) {
                items[i].style.display = 'none';
            }
            
            // Add "Show more" button
            const showMoreBtn = document.createElement('button');
            showMoreBtn.textContent = `Show ${items.length - 3} more`;
            showMoreBtn.className = 'show-more-btn';
            showMoreBtn.style.cssText = `
                background: none;
                border: none;
                color: #007bff;
                cursor: pointer;
                font-size: 0.9rem;
                margin-top: 0.5rem;
                text-decoration: underline;
            `;
            
            showMoreBtn.addEventListener('click', () => {
                const isExpanded = showMoreBtn.textContent.includes('less');
                
                for (let i = 3; i < items.length; i++) {
                    items[i].style.display = isExpanded ? 'none' : 'block';
                }
                
                showMoreBtn.textContent = isExpanded 
                    ? `Show ${items.length - 3} more`
                    : 'Show less';
            });
            
            section.appendChild(showMoreBtn);
        }
    });
}

// Add keyboard navigation for tabs
function initializeKeyboardNavigation() {
    const tabButtons = document.querySelectorAll('.tab-button');
    
    tabButtons.forEach((button, index) => {
        button.addEventListener('keydown', (e) => {
            let targetIndex;
            
            switch (e.key) {
                case 'ArrowLeft':
                    targetIndex = index > 0 ? index - 1 : tabButtons.length - 1;
                    break;
                case 'ArrowRight':
                    targetIndex = index < tabButtons.length - 1 ? index + 1 : 0;
                    break;
                case 'Home':
                    targetIndex = 0;
                    break;
                case 'End':
                    targetIndex = tabButtons.length - 1;
                    break;
                default:
                    return;
            }
            
            e.preventDefault();
            tabButtons[targetIndex].focus();
            tabButtons[targetIndex].click();
        });
    });
}

// Initialize all educational features when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    initializeTabs();
    initializeCardInteractions();
    initializeSmoothScrolling();
    addPerformanceIndicators();
    initializeTooltips();
    initializeProgressiveDisclosure();
    initializeKeyboardNavigation();
    
    // Make toggleBenefitDetails globally available
    window.toggleBenefitDetails = toggleBenefitDetails;
});

// Export functions for potential use in other modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        initializeTabs,
        toggleBenefitDetails,
        initializeCardInteractions,
        initializeSmoothScrolling,
        addPerformanceIndicators,
        initializeTooltips,
        initializeProgressiveDisclosure,
        initializeKeyboardNavigation
    };
}