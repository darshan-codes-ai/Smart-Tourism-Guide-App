{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
      const loader = document.getElementById('flutter_loading_app');
      if (loader) {
        loader.style.transition = 'opacity 0.3s ease-out';
        loader.style.opacity = '0';
        loader.style.pointerEvents = 'none';
        setTimeout(function() {
          if (loader) {
            loader.style.zIndex = '-9999';
            loader.setAttribute('aria-hidden', 'true');
          }
        }, 350);
      }
    } catch (err) {
      console.error('Failed to initialize TourMate Flutter engine:', err);
      const loader = document.getElementById('flutter_loading_app');
      if (loader) {
        loader.innerHTML = '<div style="padding:24px;text-align:center;font-family:sans-serif;color:#1A2B33;"><div style="font-size:36px;margin-bottom:12px;">⚠️</div><h2 style="margin:0 0 8px;color:#D32F2F;">Unable to Load TourMate</h2><p style="margin:0;color:#5B6B73;font-size:14px;">An error occurred while starting the application. Please refresh the browser or try a different browser.</p></div>';
      }
    }
  }
});

