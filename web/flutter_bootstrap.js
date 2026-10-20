{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    const loader = document.getElementById('flutter_loading_app');
    if (loader) {
      loader.style.transition = 'opacity 0.3s ease-out';
      loader.style.opacity = '0';
      loader.style.pointerEvents = 'none';
      setTimeout(function() {
        if (loader && loader.parentNode) {
          loader.parentNode.removeChild(loader);
        }
      }, 350);
    }
  }
});

