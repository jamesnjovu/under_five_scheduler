// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"

import AOS from "../vendor/aos";

import hooks from "./hooks"

import Alpine from "../vendor/alpine"

// Initialize AOS (Animate On Scroll) library
window.Alpine = Alpine
Alpine.start()

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: hooks,
  longPollFallbackMs: 2500,
  dom: {
    onBeforeElUpdated(from, to) {
      if (from._x_dataStack) {
        window.Alpine.clone(from, to)
      }
    },
  },
  params: { _csrf_token: csrfToken }
})

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })

window.addEventListener('DOMContentLoaded', function () {
  AOS.init({
    duration: 800,
    easing: 'ease-in-out',
    once: true
  });
});

window.addEventListener("phx:page-loading-start", _info => {
  topbar.show(300);
})
window.addEventListener("phx:page-loading-stop", _info => {
  topbar.hide();
  AOS.refreshHard();;
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket




// PWA Scripts

// Register service worker
if ('serviceWorker' in navigator) {
  window.addEventListener('load', function () {
    navigator.serviceWorker.register('/service-worker.js')
      .then(function (registration) {
        console.log('ServiceWorker registration successful with scope: ', registration.scope);
      })
      .catch(function (error) {
        console.log('ServiceWorker registration failed: ', error);
      });
  });
}

// Offline/online detection
function updateOnlineStatus() {
  const indicator = document.getElementById('offline-indicator');
  if (indicator) {
    if (navigator.onLine) {
      indicator.classList.add('hidden');
      // Store current time as last sync time when coming back online
      localStorage.setItem('lastSyncTime', Date.now().toString());
    } else {
      indicator.classList.remove('hidden');
    }
  }
}

window.addEventListener('online', updateOnlineStatus);
window.addEventListener('offline', updateOnlineStatus);
updateOnlineStatus(); // Initial check

// Deferred "Add to Home Screen" prompt handling
let deferredPrompt;
const installBanner = document.getElementById('pwa-install-banner');
const installButton = document.getElementById('pwa-install-button');
const dismissButton = document.getElementById('pwa-dismiss-button');

window.addEventListener('beforeinstallprompt', (e) => {
  // Prevent Chrome 67 and earlier from automatically showing the prompt
  e.preventDefault();
  // Store the event for later use
  deferredPrompt = e;

  // Show our custom install banner
  if (installBanner && !localStorage.getItem('pwaInstallDismissed')) {
    installBanner.classList.remove('hidden');
    installBanner.classList.remove('translate-y-full');
  }
});

if (installButton) {
  installButton.addEventListener('click', async () => {
    if (!deferredPrompt) return;

    // Hide our custom install banner
    installBanner.classList.add('translate-y-full');

    // Show the browser's install prompt
    deferredPrompt.prompt();

    // Wait for the user to respond to the prompt
    const { outcome } = await deferredPrompt.userChoice;
    console.log(`User response to the PWA installation prompt: ${outcome}`);

    // We've used the prompt, so we can't use it again
    deferredPrompt = null;
  });
}

if (dismissButton) {
  dismissButton.addEventListener('click', () => {
    installBanner.classList.add('translate-y-full');
    // Remember that user dismissed the banner
    localStorage.setItem('pwaInstallDismissed', 'true');
    // Remove completely after animation
    setTimeout(() => {
      installBanner.classList.add('hidden');
    }, 300);
  });
}

// Detect when PWA was successfully installed
window.addEventListener('appinstalled', (event) => {
  console.log('PWA was installed');
  // Hide the install banner if it's still showing
  if (installBanner) {
    installBanner.classList.add('translate-y-full');
    setTimeout(() => {
      installBanner.classList.add('hidden');
    }, 300);
  }

  // You could send analytics data here if desired
  if (typeof gtag === 'function') {
    gtag('event', 'pwa_install');
  }
});