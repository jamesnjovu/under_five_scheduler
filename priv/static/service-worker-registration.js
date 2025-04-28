// Wait for the page to load
window.addEventListener('load', () => {
    // Check if service workers are supported
    if ('serviceWorker' in navigator) {
      registerServiceWorker();
    } else {
      console.log('Service workers are not supported in this browser.');
    }
  });
  
  async function registerServiceWorker() {
    try {
      // Register the service worker from the root path
      const registration = await navigator.serviceWorker.register('/service-worker.js');
      
      console.log('ServiceWorker registration successful with scope:', registration.scope);
      
      // Check for updates to the service worker
      registration.addEventListener('updatefound', () => {
        const newWorker = registration.installing;
        console.log('New service worker installing:', newWorker);
        
        // Track progress
        newWorker.addEventListener('statechange', () => {
          console.log('Service worker state changed to:', newWorker.state);
        });
      });
      
      // Handle service worker updates
      navigator.serviceWorker.addEventListener('controllerchange', () => {
        console.log('New service worker activated, page will reload to ensure consistency');
        window.location.reload();
      });
      
      // Add "Add to Home Screen" prompt logic
      let deferredPrompt;
      window.addEventListener('beforeinstallprompt', (event) => {
        // Prevent the default prompt
        event.preventDefault();
        
        // Store the event for later use
        deferredPrompt = event;
        
        // Show your custom "Add to Home Screen" button or banner
        showInstallPromotion();
      });
      
      // Function to show installation promotion UI
      function showInstallPromotion() {
        // Create installation button if it doesn't exist
        if (!document.getElementById('install-button')) {
          const installButton = document.createElement('button');
          installButton.id = 'install-button';
          installButton.className = 'fixed bottom-4 right-4 bg-indigo-600 text-white py-2 px-4 rounded-lg shadow-lg';
          installButton.textContent = 'Install App';
          installButton.addEventListener('click', async () => {
            if (!deferredPrompt) return;
            
            // Show the installation prompt
            deferredPrompt.prompt();
            
            // Wait for the user to respond to the prompt
            const { outcome } = await deferredPrompt.userChoice;
            console.log(`User response to the install prompt: ${outcome}`);
            
            // Clear the saved prompt as it can't be used again
            deferredPrompt = null;
            
            // Hide the installation button
            installButton.remove();
          });
          
          document.body.appendChild(installButton);
        }
      }
      
    } catch (error) {
      console.error('ServiceWorker registration failed:', error);
    }
  }