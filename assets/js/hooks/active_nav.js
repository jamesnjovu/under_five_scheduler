/**
 * Hook for handling active navigation state
 * @type {Object}
 */
const ActiveNav = {
    mounted() {
        // Cache element ID and initial URL
        this.elementId = "#" + this.el.id;
        this.baseUrl = window.location.origin;
        
        // Handle initial navigation state
        this.updateNavigation(window.location.pathname);
        
        // Create bound handler for cleanup
        this.navigationHandler = (event) => {
            try {
                const newUrl = new URL(event.destination.url);
                this.updateNavigation(newUrl.pathname);
            } catch (error) {
                console.warn('Navigation event handling failed:', error);
            }
        };

        // Add event listener
        window.navigation?.addEventListener("navigate", this.navigationHandler);
    },

    destroyed() {
        // Cleanup event listener
        window.navigation?.removeEventListener("navigate", this.navigationHandler);
    },

    updateNavigation(path) {
        try {
            this.pushEventTo(this.elementId, "change_nav", { url: path });
        } catch (error) {
            console.warn('Failed to update navigation:', error);
        }
    }
};

export default ActiveNav;
